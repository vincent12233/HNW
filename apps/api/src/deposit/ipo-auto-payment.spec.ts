import { Prisma } from '../generated/prisma/client';
import { DepositService } from './deposit.service';

describe('IPO automatic payment from approved deposits', () => {
  function setup(amount: number) {
    const tx = {
      depositRequest: { updateMany: jest.fn().mockResolvedValue({ count: 1 }) },
      account: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'account',
          userId: 'client',
          cashBalance: 0,
        }),
        update: jest.fn(),
      },
      user: { count: jest.fn().mockResolvedValue(1) },
      ipoDebt: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'debt',
            amount: 100,
            paidAmount: 0,
            ipoApplicationId: 'app',
            ipoApplication: {
              id: 'app',
              allocatedQuantity: 10,
              allocatedPrice: 10,
              allocatedAmount: 100,
              ipo: { symbol: 'ABC', instrumentId: 'stock', issuePrice: 10 },
            },
          },
        ]),
        update: jest.fn(),
      },
      ipoApplication: { update: jest.fn() },
      accountTransaction: { findUnique: jest.fn().mockResolvedValue(null), create: jest.fn() },
      notification: { create: jest.fn() },
      order: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({ id: 'order' }),
      },
      trade: { create: jest.fn() },
      position: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
      },
    };
    const prisma = {
      depositRequest: {
        findUnique: jest.fn().mockResolvedValue({
          status: 'PENDING',
          amount,
          accountId: 'account',
        }),
      },
      $transaction: (fn: any) => fn(tx),
    };
    const service = new DepositService(
      prisma as any,
      {
        createLog: jest.fn(),
      } as any,
    );
    return { service, tx };
  }

  it('partial deposit reduces debt without generating holdings', async () => {
    const { service, tx } = setup(40);
    const result = await service.approveDeposit(
      'deposit',
      'finance',
      'FINANCE',
    );
    expect(result.ipoRepayment).toEqual(new Prisma.Decimal(40));
    expect(result.creditedAmount).toEqual(new Prisma.Decimal(0));
    expect(tx.ipoDebt.update.mock.calls[0][0].data).toMatchObject({
      paidAmount: { increment: new Prisma.Decimal(40) },
      status: 'PARTIAL',
    });
    expect(tx.order.create).not.toHaveBeenCalled();
    expect(tx.position.create).not.toHaveBeenCalled();
  });

  it('full payment creates holdings and credits only surplus', async () => {
    const { service, tx } = setup(150);
    const result = await service.approveDeposit(
      'deposit',
      'finance',
      'FINANCE',
    );
    expect(result.ipoRepayment).toEqual(new Prisma.Decimal(100));
    expect(result.creditedAmount).toEqual(new Prisma.Decimal(50));
    expect(tx.position.create).toHaveBeenCalled();
    expect(tx.account.update.mock.calls[0][0].data).toEqual({
      cashBalance: { increment: new Prisma.Decimal(50) },
      buyingPower: { increment: new Prisma.Decimal(50) },
    });
    expect(tx.notification.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ type: 'IPO_ALLOTMENT_SETTLED' }),
      }),
    );
  });

  it('duplicate approval does not repay or create holdings again', async () => {
    const { service, tx } = setup(150);
    tx.depositRequest.updateMany.mockResolvedValue({ count: 0 });
    await expect(
      service.approveDeposit('deposit', 'finance', 'FINANCE'),
    ).rejects.toThrow('already processed');
    expect(tx.ipoDebt.update).not.toHaveBeenCalled();
    expect(tx.order.create).not.toHaveBeenCalled();
  });
});
