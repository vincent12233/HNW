import { AdminAccountService } from '../account/admin-account.service';
import { ApprovalService } from '../approval/approval.service';
import { WithdrawalPinService } from '../client-experience/withdrawal-pin.service';
import { DepositService } from '../deposit/deposit.service';
import { Prisma } from '../generated/prisma/client';
import { UserRole } from '../generated/prisma/enums';
import { LoansService } from '../loans/loans.service';
import { PrismaService } from '../prisma/prisma.service';
import { WithdrawalService } from '../withdrawal/withdrawal.service';
import { AuditService } from './audit.service';

// These tests exercise transaction-client selection and callback rejection.
// Actual PostgreSQL rollback and concurrency still require integration tests.
function fixture() {
  const account = {
    id: 'account-1',
    userId: 'client-1',
    cashBalance: new Prisma.Decimal(1000),
    buyingPower: new Prisma.Decimal(800),
    frozenBalance: new Prisma.Decimal(200),
    user: { id: 'client-1', usedInviteCode: null },
  };
  const deposit = {
    id: 'deposit-1',
    accountId: account.id,
    account,
    amount: 200,
    status: 'PENDING',
  };
  const withdrawal = {
    id: 'withdrawal-1',
    accountId: account.id,
    amount: 200,
    frozenAmount: 200,
    status: 'PENDING',
    orderNo: 'WD1',
  };
  const loan = {
    id: 'loan-1',
    orderNo: 'LN1',
    status: 'PENDING',
    accountId: account.id,
    account,
    interestRate: new Prisma.Decimal(0),
    dueDate: null,
    note: null,
  };
  const tx = {
    auditLog: { create: jest.fn().mockResolvedValue({ id: 'audit-1' }) },
    account: {
      findUnique: jest.fn().mockResolvedValue(account),
      findFirst: jest.fn().mockResolvedValue(account),
      update: jest.fn().mockResolvedValue(account),
    },
    depositRequest: {
      findUnique: jest.fn().mockResolvedValue(deposit),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    withdrawalRequest: {
      findUnique: jest
        .fn()
        .mockResolvedValueOnce(withdrawal)
        .mockResolvedValue({
          ...withdrawal,
          status: 'REJECTED',
          frozenAmount: 0,
        }),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
    },
    user: {
      count: jest.fn().mockResolvedValue(1),
      findUnique: jest.fn().mockResolvedValue({
        usedInviteCode: { code: 'BUSINESS-INVITE' },
      }),
    },
    loanApplication: {
      findUnique: jest.fn().mockResolvedValue(loan),
      updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      findUniqueOrThrow: jest.fn().mockResolvedValue({
        ...loan,
        status: 'DISBURSED',
        approvedAmount: new Prisma.Decimal(200),
        outstandingAmount: new Prisma.Decimal(200),
      }),
    },
    ipoDebt: { findMany: jest.fn().mockResolvedValue([]) },
    accountTransaction: {
      create: jest.fn().mockResolvedValue({}),
      findFirst: jest.fn().mockResolvedValue(null),
    },
    notification: { create: jest.fn().mockResolvedValue({}) },
  };
  const callbackCompleted = jest.fn();
  const callbackRejected = jest.fn();
  const prisma = {
    auditLog: { create: jest.fn().mockResolvedValue({ id: 'outside-audit' }) },
    depositRequest: { findUnique: jest.fn().mockResolvedValue(deposit) },
    $transaction: jest.fn(
      async (
        callback: (client: Prisma.TransactionClient) => Promise<unknown>,
      ) => {
        try {
          const result = await callback(
            tx as unknown as Prisma.TransactionClient,
          );
          callbackCompleted();
          return result;
        } catch (error) {
          callbackRejected(error);
          throw error;
        }
      },
    ),
  };
  const prismaService = prisma as unknown as PrismaService;
  const audit = new AuditService(prismaService);
  return {
    tx,
    prisma,
    callbackCompleted,
    callbackRejected,
    deposits: new DepositService(prismaService, audit),
    withdrawals: new WithdrawalService(
      prismaService,
      audit,
      {} as WithdrawalPinService,
    ),
    accounts: new AdminAccountService(
      prismaService,
      audit,
      {} as ApprovalService,
    ),
    loans: new LoansService(prismaService, audit),
  };
}

type Fixture = ReturnType<typeof fixture>;
type FundingOperation = {
  action: string;
  resourceId: string;
  actorId?: string;
  run: (f: Fixture) => Promise<unknown>;
  expectedResult: object;
  expectedMetadata?: object;
};

const operations: FundingOperation[] = [
  {
    action: 'DEPOSIT_APPROVED',
    resourceId: 'deposit-1',
    run: (f: Fixture) =>
      f.deposits.approveDeposit('deposit-1', 'finance', 'FINANCE'),
    expectedResult: {
      message: 'Deposit approved',
      depositId: 'deposit-1',
      depositAmount: 200,
      ipoRepayment: new Prisma.Decimal(0),
      creditedAmount: new Prisma.Decimal(200),
    },
  },
  {
    action: 'DEPOSIT_REJECTED',
    resourceId: 'deposit-1',
    run: (f: Fixture) =>
      f.deposits.rejectDeposit(
        'deposit-1',
        'Receipt verification failed',
        'finance',
        'FINANCE',
      ),
    expectedResult: {
      message: 'Deposit rejected',
      depositId: 'deposit-1',
    },
  },
  {
    action: 'WITHDRAWAL_APPROVED',
    resourceId: 'withdrawal-1',
    run: (f: Fixture) =>
      f.withdrawals.approveWithdrawal('withdrawal-1', 'finance', 'FINANCE'),
    expectedResult: {
      message: 'Withdrawal approved',
      withdrawalId: 'withdrawal-1',
      amount: 200,
      balanceBefore: new Prisma.Decimal(1000),
      balanceAfter: new Prisma.Decimal(800),
      frozenBalanceAfter: new Prisma.Decimal(0),
    },
  },
  {
    action: 'WITHDRAWAL_REJECTED',
    resourceId: 'withdrawal-1',
    run: (f: Fixture) =>
      f.withdrawals.rejectWithdrawal(
        'withdrawal-1',
        'Bank verification failed',
        'finance',
        'FINANCE',
      ),
    expectedResult: {
      id: 'withdrawal-1',
      status: 'REJECTED',
      frozenAmount: 0,
    },
  },
  ...(['FINANCE', 'SUPPORT'] as const).flatMap((role) =>
    (['CREDIT', 'DEBIT'] as const).map((direction): FundingOperation => ({
      action: `${role === 'FINANCE' ? 'FINANCE' : 'DEDICATED'}_${direction}`,
      resourceId: 'HNW123',
      actorId: role.toLowerCase(),
      run: (f: Fixture) =>
        f.accounts[direction === 'CREDIT' ? 'credit' : 'debit'](
          ' hnw123 ',
          { amount: '200.00', referenceId: 'PAYMENT-REFERENCE-1' },
          role.toLowerCase(),
          role,
        ),
      expectedResult: {
        message: direction === 'CREDIT' ? 'Funds credited' : 'Funds debited',
        accountNumber: 'HNW123',
        direction,
        amount: '200.00',
        ipoRepayment: '0.00',
        creditedAmount: '200.00',
        balance: direction === 'CREDIT' ? '1200.00' : '800.00',
      },
      expectedMetadata: {
        referenceId: 'PAYMENT-REFERENCE-1',
        amount: '200.00',
        ipoRepayment: '0.00',
        creditedAmount: '200.00',
      },
    })),
  ),
  {
    action: 'LOAN_APPROVE_AUTO_CREDIT',
    resourceId: 'loan-1',
    run: (f: Fixture) =>
      f.loans.approve('loan-1', 'finance', UserRole.FINANCE, {
        approvedAmount: '200.00',
      }),
    expectedResult: {
      id: 'loan-1',
      orderNo: 'LN1',
      status: 'DISBURSED',
      approvedAmount: new Prisma.Decimal(200),
      outstandingAmount: new Prisma.Decimal(200),
    },
    expectedMetadata: {
      orderNo: 'LN1',
      approvedAmount: new Prisma.Decimal(200),
    },
  },
];

describe.each(operations)('$action audit transaction', (operation) => {
  it('awaits one audit insert in the transaction and preserves the result', async () => {
    const f = fixture();
    let notifyAuditStarted!: () => void;
    let resolveAudit!: (value: { id: string }) => void;
    const auditStarted = new Promise<void>((resolve) => {
      notifyAuditStarted = resolve;
    });
    const auditResult = new Promise<{ id: string }>((resolve) => {
      resolveAudit = resolve;
    });
    f.tx.auditLog.create.mockImplementationOnce(() => {
      notifyAuditStarted();
      return auditResult;
    });

    const result = operation.run(f);
    await auditStarted;
    expect(f.callbackCompleted).not.toHaveBeenCalled();
    resolveAudit({ id: 'audit-1' });

    await expect(result).resolves.toMatchObject(operation.expectedResult);
    expect(f.callbackCompleted).toHaveBeenCalledTimes(1);
    expect(f.callbackRejected).not.toHaveBeenCalled();
    expect(f.tx.auditLog.create).toHaveBeenCalledTimes(1);
    expect(f.tx.auditLog.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        actorId: operation.actorId ?? 'finance',
        action: operation.action,
        resourceId: operation.resourceId,
        ...(operation.expectedMetadata
          ? { metadata: operation.expectedMetadata }
          : {}),
      }),
    });
    expect(f.prisma.auditLog.create).not.toHaveBeenCalled();
    expect(f.prisma.$transaction).toHaveBeenCalledWith(expect.any(Function), {
      isolationLevel: 'Serializable',
    });
  });

  it('rejects the transaction callback when audit insertion fails', async () => {
    const f = fixture();
    const failure = new Error('audit insert failed');
    f.tx.auditLog.create.mockRejectedValueOnce(failure);

    await expect(operation.run(f)).rejects.toBe(failure);

    expect(f.callbackRejected).toHaveBeenCalledWith(failure);
    expect(f.callbackCompleted).not.toHaveBeenCalled();
    expect(f.tx.auditLog.create).toHaveBeenCalledTimes(1);
    expect(f.prisma.auditLog.create).not.toHaveBeenCalled();
  });
});
