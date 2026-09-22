import { ConfigService } from '@nestjs/config';
import { AdminAccountService } from '../account/admin-account.service';
import { AuditService } from '../audit/audit.service';
import { DepositService } from '../deposit/deposit.service';
import { PrismaService } from '../prisma/prisma.service';
import { WithdrawalService } from '../withdrawal/withdrawal.service';
import { WithdrawalPinService } from '../client-experience/withdrawal-pin.service';
import { moneyDecimal } from '../common/money';
import {
  fundingRaceRuns,
  requireFundingIntegrationDatabaseUrl,
} from './database-url.guard';
import {
  PHASE4A_FIXED_INVITE,
  ThrowingAuditService,
  WITHDRAWAL_PIN,
  assertFundingInvariants,
  cleanupPhase4A,
  createClientWithAccount,
  createInviteGraph,
  createStaffUser,
  interceptLedgerCreate,
  snapshotAccount,
  token,
} from './fixture';

const configured = Boolean(
  process.env.FUNDING_INTEGRATION_DATABASE_URL?.trim(),
);

(configured ? describe : describe.skip)(
  'real PostgreSQL funding concurrency',
  () => {
    let prisma: PrismaService;
    let audit: AuditService;
    let deposits: DepositService;
    let withdrawals: WithdrawalService;
    let accounts: AdminAccountService;
    let financeInviteId: string;
    let dedicatedInviteId: string;
    let financeId: string;
    let supportId: string;
    const raceRuns = fundingRaceRuns(20);

    beforeAll(async () => {
      process.env.ADMIN_FIXED_INVITE_CODE = PHASE4A_FIXED_INVITE;
      const url = requireFundingIntegrationDatabaseUrl();
      prisma = new PrismaService({
        get: (key: string) => (key === 'DATABASE_URL' ? url : undefined),
      } as ConfigService);
      await prisma.$connect();
      audit = new AuditService(prisma);
      deposits = new DepositService(prisma, audit);
      withdrawals = new WithdrawalService(
        prisma,
        audit,
        new WithdrawalPinService(prisma),
      );
      accounts = new AdminAccountService(prisma, audit, {} as never);
    });

    afterAll(async () => {
      if (prisma) {
        await cleanupPhase4A(prisma);
        await prisma.$disconnect();
      }
    });

    beforeEach(async () => {
      await cleanupPhase4A(prisma);
      const finance = await createStaffUser(prisma, 'FINANCE');
      const support = await createStaffUser(prisma, 'SUPPORT');
      const business = await createStaffUser(prisma, 'BUSINESS');
      const dedicatedBusiness = await createStaffUser(prisma, 'BUSINESS');
      financeId = finance.id;
      supportId = support.id;
      financeInviteId = (
        await createInviteGraph(prisma, business.id, token('FINV'))
      ).id;
      dedicatedInviteId = (
        await createInviteGraph(
          prisma,
          dedicatedBusiness.id,
          PHASE4A_FIXED_INVITE,
        )
      ).id;
    });

    async function financeClient(
      balances?: {
        cashBalance: string;
        buyingPower: string;
        frozenBalance: string;
      },
      withPin = false,
    ) {
      return createClientWithAccount(prisma, {
        inviteCodeId: financeInviteId,
        balances,
        withWithdrawalPin: withPin,
      });
    }

    async function dedicatedClient() {
      return createClientWithAccount(prisma, {
        inviteCodeId: dedicatedInviteId,
        assignedBusinessId: supportId,
      });
    }

    async function pendingDeposit(accountId: string, amount = '200.00') {
      return prisma.depositRequest.create({
        data: {
          accountId,
          amount,
          referenceId: token('DEP'),
          status: 'PENDING',
        },
      });
    }

    async function pendingWithdrawal(accountId: string, amount = '200.00') {
      return prisma.withdrawalRequest.create({
        data: {
          accountId,
          amount,
          frozenAmount: amount,
          orderNo: token('WD'),
          upiId: 'phase4a@upi',
          status: 'PENDING',
        },
      });
    }

    function ledgerCount(
      accountId: string,
      type: 'DEPOSIT' | 'WITHDRAWAL' | 'ADMIN_CREDIT' | 'ADMIN_DEBIT',
    ) {
      return prisma.accountTransaction.count({
        where: { accountId, type, status: 'COMPLETED' },
      });
    }

    function auditCount(resourceId: string, action: string) {
      return prisma.auditLog.count({ where: { resourceId, action } });
    }

    it(`deposit double-approve is not duplicated across ${raceRuns} races`, async () => {
      for (let run = 0; run < raceRuns; run += 1) {
        const { account } = await financeClient();
        const deposit = await pendingDeposit(account.id);
        const settled = await Promise.allSettled([
          deposits.approveDeposit(deposit.id, financeId, 'FINANCE'),
          deposits.approveDeposit(deposit.id, financeId, 'FINANCE'),
        ]);
        const successes = settled.filter((item) => item.status === 'fulfilled');
        const snapshot = await snapshotAccount(prisma, account.id);
        const depositRow = await prisma.depositRequest.findUniqueOrThrow({
          where: { id: deposit.id },
        });
        expect(successes.length).toBe(1);
        expect(depositRow.status).toBe('APPROVED');
        expect(snapshot.cashBalance.toFixed(2)).toBe('1200.00');
        expect(snapshot.buyingPower.toFixed(2)).toBe('1000.00');
        expect(await ledgerCount(account.id, 'DEPOSIT')).toBe(1);
        expect(await auditCount(deposit.id, 'DEPOSIT_APPROVED')).toBe(1);
        assertFundingInvariants(snapshot);
      }
    });

    it('deposit approve vs reject yields one terminal status aligned with ledger', async () => {
      const { account } = await financeClient();
      const deposit = await pendingDeposit(account.id);
      const settled = await Promise.allSettled([
        deposits.approveDeposit(deposit.id, financeId, 'FINANCE'),
        deposits.rejectDeposit(deposit.id, 'race', financeId, 'FINANCE'),
      ]);
      const depositRow = await prisma.depositRequest.findUniqueOrThrow({
        where: { id: deposit.id },
      });
      const snapshot = await snapshotAccount(prisma, account.id);
      const ledger = await ledgerCount(account.id, 'DEPOSIT');
      expect(['APPROVED', 'REJECTED']).toContain(depositRow.status);
      expect(settled.filter((item) => item.status === 'fulfilled').length).toBe(
        1,
      );
      if (depositRow.status === 'APPROVED') {
        expect(snapshot.cashBalance.toFixed(2)).toBe('1200.00');
        expect(ledger).toBe(1);
        expect(await auditCount(deposit.id, 'DEPOSIT_APPROVED')).toBe(1);
        expect(await auditCount(deposit.id, 'DEPOSIT_REJECTED')).toBe(0);
      } else {
        expect(snapshot.cashBalance.toFixed(2)).toBe('1000.00');
        expect(ledger).toBe(0);
        expect(await auditCount(deposit.id, 'DEPOSIT_REJECTED')).toBe(1);
        expect(await auditCount(deposit.id, 'DEPOSIT_APPROVED')).toBe(0);
      }
      assertFundingInvariants(snapshot);
    });

    it(`withdrawal double-approve is not duplicated across ${raceRuns} races`, async () => {
      for (let run = 0; run < raceRuns; run += 1) {
        const { account } = await financeClient();
        const withdrawal = await pendingWithdrawal(account.id);
        const settled = await Promise.allSettled([
          withdrawals.approveWithdrawal(withdrawal.id, financeId, 'FINANCE'),
          withdrawals.approveWithdrawal(withdrawal.id, financeId, 'FINANCE'),
        ]);
        const snapshot = await snapshotAccount(prisma, account.id);
        const row = await prisma.withdrawalRequest.findUniqueOrThrow({
          where: { id: withdrawal.id },
        });
        expect(
          settled.filter((item) => item.status === 'fulfilled').length,
        ).toBe(1);
        expect(row.status).toBe('APPROVED');
        expect(moneyDecimal(row.frozenAmount).toFixed(2)).toBe('0.00');
        expect(snapshot.cashBalance.toFixed(2)).toBe('800.00');
        expect(snapshot.frozenBalance.toFixed(2)).toBe('0.00');
        expect(await ledgerCount(account.id, 'WITHDRAWAL')).toBe(1);
        expect(await auditCount(withdrawal.id, 'WITHDRAWAL_APPROVED')).toBe(1);
        assertFundingInvariants(snapshot);
      }
    });

    it('withdrawal approve vs reject does not lose money or stick frozen funds', async () => {
      const { account } = await financeClient();
      const withdrawal = await pendingWithdrawal(account.id);
      await Promise.allSettled([
        withdrawals.approveWithdrawal(withdrawal.id, financeId, 'FINANCE'),
        withdrawals.rejectWithdrawal(
          withdrawal.id,
          'race',
          financeId,
          'FINANCE',
        ),
      ]);
      const row = await prisma.withdrawalRequest.findUniqueOrThrow({
        where: { id: withdrawal.id },
      });
      const snapshot = await snapshotAccount(prisma, account.id);
      expect(['APPROVED', 'REJECTED']).toContain(row.status);
      if (row.status === 'APPROVED') {
        expect(snapshot.cashBalance.toFixed(2)).toBe('800.00');
        expect(snapshot.frozenBalance.toFixed(2)).toBe('0.00');
        expect(await ledgerCount(account.id, 'WITHDRAWAL')).toBe(1);
      } else {
        expect(snapshot.cashBalance.toFixed(2)).toBe('1000.00');
        expect(snapshot.frozenBalance.toFixed(2)).toBe('0.00');
        expect(snapshot.buyingPower.toFixed(2)).toBe('1000.00');
        expect(await ledgerCount(account.id, 'WITHDRAWAL')).toBe(0);
      }
      assertFundingInvariants(snapshot);
    });

    it('concurrent withdrawal submissions cannot freeze more than available cash', async () => {
      const { user, account } = await financeClient(
        {
          cashBalance: '1000.00',
          buyingPower: '1000.00',
          frozenBalance: '0.00',
        },
        true,
      );
      const settled = await Promise.allSettled([
        withdrawals.createRequest(
          user.id,
          '700.00',
          undefined,
          undefined,
          undefined,
          'phase4a@upi',
          undefined,
          WITHDRAWAL_PIN,
        ),
        withdrawals.createRequest(
          user.id,
          '700.00',
          undefined,
          undefined,
          undefined,
          'phase4a@upi',
          undefined,
          WITHDRAWAL_PIN,
        ),
      ]);
      const snapshot = await snapshotAccount(prisma, account.id);
      const pending = await prisma.withdrawalRequest.findMany({
        where: { accountId: account.id, status: 'PENDING' },
      });
      const frozenSum = pending.reduce(
        (sum, row) => sum.add(moneyDecimal(row.frozenAmount)),
        moneyDecimal(0),
      );
      expect(snapshot.available.gte(0)).toBe(true);
      expect(snapshot.frozenBalance.lte(1000)).toBe(true);
      expect(frozenSum.toFixed(2)).toBe(snapshot.frozenBalance.toFixed(2));
      expect(Number(snapshot.frozenBalance.toFixed(2))).toBeLessThanOrEqual(
        1000,
      );
      expect(
        settled.filter((item) => item.status === 'fulfilled').length,
      ).toBeLessThanOrEqual(1);
      assertFundingInvariants(snapshot);
    });

    it(`FINANCE same-reference concurrent credit posts at most once across ${raceRuns} races`, async () => {
      for (let run = 0; run < raceRuns; run += 1) {
        const { account } = await financeClient();
        const referenceId = token('PHASE4-CREDIT-');
        const dto = { amount: '200.00', referenceId };
        const settled = await Promise.allSettled([
          accounts.credit(account.accountNumber, dto, financeId, 'FINANCE'),
          accounts.credit(account.accountNumber, dto, financeId, 'FINANCE'),
        ]);
        const snapshot = await snapshotAccount(prisma, account.id);
        const ledger = await prisma.accountTransaction.count({
          where: {
            accountId: account.id,
            type: 'ADMIN_CREDIT',
            referenceId,
            status: 'COMPLETED',
          },
        });
        const fulfilled = settled.filter((item) => item.status === 'fulfilled');
        expect(ledger).toBe(1);
        expect(fulfilled.length).toBe(1);
        expect(snapshot.cashBalance.toFixed(2)).toBe('1200.00');
        expect(
          await prisma.auditLog.count({
            where: {
              action: 'FINANCE_CREDIT',
              resourceId: account.accountNumber,
            },
          }),
        ).toBe(1);
        assertFundingInvariants(snapshot);
      }
    });

    it(`FINANCE same-reference concurrent debit posts at most once across ${raceRuns} races`, async () => {
      for (let run = 0; run < raceRuns; run += 1) {
        const { account } = await financeClient();
        const referenceId = token('PHASE4-DEBIT-');
        const dto = { amount: '200.00', referenceId };
        const settled = await Promise.allSettled([
          accounts.debit(account.accountNumber, dto, financeId, 'FINANCE'),
          accounts.debit(account.accountNumber, dto, financeId, 'FINANCE'),
        ]);
        const snapshot = await snapshotAccount(prisma, account.id);
        const ledger = await prisma.accountTransaction.count({
          where: {
            accountId: account.id,
            type: 'ADMIN_DEBIT',
            referenceId,
            status: 'COMPLETED',
          },
        });
        expect(ledger).toBe(1);
        expect(
          settled.filter((item) => item.status === 'fulfilled').length,
        ).toBe(1);
        expect(snapshot.cashBalance.toFixed(2)).toBe('800.00');
        expect(snapshot.buyingPower.toFixed(2)).toBe('600.00');
        assertFundingInvariants(snapshot);
      }
    });

    it('FINANCE different-reference concurrent 700+700 debits cannot overdraft', async () => {
      const { account } = await financeClient({
        cashBalance: '1000.00',
        buyingPower: '1000.00',
        frozenBalance: '0.00',
      });
      const settled = await Promise.allSettled([
        accounts.debit(
          account.accountNumber,
          { amount: '700.00', referenceId: token('DEBITA') },
          financeId,
          'FINANCE',
        ),
        accounts.debit(
          account.accountNumber,
          { amount: '700.00', referenceId: token('DEBITB') },
          financeId,
          'FINANCE',
        ),
      ]);
      const snapshot = await snapshotAccount(prisma, account.id);
      const ledger = await ledgerCount(account.id, 'ADMIN_DEBIT');
      expect(snapshot.cashBalance.gte(0)).toBe(true);
      expect(ledger).toBe(1);
      expect(settled.filter((item) => item.status === 'fulfilled').length).toBe(
        1,
      );
      expect(snapshot.cashBalance.toFixed(2)).toBe('300.00');
      assertFundingInvariants(snapshot);
    });

    it('SUPPORT dedicated same-reference credit and debit stay idempotent', async () => {
      const { account } = await dedicatedClient();
      const creditRef = token('DED-CREDIT-');
      const debitRef = token('DED-DEBIT-');
      const creditSettled = await Promise.allSettled([
        accounts.credit(
          account.accountNumber,
          { amount: '200.00', referenceId: creditRef },
          supportId,
          'SUPPORT',
        ),
        accounts.credit(
          account.accountNumber,
          { amount: '200.00', referenceId: creditRef },
          supportId,
          'SUPPORT',
        ),
      ]);
      const afterCredit = await snapshotAccount(prisma, account.id);
      expect(
        creditSettled.filter((item) => item.status === 'fulfilled').length,
      ).toBe(1);
      expect(afterCredit.cashBalance.toFixed(2)).toBe('1200.00');
      const debitSettled = await Promise.allSettled([
        accounts.debit(
          account.accountNumber,
          { amount: '200.00', referenceId: debitRef },
          supportId,
          'SUPPORT',
        ),
        accounts.debit(
          account.accountNumber,
          { amount: '200.00', referenceId: debitRef },
          supportId,
          'SUPPORT',
        ),
      ]);
      const afterDebit = await snapshotAccount(prisma, account.id);
      expect(
        debitSettled.filter((item) => item.status === 'fulfilled').length,
      ).toBe(1);
      expect(afterDebit.cashBalance.toFixed(2)).toBe('1000.00');
      expect(
        await prisma.accountTransaction.count({
          where: { accountId: account.id, referenceId: creditRef },
        }),
      ).toBe(1);
      expect(
        await prisma.accountTransaction.count({
          where: { accountId: account.id, referenceId: debitRef },
        }),
      ).toBe(1);
    });

    it('rolls back deposit approval when audit insert fails', async () => {
      const failing = new DepositService(
        prisma,
        new ThrowingAuditService() as never,
      );
      const { account } = await financeClient();
      const deposit = await pendingDeposit(account.id);
      await expect(
        failing.approveDeposit(deposit.id, financeId, 'FINANCE'),
      ).rejects.toThrow('audit insert failed');
      const row = await prisma.depositRequest.findUniqueOrThrow({
        where: { id: deposit.id },
      });
      const snapshot = await snapshotAccount(prisma, account.id);
      expect(row.status).toBe('PENDING');
      expect(snapshot.cashBalance.toFixed(2)).toBe('1000.00');
      expect(await ledgerCount(account.id, 'DEPOSIT')).toBe(0);
      expect(await auditCount(deposit.id, 'DEPOSIT_APPROVED')).toBe(0);
    });

    it('rolls back withdrawal approval when audit insert fails', async () => {
      const failing = new WithdrawalService(
        prisma,
        new ThrowingAuditService() as never,
        new WithdrawalPinService(prisma),
      );
      const { account } = await financeClient();
      const withdrawal = await pendingWithdrawal(account.id);
      await expect(
        failing.approveWithdrawal(withdrawal.id, financeId, 'FINANCE'),
      ).rejects.toThrow('audit insert failed');
      const row = await prisma.withdrawalRequest.findUniqueOrThrow({
        where: { id: withdrawal.id },
      });
      const snapshot = await snapshotAccount(prisma, account.id);
      expect(row.status).toBe('PENDING');
      expect(snapshot.cashBalance.toFixed(2)).toBe('1000.00');
      expect(snapshot.frozenBalance.toFixed(2)).toBe('200.00');
      expect(await ledgerCount(account.id, 'WITHDRAWAL')).toBe(0);
      expect(await auditCount(withdrawal.id, 'WITHDRAWAL_APPROVED')).toBe(0);
    });

    it('rolls back FINANCE credit when audit insert fails', async () => {
      const failing = new AdminAccountService(
        prisma,
        new ThrowingAuditService() as never,
        {} as never,
      );
      const { account } = await financeClient();
      const referenceId = token('AUDIT-FAIL-');
      await expect(
        failing.credit(
          account.accountNumber,
          { amount: '200.00', referenceId },
          financeId,
          'FINANCE',
        ),
      ).rejects.toThrow('audit insert failed');
      const snapshot = await snapshotAccount(prisma, account.id);
      expect(snapshot.cashBalance.toFixed(2)).toBe('1000.00');
      expect(
        await prisma.accountTransaction.count({
          where: { accountId: account.id, referenceId },
        }),
      ).toBe(0);
      expect(
        await prisma.auditLog.count({
          where: {
            action: 'FINANCE_CREDIT',
            resourceId: account.accountNumber,
          },
        }),
      ).toBe(0);
    });

    it('rolls back deposit approval when ledger insert fails', async () => {
      const restore = interceptLedgerCreate(prisma, () => true);
      try {
        const { account } = await financeClient();
        const deposit = await pendingDeposit(account.id);
        await expect(
          deposits.approveDeposit(deposit.id, financeId, 'FINANCE'),
        ).rejects.toThrow('ledger insert failed');
        const row = await prisma.depositRequest.findUniqueOrThrow({
          where: { id: deposit.id },
        });
        const snapshot = await snapshotAccount(prisma, account.id);
        expect(row.status).toBe('PENDING');
        expect(snapshot.cashBalance.toFixed(2)).toBe('1000.00');
        expect(await ledgerCount(account.id, 'DEPOSIT')).toBe(0);
      } finally {
        restore();
      }
    });
  },
);

if (!configured) {
  describe('real PostgreSQL funding concurrency (skipped)', () => {
    it('documents how to run against an isolated local database', () => {
      // eslint-disable-next-line no-console
      console.warn(
        'SKIP: set FUNDING_INTEGRATION_DATABASE_URL to a local postgres URL whose database name contains test, e2e, or integration. Never export production DATABASE_URL. Example: npm run test:funding:integration via scripts/run-funding-integration.sh',
      );
      expect(process.env.FUNDING_INTEGRATION_DATABASE_URL).toBeUndefined();
    });
  });
}
