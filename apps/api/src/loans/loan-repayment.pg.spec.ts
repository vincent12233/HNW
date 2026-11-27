import { randomUUID } from 'crypto';
import { AuditService } from '../audit/audit.service';
import { UserRole } from '../generated/prisma/client';
import {
  auditPostgresEnabled,
  auditPrisma,
  withBlockedWriters,
} from '../testing/postgres-audit-fixture';
import { LoansService } from './loans.service';

(auditPostgresEnabled ? describe : describe.skip)(
  'Loan repayment PostgreSQL transactions',
  () => {
    const first = auditPrisma();
    const second = auditPrisma();
    const services = [first, second].map(
      (db) => new LoansService(db, new AuditService(db)),
    );
    let userId: string;
    let loanId: string;
    beforeEach(async () => {
      userId = randomUUID();
      await first.user.create({
        data: {
          id: userId,
          email: `${userId}@test.local`,
          passwordHash: 'fixture',
          fullName: 'Fixture',
          role: UserRole.FINANCE,
        },
      });
      const account = await first.account.create({
        data: { accountNumber: randomUUID(), userId },
      });
      const loan = await first.loanApplication.create({
        data: {
          accountId: account.id,
          orderNo: randomUUID(),
          requestedAmount: 1000,
          outstandingAmount: 1000,
          status: 'DISBURSED',
        },
      });
      loanId = loan.id;
    });
    afterEach(async () => {
      await first.auditLog.deleteMany({ where: { resourceId: loanId } });
      await first.loanRepayment.deleteMany({ where: { loanId } });
      await first.loanApplication.delete({ where: { id: loanId } });
      await first.account.delete({ where: { userId } });
      await first.user.delete({ where: { id: userId } });
    });
    afterAll(async () => {
      await first.$disconnect();
      await second.$disconnect();
    });
    const repay = (index: number, key: string, amount = 100) =>
      services[index].repay(
        loanId,
        userId,
        UserRole.FINANCE,
        amount,
        'test',
        key,
      );
    it('serializes two independent 100 repayments to 800 and commits each audit', async () => {
      await withBlockedWriters(
        'SELECT id FROM loan_applications WHERE id=$1 FOR UPDATE',
        [loanId],
        'loan_applications',
        () => [repay(0, randomUUID()), repay(1, randomUUID())],
      );
      expect(
        (
          await first.loanApplication.findUniqueOrThrow({
            where: { id: loanId },
          })
        ).outstandingAmount.toString(),
      ).toBe('800');
      expect(await first.loanRepayment.count({ where: { loanId } })).toBe(2);
      expect(
        await first.auditLog.count({
          where: { resourceId: loanId, action: 'LOAN_REPAY_RECORD' },
        }),
      ).toBe(2);
    });
    it('replays concurrent duplicates and preserves the original response after later repayments', async () => {
      const key = randomUUID();
      const [a, b] = await withBlockedWriters(
        'SELECT id FROM loan_applications WHERE id=$1 FOR UPDATE',
        [loanId],
        'loan_applications',
        () => [repay(0, key), repay(1, key)],
      );
      expect(a).toEqual(b);
      await repay(1, randomUUID());
      expect(await repay(0, key)).toEqual(a);
      expect(await first.loanRepayment.count({ where: { loanId } })).toBe(2);
      await expect(repay(0, key, 101)).rejects.toMatchObject({ status: 409 });
    });
    it('rejects overpayment and rolls all writes back when audit fails', async () => {
      await expect(repay(0, randomUUID(), 1001)).rejects.toMatchObject({
        status: 400,
      });
      const failing = new LoansService(first, {
        createLog: jest.fn().mockRejectedValue(new Error('audit unavailable')),
      } as never);
      await expect(
        failing.repay(
          loanId,
          userId,
          UserRole.FINANCE,
          100,
          'test',
          randomUUID(),
        ),
      ).rejects.toThrow('audit unavailable');
      expect(
        (
          await first.loanApplication.findUniqueOrThrow({
            where: { id: loanId },
          })
        ).outstandingAmount.toString(),
      ).toBe('1000');
      expect(await first.loanRepayment.count({ where: { loanId } })).toBe(0);
    });
  },
);
