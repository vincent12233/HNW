import { Prisma } from '../generated/prisma/client';
import { MatchingService } from './matching.service';

describe('MatchingService partial SELL accounting', () => {
  const config = {
    get: jest.fn((key: string) => {
      if (key === 'MATCHING_MAX_FILL_QUANTITY') return '5';
      if (key === 'ORDER_QUOTE_MAX_AGE_MS') return '120000';
      return undefined;
    }),
  } as any;

  function freshQuote(price: Prisma.Decimal) {
    return {
      askPrice: price,
      bidPrice: price,
      lastPrice: price,
      asOf: new Date(),
    };
  }

  function createService(tx: any) {
    const prisma = {
      $transaction: jest.fn(async (fn: any) => fn(tx)),
    } as any;
    return new MatchingService(prisma, config);
  }

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('partially fills SELL while preserving quantity, frozen quantity, cash and P&L invariants', async () => {
    const price = new Prisma.Decimal('125');
    const order = {
      id: 'sell-partial',
      accountId: 'account-1',
      instrumentId: 'instrument-1',
      side: 'SELL',
      type: 'LIMIT',
      timeInForce: 'DAY',
      status: 'OPEN',
      quantity: 8,
      filledQuantity: 0,
      limitPrice: new Prisma.Decimal('120'),
      averageFillPrice: null,
      frozenAmount: new Prisma.Decimal('0'),
      account: { cashBalance: new Prisma.Decimal('500') },
      instrument: {
        exchange: 'NSE',
        symbol: 'RELIANCE',
        quote: freshQuote(price),
      },
    };
    const tx = {
      order: {
        findUnique: jest
          .fn()
          .mockResolvedValueOnce(order)
          .mockResolvedValueOnce({ id: order.id, status: 'PARTIALLY_FILLED' }),
        update: jest.fn(),
      },
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          cashBalance: new Prisma.Decimal('500'),
        }),
        update: jest.fn().mockResolvedValue({
          cashBalance: new Prisma.Decimal('1125'),
        }),
      },
      accountTransaction: { create: jest.fn() },
      position: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: 'position-1',
          quantity: 8,
          frozenQuantity: 8,
          averagePrice: new Prisma.Decimal('100'),
        }),
        update: jest.fn(),
      },
      trade: { create: jest.fn() },
    } as any;

    await createService(tx).matchOrder(order.id);

    expect(tx.account.update).toHaveBeenCalledWith({
      where: { id: 'account-1' },
      data: {
        cashBalance: { increment: new Prisma.Decimal('625') },
        buyingPower: { increment: new Prisma.Decimal('625') },
      },
    });
    expect(tx.position.update).toHaveBeenCalledWith({
      where: { id: 'position-1' },
      data: {
        quantity: { decrement: 5 },
        frozenQuantity: { decrement: 5 },
        averagePrice: new Prisma.Decimal('100'),
        realizedPnl: { increment: new Prisma.Decimal('125') },
      },
    });
    expect(tx.order.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: 'PARTIALLY_FILLED',
          filledQuantity: 5,
          averageFillPrice: new Prisma.Decimal('125'),
          frozenAmount: new Prisma.Decimal('0'),
        }),
      }),
    );
  });

  it('weights averageFillPrice across later SELL fills and keeps position cost basis unchanged', async () => {
    const price = new Prisma.Decimal('110');
    const order = {
      id: 'sell-later-fill',
      accountId: 'account-1',
      instrumentId: 'instrument-1',
      side: 'SELL',
      type: 'LIMIT',
      timeInForce: 'DAY',
      status: 'PARTIALLY_FILLED',
      quantity: 8,
      filledQuantity: 5,
      limitPrice: new Prisma.Decimal('105'),
      averageFillPrice: new Prisma.Decimal('125'),
      frozenAmount: new Prisma.Decimal('0'),
      account: { cashBalance: new Prisma.Decimal('1125') },
      instrument: {
        exchange: 'NSE',
        symbol: 'RELIANCE',
        quote: freshQuote(price),
      },
    };
    const tx = {
      order: {
        findUnique: jest
          .fn()
          .mockResolvedValueOnce(order)
          .mockResolvedValueOnce({ id: order.id, status: 'FILLED' }),
        update: jest.fn(),
      },
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          cashBalance: new Prisma.Decimal('1125'),
        }),
        update: jest.fn().mockResolvedValue({
          cashBalance: new Prisma.Decimal('1455'),
        }),
      },
      accountTransaction: { create: jest.fn() },
      position: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: 'position-1',
          quantity: 5,
          frozenQuantity: 3,
          averagePrice: new Prisma.Decimal('100'),
        }),
        update: jest.fn(),
      },
      trade: { create: jest.fn() },
    } as any;

    await createService(tx).matchOrder(order.id);

    expect(tx.position.update).toHaveBeenCalledWith({
      where: { id: 'position-1' },
      data: {
        quantity: { decrement: 3 },
        frozenQuantity: { decrement: 3 },
        averagePrice: new Prisma.Decimal('100'),
        realizedPnl: { increment: new Prisma.Decimal('30') },
      },
    });
    expect(tx.order.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: 'FILLED',
          filledQuantity: 8,
          averageFillPrice: new Prisma.Decimal('119.375'),
        }),
      }),
    );
  });

  it('partially fills IOC SELL then releases exactly the unfilled frozen quantity', async () => {
    const price = new Prisma.Decimal('125');
    const initialOrder = {
      id: 'sell-ioc',
      accountId: 'account-1',
      instrumentId: 'instrument-1',
      side: 'SELL',
      type: 'LIMIT',
      timeInForce: 'IOC',
      status: 'OPEN',
      quantity: 8,
      filledQuantity: 0,
      limitPrice: new Prisma.Decimal('120'),
      averageFillPrice: null,
      frozenAmount: new Prisma.Decimal('0'),
      account: { cashBalance: new Prisma.Decimal('500') },
      instrument: {
        exchange: 'NSE',
        symbol: 'RELIANCE',
        quote: freshQuote(price),
      },
    };
    const partiallyFilled = {
      ...initialOrder,
      status: 'PARTIALLY_FILLED',
      filledQuantity: 5,
      averageFillPrice: new Prisma.Decimal('125'),
    };
    const tx = {
      order: {
        findUnique: jest
          .fn()
          .mockResolvedValueOnce(initialOrder)
          .mockResolvedValueOnce({ id: initialOrder.id, status: 'CANCELLED' }),
        findUniqueOrThrow: jest.fn().mockResolvedValue(partiallyFilled),
        update: jest.fn(),
      },
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          cashBalance: new Prisma.Decimal('500'),
        }),
        update: jest.fn().mockResolvedValue({
          cashBalance: new Prisma.Decimal('1125'),
        }),
      },
      accountTransaction: { create: jest.fn() },
      position: {
        findUniqueOrThrow: jest
          .fn()
          .mockResolvedValueOnce({
            id: 'position-1',
            quantity: 8,
            frozenQuantity: 8,
            averagePrice: new Prisma.Decimal('100'),
          })
          .mockResolvedValueOnce({
            id: 'position-1',
            quantity: 3,
            frozenQuantity: 3,
            averagePrice: new Prisma.Decimal('100'),
          }),
        update: jest.fn(),
      },
      trade: { create: jest.fn() },
    } as any;

    await createService(tx).matchOrder(initialOrder.id);

    expect(tx.trade.create).toHaveBeenCalledTimes(1);
    expect(tx.position.update).toHaveBeenNthCalledWith(1, {
      where: { id: 'position-1' },
      data: expect.objectContaining({
        quantity: { decrement: 5 },
        frozenQuantity: { decrement: 5 },
      }),
    });
    expect(tx.position.update).toHaveBeenNthCalledWith(2, {
      where: { id: 'position-1' },
      data: { frozenQuantity: { decrement: 3 } },
    });
    expect(tx.order.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({ status: 'CANCELLED' }),
      }),
    );
  });
});
