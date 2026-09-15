import { BadRequestException, ConflictException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { MatchingService } from '../matching/matching.service';
import { OrderCancellationService } from './order-cancellation.service';

describe('order match/cancel race guards', () => {
  const config = {
    get: jest.fn((key: string) => {
      if (key === 'MATCHING_MAX_FILL_QUANTITY') return '5';
      if (key === 'ORDER_QUOTE_MAX_AGE_MS') return '120000';
      return undefined;
    }),
  } as any;

  const p2034 = () => {
    const error: any = new Error('serialization conflict');
    error.code = 'P2034';
    return error;
  };

  const freshQuote = (price: Prisma.Decimal) => ({
    askPrice: price,
    bidPrice: price,
    lastPrice: price,
    asOf: new Date(),
  });

  it('matching retries after a commit conflict and stops when cancellation won', async () => {
    const price = new Prisma.Decimal('100');
    const activeOrder = {
      id: 'order-race-match',
      accountId: 'account-1',
      instrumentId: 'instrument-1',
      side: 'BUY',
      type: 'LIMIT',
      timeInForce: 'DAY',
      status: 'OPEN',
      quantity: 1,
      filledQuantity: 0,
      limitPrice: new Prisma.Decimal('100'),
      averageFillPrice: null,
      frozenAmount: new Prisma.Decimal('100'),
      account: { cashBalance: new Prisma.Decimal('1000') },
      instrument: {
        exchange: 'NSE',
        symbol: 'RELIANCE',
        quote: freshQuote(price),
      },
    };

    const firstTx = {
      order: {
        findUnique: jest
          .fn()
          .mockResolvedValueOnce(activeOrder)
          .mockResolvedValueOnce({ id: activeOrder.id, status: 'FILLED' }),
        update: jest.fn(),
      },
      account: {
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          cashBalance: new Prisma.Decimal('1000'),
          frozenBalance: new Prisma.Decimal('100'),
        }),
        update: jest.fn().mockResolvedValue({
          cashBalance: new Prisma.Decimal('900'),
        }),
      },
      accountTransaction: { create: jest.fn() },
      position: {
        findUnique: jest.fn().mockResolvedValue(null),
        upsert: jest.fn(),
      },
      trade: { create: jest.fn() },
    } as any;

    const secondTx = {
      order: {
        findUnique: jest.fn().mockResolvedValue({
          ...activeOrder,
          status: 'CANCELLED',
          cancelledAt: new Date(),
        }),
      },
      accountTransaction: { create: jest.fn() },
      trade: { create: jest.fn() },
      account: { update: jest.fn() },
      position: { upsert: jest.fn(), update: jest.fn() },
    } as any;

    let attempt = 0;
    const prisma = {
      $transaction: jest.fn(async (fn: any) => {
        attempt += 1;
        if (attempt === 1) {
          await fn(firstTx);
          throw p2034();
        }
        return fn(secondTx);
      }),
    } as any;

    const service = new MatchingService(prisma, config);
    const result = await service.matchOrder(activeOrder.id);

    expect(prisma.$transaction).toHaveBeenCalledTimes(2);
    expect(firstTx.trade.create).toHaveBeenCalledTimes(1);
    expect(firstTx.accountTransaction.create).toHaveBeenCalledTimes(1);
    expect(secondTx.trade.create).not.toHaveBeenCalled();
    expect(secondTx.accountTransaction.create).not.toHaveBeenCalled();
    expect(secondTx.account.update).not.toHaveBeenCalled();
    expect(result?.status).toBe('CANCELLED');
  });

  it('cancellation retries after a commit conflict and stops when matching won', async () => {
    const activeOrder = {
      id: 'order-race-cancel',
      status: 'OPEN',
      side: 'BUY',
      quantity: 1,
      filledQuantity: 0,
      accountId: 'account-1',
      instrumentId: 'instrument-1',
      frozenAmount: new Prisma.Decimal('100'),
      account: { cashBalance: new Prisma.Decimal('1000') },
      instrument: { exchange: 'NSE', symbol: 'RELIANCE' },
      trades: [],
    };

    const firstTx = {
      order: {
        findFirst: jest.fn().mockResolvedValue(activeOrder),
        update: jest.fn().mockResolvedValue({
          ...activeOrder,
          status: 'CANCELLED',
        }),
      },
      position: { findUnique: jest.fn() },
    } as any;

    const secondTx = {
      order: {
        findFirst: jest.fn().mockResolvedValue({
          ...activeOrder,
          status: 'FILLED',
          filledQuantity: 1,
          frozenAmount: new Prisma.Decimal('0'),
        }),
        update: jest.fn(),
      },
      position: { findUnique: jest.fn() },
    } as any;

    const freezeService = {
      releaseBuy: jest.fn(),
      releaseSell: jest.fn(),
    } as any;

    let attempt = 0;
    const prisma = {
      $transaction: jest.fn(async (fn: any) => {
        attempt += 1;
        if (attempt === 1) {
          await fn(firstTx);
          throw p2034();
        }
        return fn(secondTx);
      }),
    } as any;

    const service = new OrderCancellationService(prisma, freezeService);

    await expect(
      service.cancel('user-1', activeOrder.id),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(prisma.$transaction).toHaveBeenCalledTimes(2);
    expect(freezeService.releaseBuy).toHaveBeenCalledTimes(1);
    expect(freezeService.releaseSell).not.toHaveBeenCalled();
    expect(secondTx.order.update).not.toHaveBeenCalled();
  });

  it('matching converts an exhausted serialization retry into ConflictException', async () => {
    const prisma = {
      $transaction: jest.fn(async () => {
        throw p2034();
      }),
    } as any;

    const service = new MatchingService(prisma, config);

    await expect(service.matchOrder('order-1')).rejects.toThrow(
      'Concurrent order update detected; please retry',
    );
    await expect(service.matchOrder('order-1')).rejects.toBeInstanceOf(
      ConflictException,
    );
  });

  it('cancellation converts an exhausted serialization retry into ConflictException', async () => {
    const prisma = {
      $transaction: jest.fn(async () => {
        throw p2034();
      }),
    } as any;
    const freezeService = {
      releaseBuy: jest.fn(),
      releaseSell: jest.fn(),
    } as any;

    const service = new OrderCancellationService(prisma, freezeService);

    await expect(service.cancel('user-1', 'order-1')).rejects.toThrow(
      'Concurrent order update detected; please retry',
    );
    await expect(service.cancel('user-1', 'order-1')).rejects.toBeInstanceOf(
      ConflictException,
    );
  });
});
