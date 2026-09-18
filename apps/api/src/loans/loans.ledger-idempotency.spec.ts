import { ConflictException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { UserRole } from '../generated/prisma/enums';
import { LoansService } from './loans.service';

describe('LoansService ledger idempotency', () => {
  it('uses LOAN_DISBURSEMENT:{loanId} and blocks a second approve credit', async () => {
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
        cashBalance: new Prisma.Decimal(50),
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
      accountTransaction: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({
          id: 'tx-1',
          idempotencyKey: 'LOAN_DISBURSEMENT:loan-1',
        }),
      },
    };
    const prisma = {
      $transaction: jest.fn((callback: (client: typeof tx) => unknown) =>
        callback(tx),
      ),
    };
    const audit = { createLog: jest.fn() };
    const service = new LoansService(prisma as any, audit as any);

    await service.approve(loan.id, 'finance', UserRole.FINANCE, {
      approvedAmount: 25,
    });
    expect(tx.accountTransaction.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        type: 'LOAN_DISBURSEMENT',
        idempotencyKey: 'LOAN_DISBURSEMENT:loan-1',
        referenceId: 'LN1',
      }),
    });

    await expect(
      service.approve(loan.id, 'finance', UserRole.FINANCE, {
        approvedAmount: 25,
      }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(tx.accountTransaction.create).toHaveBeenCalledTimes(1);
  });

  it('allows different loans to each create a disbursement ledger', async () => {
    const makeTx = (loanId: string) => {
      const loan = {
        id: loanId,
        orderNo: `LN-${loanId}`,
        status: 'PENDING',
        accountId: 'account-1',
        requestedAmount: new Prisma.Decimal(0),
        interestRate: new Prisma.Decimal(0),
        dueDate: null,
        note: null,
        account: {
          cashBalance: new Prisma.Decimal(10),
          user: { usedInviteCode: null },
        },
      };
      return {
        loan,
        tx: {
          loanApplication: {
            findUnique: jest.fn().mockResolvedValue(loan),
            updateMany: jest.fn().mockResolvedValue({ count: 1 }),
            findUniqueOrThrow: jest.fn().mockResolvedValue(loan),
          },
          account: { update: jest.fn() },
          accountTransaction: {
            findUnique: jest.fn().mockResolvedValue(null),
            create: jest.fn().mockResolvedValue({
              id: `tx-${loanId}`,
              idempotencyKey: `LOAN_DISBURSEMENT:${loanId}`,
            }),
          },
        },
      };
    };

    const first = makeTx('loan-a');
    const second = makeTx('loan-b');
    const audit = { createLog: jest.fn() };
    const serviceA = new LoansService(
      {
        $transaction: (cb: any) => cb(first.tx),
      } as any,
      audit as any,
    );
    const serviceB = new LoansService(
      {
        $transaction: (cb: any) => cb(second.tx),
      } as any,
      audit as any,
    );

    await serviceA.approve('loan-a', 'finance', UserRole.FINANCE, {
      approvedAmount: 11,
    });
    await serviceB.approve('loan-b', 'finance', UserRole.FINANCE, {
      approvedAmount: 12,
    });
    expect(first.tx.accountTransaction.create).toHaveBeenCalledTimes(1);
    expect(second.tx.accountTransaction.create).toHaveBeenCalledTimes(1);
    expect(
      first.tx.accountTransaction.create.mock.calls[0][0].data.idempotencyKey,
    ).toBe('LOAN_DISBURSEMENT:loan-a');
    expect(
      second.tx.accountTransaction.create.mock.calls[0][0].data.idempotencyKey,
    ).toBe('LOAN_DISBURSEMENT:loan-b');
  });
});
