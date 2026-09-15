import { Prisma } from '../generated/prisma/client';
import { AdminAccountService } from './admin-account.service';

describe('AdminAccountService credit applies IPO debt', () => {
  function setup(creditAmount: number) {
    const account = {
      id: 'account',
      accountNumber: 'ACC1',
      cashBalance: new Prisma.Decimal(0),
      buyingPower: new Prisma.Decimal(0),
      frozenBalance: new Prisma.Decimal(0),
      user: { id: 'client' },
    };
    const tx = {
      account: {
        findFirst: jest.fn().mockResolvedValue(account),
        update: jest.fn().mockImplementation(async ({ data }) => {
          const cashInc = data.cashBalance?.increment ?? 0;
          const bpInc = data.buyingPower?.increment ?? 0;
          account.cashBalance = moneyAdd(account.cashBalance, cashInc);
          account.buyingPower = moneyAdd(account.buyingPower, bpInc);
          return { ...account };
        }),
      },
      accountTransaction: {
        findFirst: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
      },
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
      notification: { create: jest.fn() },
      order: { findUnique: jest.fn().mockResolvedValue(null), create: jest.fn().mockResolvedValue({ id: 'order' }) },
      trade: { create: jest.fn() },
      position: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
      },
    };
    const prisma = {
      $transaction: (fn: any) => fn(tx),
    };
    const service = new AdminAccountService(
      prisma as any,
      { createLog: jest.fn() } as any,
      {} as any,
    );
    return { service, tx, creditAmount };
  }

  function moneyAdd(base: Prisma.Decimal, delta: Prisma.Decimal | number) {
    return new Prisma.Decimal(base).add(new Prisma.Decimal(delta));
  }

  it('partial credit reduces IPO debt without crediting surplus cash', async () => {
    const { service, tx } = setup(40);
    const result = await service.credit(
      'ACC1',
      { amount: '40', referenceId: 'REF-PARTIAL' },
      'finance-1',
      'FINANCE',
    );
    expect(result.ipoRepayment).toBe('40.00');
    expect(result.creditedAmount).toBe('0.00');
    expect(tx.ipoDebt.update).toHaveBeenCalled();
    expect(tx.account.update).not.toHaveBeenCalled();
    expect(tx.position.create).not.toHaveBeenCalled();
  });

  it('full credit settles holdings and credits only surplus', async () => {
    const { service, tx } = setup(150);
    const result = await service.credit(
      'ACC1',
      { amount: '150', referenceId: 'REF-FULL', note: 'Wire ABC123' },
      'finance-1',
      'FINANCE',
    );
    expect(result.ipoRepayment).toBe('100.00');
    expect(result.creditedAmount).toBe('50.00');
    expect(tx.ipoApplication.update).toHaveBeenCalledWith({
      where: { id: 'app' },
      data: { paymentStatus: 'PAID' },
    });
    expect(tx.position.create).toHaveBeenCalled();
    expect(tx.account.update).toHaveBeenCalledWith({
      where: { id: 'account' },
      data: {
        cashBalance: { increment: new Prisma.Decimal(50) },
        buyingPower: { increment: new Prisma.Decimal(50) },
      },
    });
    expect(tx.accountTransaction.create).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          note: 'Wire ABC123; 100.00 applied to IPO debt',
        }),
      }),
    );
  });

  it('credit without debts credits the full amount', async () => {
    const { service, tx } = setup(80);
    tx.ipoDebt.findMany.mockResolvedValue([]);
    const result = await service.credit(
      'ACC1',
      { amount: '80', referenceId: 'REF-NONE' },
      'finance-1',
      'FINANCE',
    );
    expect(result.ipoRepayment).toBe('0.00');
    expect(result.creditedAmount).toBe('80.00');
    expect(tx.account.update).toHaveBeenCalled();
  });
});
