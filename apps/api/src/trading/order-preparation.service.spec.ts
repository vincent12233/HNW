import { BadRequestException, ConflictException } from '@nestjs/common';
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
      (service as any).assertQuoteFresh(
        new Date(Date.now() - 120001),
      ),
    ).toThrow('Market quote is temporarily unavailable');
  });

  it('accepts a recent quote', () => {
    expect(() =>
      (service as any).assertQuoteFresh(new Date(Date.now() - 30000)),
    ).not.toThrow();
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
});
