import { ConflictException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { MatchingService } from './matching.service';

describe('MatchingService consistency guards', () => {
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

  it('rejects BUY settlement when current cash balance is insufficient', async () => {
    const price = new Prisma.Decimal('100');
    const order = {
      id: 'buy-cash-short',
      accountId: 'account-1',
      instrumentId: 'instrument-1',
      side: 'BUY',
      type: 'LIMIT',
      timeInForce: 'DAY',
      status: 'OPEN',
      quantity: 2,
      filledQuantity: 0,
      limitPrice: new Prisma.Decimal('100'),
      averageFillPrice: null,
      frozenAmount: new Prisma.Decimal('200'),
      account: { cashBalance: new Prisma.Decimal('1000') },
      instrument: {
        exchange: 'NSE',
        symbol: 'RELIANCE',
        quote: { askPrice: price, bidPrice: price, lastPrice: price },
      },
    };

    const tx = {
      order: { findUnique: jest.fn().mockResolvedValue(order) },
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          cashBalance: new Prisma.Decimal('150'),
          frozenBalance: new Prisma.Decimal('200'),
        }),
      },
    } as any;

    await expect(createService(tx).matchOrder(order.id)).rejects.toThrow(
      'Insufficient cash balance during settlement',
    );
  });

  it('rejects SELL settlement when frozen quantity is insufficient', async () => {
    const price = new Prisma.Decimal('125');
    const order = {
      id: 'sell-freeze-short',
      accountId: 'account-1',
      instrumentId: 'instrument-1',
      side: 'SELL',
      type: 'LIMIT',
      timeInForce: 'DAY',
      status: 'OPEN',
      quantity: 2,
      filledQuantity: 0,
      limitPrice: new Prisma.Decimal('120'),
      averageFillPrice: null,
      frozenAmount: new Prisma.Decimal('0'),
      account: { cashBalance: new Prisma.Decimal('500') },
      instrument: {
        exchange: 'NSE',
        symbol: 'RELIANCE',
        quote: { askPrice: price, bidPrice: price, lastPrice: price },
      },
    };

    const tx = {
      order: { findUnique: jest.fn().mockResolvedValue(order) },
      position: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          id: 'position-1',
          quantity: 5,
          frozenQuantity: 1,
          averagePrice: new Prisma.Decimal('100'),
        }),
      },
    } as any;

    await expect(createService(tx).matchOrder(order.id)).rejects.toBeInstanceOf(
      ConflictException,
    );
  });
});
