import { BadRequestException, ConflictException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { OrderPreparationService } from './order-preparation.service';

describe('OrderPreparationService', () => {
  const config = { get: jest.fn().mockReturnValue(undefined) } as any;
  const service = new OrderPreparationService(config);

  it('requires limitPrice for LIMIT orders', () => {
    expect(() =>
      service.validateOrderRequest({
        clientOrderId: 'client-123',
        exchange: 'NSE',
        symbol: 'RELIANCE',
        side: 'BUY',
        type: 'LIMIT',
        timeInForce: 'DAY',
        quantity: 1,
      } as any),
    ).toThrow(BadRequestException);
  });

  it('rejects limitPrice for MARKET orders', () => {
    expect(() =>
      service.validateOrderRequest({
        clientOrderId: 'client-123',
        exchange: 'NSE',
        symbol: 'RELIANCE',
        side: 'BUY',
        type: 'MARKET',
        timeInForce: 'DAY',
        quantity: 1,
        limitPrice: '100.00',
      } as any),
    ).toThrow(BadRequestException);
  });

  it('rejects stale quotes before execution pricing', () => {
    expect(() =>
      (service as any).assertQuoteFresh(new Date(Date.now() - 120001)),
    ).toThrow('Market quote is temporarily unavailable');
  });

  it('accepts a recent quote', () => {
    expect(() =>
      (service as any).assertQuoteFresh(new Date(Date.now() - 30000)),
    ).not.toThrow();
  });

  it('allows small upstream clock skew but rejects a future quote', () => {
    expect(() =>
      (service as any).assertQuoteFresh(new Date(Date.now() + 3000)),
    ).not.toThrow();
    expect(() =>
      (service as any).assertQuoteFresh(new Date(Date.now() + 10000)),
    ).toThrow('Market quote is temporarily unavailable');
  });

  it('rejects non-positive or crossed execution quotes', () => {
    expect(() =>
      (service as any).assertQuotePrices(new Prisma.Decimal(0), null, null),
    ).toThrow('Market quote is temporarily unavailable');
    expect(() =>
      (service as any).assertQuotePrices(
        new Prisma.Decimal(100),
        new Prisma.Decimal(101),
        new Prisma.Decimal(100),
      ),
    ).toThrow('Market quote is temporarily unavailable');
  });

  it('rejects reuse of clientOrderId for a different order', async () => {
    const existing = {
      instrument: { exchange: 'NSE', symbol: 'RELIANCE' },
      side: 'BUY',
      type: 'LIMIT',
      timeInForce: 'DAY',
      quantity: 1,
      limitPrice: { equals: () => false },
    } as any;

    const prisma = {
      order: { findFirst: jest.fn().mockResolvedValue(existing) },
    } as any;

    await expect(
      service.getIdempotentOrder(prisma, 'user-1', {
        clientOrderId: 'client-123',
        exchange: 'NSE',
        symbol: 'RELIANCE',
        side: 'BUY',
        type: 'LIMIT',
        timeInForce: 'DAY',
        quantity: 1,
        limitPrice: '101.00',
      } as any),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  function freshQuote() {
    return {
      lastPrice: new Prisma.Decimal('100.00'),
      bidPrice: new Prisma.Decimal('99.95'),
      askPrice: new Prisma.Decimal('100.05'),
      asOf: new Date(),
    };
  }

  function prepareTx(instrument: Record<string, unknown>) {
    return {
      account: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'acct-1',
          isLive: true,
          currency: 'INR',
          cashBalance: new Prisma.Decimal('100000'),
        }),
      },
      order: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn(),
      },
      instrument: {
        findUnique: jest.fn().mockResolvedValue(instrument),
      },
      accountTransaction: { create: jest.fn() },
      position: { findUnique: jest.fn(), update: jest.fn() },
    };
  }

  const marketBuyDto = {
    clientOrderId: 'client-buy-1',
    exchange: 'NSE',
    symbol: 'RELIANCE',
    side: 'BUY',
    type: 'MARKET',
    timeInForce: 'DAY',
    quantity: 1,
  } as any;

  it('allows a standard BUY on ordinary NSE equity', async () => {
    const tx = prepareTx({
      id: 'inst-nse',
      isActive: true,
      category: 'EQUITY',
      currency: 'INR',
      tickSize: new Prisma.Decimal('0.05'),
      quote: freshQuote(),
    });

    const result = await service.prepare(tx as any, 'user-1', marketBuyDto);

    expect(result.idempotentReplay).toBe(false);
    expect(result.instrument).toEqual(
      expect.objectContaining({ id: 'inst-nse' }),
    );
    expect(tx.order.create).not.toHaveBeenCalled();
    expect(tx.position.update).not.toHaveBeenCalled();
  });

  it('allows a standard SELL on ordinary NSE equity', async () => {
    const tx = prepareTx({
      id: 'inst-nse',
      isActive: true,
      category: null,
      currency: 'INR',
      tickSize: new Prisma.Decimal('0.05'),
      quote: freshQuote(),
    });

    const result = await service.prepare(tx as any, 'user-1', {
      ...marketBuyDto,
      side: 'SELL',
      clientOrderId: 'client-sell-1',
    });

    expect(result.idempotentReplay).toBe(false);
    expect(result.instrument).toEqual(
      expect.objectContaining({ id: 'inst-nse' }),
    );
  });

  it('allows a standard BUY on ordinary BSE equity', async () => {
    const tx = prepareTx({
      id: 'inst-bse',
      isActive: true,
      category: 'EQUITY',
      currency: 'INR',
      tickSize: new Prisma.Decimal('0.05'),
      quote: freshQuote(),
    });

    const result = await service.prepare(tx as any, 'user-1', {
      ...marketBuyDto,
      exchange: 'BSE',
      symbol: 'RELIANCE',
      clientOrderId: 'client-bse-1',
    });

    expect(result.idempotentReplay).toBe(false);
    expect(result.instrument).toEqual(
      expect.objectContaining({ id: 'inst-bse' }),
    );
  });

  it.each(['IPO', 'ipo', 'IpO', 'OTC', 'INSTITUTIONAL', 'INST', 'LIMIT_UP'])(
    'rejects a standard order for protected category %s before freeze, order creation or matching',
    async (category) => {
      const tx = prepareTx({
        id: 'special-1',
        isActive: true,
        category,
        currency: 'INR',
        tickSize: new Prisma.Decimal('0.05'),
        quote: freshQuote(),
      });

      await expect(
        service.prepare(tx as any, 'user-1', marketBuyDto),
      ).rejects.toThrow(
        'Instrument is not available for standard market trading',
      );

      expect(tx.order.create).not.toHaveBeenCalled();
      expect(tx.position.update).not.toHaveBeenCalled();
      expect(tx.accountTransaction.create).not.toHaveBeenCalled();
    },
  );
});
