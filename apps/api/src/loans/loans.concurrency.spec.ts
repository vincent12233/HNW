import { ConflictException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { LoansService } from './loans.service';

describe('LoansService concurrency protection', () => {
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
      accountTransaction: { create: jest.fn() },
    };
    const prisma = {
      $transaction: jest.fn((callback: (client: typeof tx) => unknown) => callback(tx)),
    };
    const audit = { createLog: jest.fn() };
    const service = new LoansService(prisma as any, audit as any);

    await expect(service.approve('loan-1', 'finance-2', { approvedAmount: 500 }))
      .rejects.toBeInstanceOf(ConflictException);
    expect(tx.account.update).not.toHaveBeenCalled();
    expect(tx.accountTransaction.create).not.toHaveBeenCalled();
    expect(audit.createLog).not.toHaveBeenCalled();
  });
});
