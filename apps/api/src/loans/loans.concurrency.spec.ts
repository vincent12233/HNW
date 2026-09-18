import { ConflictException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { LoansService } from './loans.service';
import { UserRole } from '../generated/prisma/enums';

describe('LoansService concurrency protection', () => {
  it.each([0.01, 100.25, 123456.78])(
    'credits exactly %s and rejects a second approval',
    async (amount) => {
      const loan = {
        id: 'loan-1',
        orderNo: 'LN1',
        status: 'PENDING',
        accountId: 'account-1',
        requestedAmount: new Prisma.Decimal(0),
        interestRate: new Prisma.Decimal(0),
        dueDate: null,
        note: null,
        account: {
          cashBalance: new Prisma.Decimal('200.15'),
          user: { usedInviteCode: null },
        },
      };
      const tx = {
        loanApplication: {
          findUnique: jest.fn().mockImplementation(async () => loan),
          updateMany: jest.fn().mockImplementation(async () => {
            loan.status = 'DISBURSED';
            return { count: 1 };
          }),
          findUniqueOrThrow: jest.fn().mockImplementation(async () => loan),
        },
        account: { update: jest.fn() },
        accountTransaction: { findUnique: jest.fn().mockResolvedValue(null), create: jest.fn() },
      };
      const prisma = {
        $transaction: jest.fn((callback: (client: typeof tx) => unknown) =>
          callback(tx),
        ),
      };
      const audit = { createLog: jest.fn() };
      const service = new LoansService(prisma as any, audit as any);
      await service.approve(loan.id, 'finance', UserRole.FINANCE, {
        approvedAmount: amount,
      });
      const expectedBalance = new Prisma.Decimal('200.15')
        .add(amount)
        .toFixed(2);
      const updateData = tx.loanApplication.updateMany.mock.calls[0][0].data;
      expect(updateData.status).toBe('DISBURSED');
      expect(new Prisma.Decimal(updateData.approvedAmount).toFixed(2)).toBe(
        new Prisma.Decimal(amount).toFixed(2),
      );
      expect(new Prisma.Decimal(updateData.outstandingAmount).toFixed(2)).toBe(
        new Prisma.Decimal(amount).toFixed(2),
      );
      const balanceUpdate = tx.account.update.mock.calls[0][0].data;
      expect(balanceUpdate.cashBalance.toFixed(2)).toBe(expectedBalance);
      expect(
        new Prisma.Decimal(balanceUpdate.buyingPower.increment).toFixed(2),
      ).toBe(new Prisma.Decimal(amount).toFixed(2));
      const entry = tx.accountTransaction.create.mock.calls[0][0].data;
      expect(new Prisma.Decimal(entry.amount).toFixed(2)).toBe(
        new Prisma.Decimal(amount).toFixed(2),
      );
      expect(entry.balanceAfter.toFixed(2)).toBe(expectedBalance);
      expect(entry.referenceId).toBe('LN1');
      expect(prisma.$transaction.mock.calls[0][1]).toEqual({
        isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
      });
      await expect(
        service.approve(loan.id, 'finance', UserRole.FINANCE, {
          approvedAmount: amount,
        }),
      ).rejects.toBeInstanceOf(ConflictException);
      expect(tx.account.update).toHaveBeenCalledTimes(1);
      expect(tx.accountTransaction.create).toHaveBeenCalledTimes(1);
      expect(audit.createLog).toHaveBeenCalledTimes(1);
    },
  );
  it('does not credit an account when another operator already claimed the loan', async () => {
    const tx = {
      loanApplication: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'loan-1',
          orderNo: 'LN1',
          status: 'PENDING',
          accountId: 'account-1',
          interestRate: new Prisma.Decimal(0),
          dueDate: null,
          note: null,
          account: { cashBalance: new Prisma.Decimal(100) },
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      account: { update: jest.fn() },
      accountTransaction: { findUnique: jest.fn().mockResolvedValue(null), create: jest.fn() },
    };
    const prisma = {
      $transaction: jest.fn((callback: (client: typeof tx) => unknown) =>
        callback(tx),
      ),
    };
    const audit = { createLog: jest.fn() };
    const service = new LoansService(prisma as any, audit as any);

    await expect(
      service.approve('loan-1', 'finance-2', { approvedAmount: 500 }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(tx.account.update).not.toHaveBeenCalled();
    expect(tx.accountTransaction.create).not.toHaveBeenCalled();
    expect(audit.createLog).not.toHaveBeenCalled();
  });
});
