import { ConflictException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { MatchingService } from './matching.service';

describe('MatchingService', () => {
  const config = {
    get: jest.fn((key: string) =>
      key === 'MATCHING_MAX_FILL_QUANTITY' ? '5' : undefined,
    ),
  } as any;

  function createService(tx: any) {
    const prisma = {
      $transaction: jest.fn(async (fn: any) => fn(tx)),
    } as any;
    return new MatchingService(prisma, config);
  }

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('settles a BUY fill using current account balances', async () => {
    const price = new Prisma.Decimal('100');
    const order = {
      id: 'order-buy', accountId: 'account-1', instrumentId: 'instrument-1',
      side: 'BUY', type: 'LIMIT', timeInForce: 'DAY', status: 'OPEN',
      quantity: 2, filledQuantity: 0, limitPrice: new Prisma.Decimal('100'),
      averageFillPrice: null, frozenAmount: new Prisma.Decimal('200'),
      account: { cashBalance: new Prisma.Decimal('999') },
      instrument: { exchange: 'NSE', symbol: 'RELIANCE', quote: { askPrice: price, bidPrice: price, lastPrice: price } },
    };
    const tx = {
      order: { findUnique: jest.fn().mockResolvedValueOnce(order).mockResolvedValueOnce({ id: order.id, status: 'FILLED' }), update: jest.fn() },
      account: { findUniqueOrThrow: jest.fn().mockResolvedValue({ cashBalance: new Prisma.Decimal('1000'), frozenBalance: new Prisma.Decimal('200') }), update: jest.fn().mockResolvedValue({ cashBalance: new Prisma.Decimal('800') }) },
      accountTransaction: { create: jest.fn() },
      position: { findUnique: jest.fn().mockResolvedValue(null), upsert: jest.fn() },
      trade: { create: jest.fn() },
    } as any;
    await createService(tx).matchOrder(order.id);
    expect(tx.accountTransaction.create).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ balanceBefore: new Prisma.Decimal('1000'), balanceAfter: new Prisma.Decimal('800') }) }));
    expect(tx.trade.create).toHaveBeenCalled();
  });

  it('settles a SELL fill and reduces both quantity and frozen quantity', async () => {
    const price = new Prisma.Decimal('125');
    const order = {
      id: 'order-sell', accountId: 'account-1', instrumentId: 'instrument-1',
      side: 'SELL', type: 'LIMIT', timeInForce: 'DAY', status: 'OPEN',
      quantity: 2, filledQuantity: 0, limitPrice: new Prisma.Decimal('120'),
      averageFillPrice: null, frozenAmount: new Prisma.Decimal('0'),
      account: { cashBalance: new Prisma.Decimal('999') },
      instrument: { exchange: 'NSE', symbol: 'RELIANCE', quote: { askPrice: price, bidPrice: price, lastPrice: price } },
    };
    const tx = {
      order: { findUnique: jest.fn().mockResolvedValueOnce(order).mockResolvedValueOnce({ id: order.id, status: 'FILLED' }), update: jest.fn() },
      account: { findUniqueOrThrow: jest.fn().mockResolvedValue({ cashBalance: new Prisma.Decimal('500') }), update: jest.fn().mockResolvedValue({ cashBalance: new Prisma.Decimal('750') }) },
      accountTransaction: { create: jest.fn() },
      position: { findUniqueOrThrow: jest.fn().mockResolvedValue({ id: 'position-1', quantity: 5, frozenQuantity: 2, averagePrice: new Prisma.Decimal('100') }), update: jest.fn() },
      trade: { create: jest.fn() },
    } as any;
    await createService(tx).matchOrder(order.id);
    expect(tx.position.update).toHaveBeenCalledWith(expect.objectContaining({ where: { id: 'position-1' }, data: expect.objectContaining({ quantity: { decrement: 2 }, frozenQuantity: { decrement: 2 } }) }));
  });

  it('cancels a FOK BUY remainder and releases frozen funds when full fill is unavailable', async () => {
    const price = new Prisma.Decimal('100');
    const order = {
      id: 'order-fok', accountId: 'account-1', instrumentId: 'instrument-1',
      side: 'BUY', type: 'LIMIT', timeInForce: 'FOK', status: 'OPEN',
      quantity: 10, filledQuantity: 0, limitPrice: new Prisma.Decimal('100'),
      averageFillPrice: null, frozenAmount: new Prisma.Decimal('1000'),
      account: { cashBalance: new Prisma.Decimal('1000') },
      instrument: { exchange: 'NSE', symbol: 'RELIANCE', quote: { askPrice: price, bidPrice: price, lastPrice: price } },
    };
    const tx = {
      order: { findUnique: jest.fn().mockResolvedValueOnce(order).mockResolvedValueOnce({ id: order.id, status: 'CANCELLED' }), update: jest.fn() },
      account: { findUniqueOrThrow: jest.fn().mockResolvedValue({ cashBalance: new Prisma.Decimal('1000'), frozenBalance: new Prisma.Decimal('1000') }), update: jest.fn() },
      accountTransaction: { create: jest.fn() }, position: {}, trade: { create: jest.fn() },
    } as any;
    await createService(tx).matchOrder(order.id);
    expect(tx.trade.create).not.toHaveBeenCalled();
    expect(tx.order.update).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ status: 'CANCELLED' }) }));
  });

  it('partially fills an IOC order then cancels and releases the remainder', async () => {
    const price = new Prisma.Decimal('100');
    const initialOrder = {
      id: 'order-ioc', accountId: 'account-1', instrumentId: 'instrument-1',
      side: 'BUY', type: 'LIMIT', timeInForce: 'IOC', status: 'OPEN',
      quantity: 8, filledQuantity: 0, limitPrice: new Prisma.Decimal('100'),
      averageFillPrice: null, frozenAmount: new Prisma.Decimal('800'),
      account: { cashBalance: new Prisma.Decimal('1000') },
      instrument: { exchange: 'NSE', symbol: 'RELIANCE', quote: { askPrice: price, bidPrice: price, lastPrice: price } },
    };
    const partiallyFilled = { ...initialOrder, status: 'PARTIALLY_FILLED', filledQuantity: 5, frozenAmount: new Prisma.Decimal('300') };
    const tx = {
      order: {
        findUnique: jest.fn()
          .mockResolvedValueOnce(initialOrder)
          .mockResolvedValueOnce(partiallyFilled)
          .mockResolvedValueOnce({ id: initialOrder.id, status: 'CANCELLED' }),
        findUniqueOrThrow: jest.fn().mockResolvedValue(partiallyFilled),
        update: jest.fn(),
      },
      account: {
        findUniqueOrThrow: jest.fn()
          .mockResolvedValueOnce({ cashBalance: new Prisma.Decimal('1000'), frozenBalance: new Prisma.Decimal('800') })
          .mockResolvedValueOnce({ cashBalance: new Prisma.Decimal('500'), frozenBalance: new Prisma.Decimal('300') }),
        update: jest.fn().mockResolvedValue({ cashBalance: new Prisma.Decimal('500') }),
      },
      accountTransaction: { create: jest.fn() },
      position: { findUnique: jest.fn().mockResolvedValue(null), upsert: jest.fn() },
      trade: { create: jest.fn() },
    } as any;

    await createService(tx).matchOrder(initialOrder.id);

    expect(tx.trade.create).toHaveBeenCalledTimes(1);
    expect(tx.order.update).toHaveBeenCalledWith(expect.objectContaining({ data: expect.objectContaining({ status: 'CANCELLED' }) }));
    expect(tx.account.update).toHaveBeenCalledTimes(2);
  });

  it('rejects BUY settlement when frozen balance is inconsistent', async () => {
    const price = new Prisma.Decimal('100');
    const order = {
      id: 'order-bad-buy', accountId: 'account-1', instrumentId: 'instrument-1',
      side: 'BUY', type: 'LIMIT', timeInForce: 'DAY', status: 'OPEN',
      quantity: 2, filledQuantity: 0, limitPrice: new Prisma.Decimal('100'), averageFillPrice: null,
      frozenAmount: new Prisma.Decimal('200'), account: { cashBalance: new Prisma.Decimal('1000') },
      instrument: { exchange: 'NSE', symbol: 'RELIANCE', quote: { askPrice: price, bidPrice: price, lastPrice: price } },
    };
    const tx = {
      order: { findUnique: jest.fn().mockResolvedValue(order) },
      account: { findUniqueOrThrow: jest.fn().mockResolvedValue({ cashBalance: new Prisma.Decimal('1000'), frozenBalance: new Prisma.Decimal('50') }) },
    } as any;

    await expect(createService(tx).matchOrder(order.id)).rejects.toBeInstanceOf(ConflictException);
  });
});
