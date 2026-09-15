import { BadRequestException, NotFoundException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { OrderCancellationService } from './order-cancellation.service';

describe('OrderCancellationService', () => {
  const freezeService = {
    releaseBuy: jest.fn(),
    releaseSell: jest.fn(),
  } as any;

  function createService(order: any) {
    const tx = {
      order: {
        findFirst: jest.fn().mockResolvedValue(order),
        update: jest.fn(),
      },
      position: {
        findUnique: jest.fn(),
      },
      notification: {
        create: jest.fn().mockResolvedValue({}),
      },
    } as any;

    const prisma = {
      $transaction: jest.fn(async (fn: any) => fn(tx)),
    } as any;

    return {
      service: new OrderCancellationService(prisma, freezeService),
      tx,
    };
  }

  beforeEach(() => {
    jest.clearAllMocks();
  });

  it('rejects cancellation when order is missing', async () => {
    const { service } = createService(null);

    await expect(service.cancel('user-1', 'order-1')).rejects.toBeInstanceOf(
      NotFoundException,
    );
  });

  it('rejects cancellation for a completed order', async () => {
    const { service } = createService({
      status: 'FILLED',
      quantity: 1,
      filledQuantity: 1,
    });

    await expect(service.cancel('user-1', 'order-1')).rejects.toBeInstanceOf(
      BadRequestException,
    );
  });

  it('releases BUY frozen amount before cancellation', async () => {
    const order = {
      id: 'order-1',
      status: 'OPEN',
      side: 'BUY',
      quantity: 2,
      filledQuantity: 0,
      accountId: 'account-1',
      instrumentId: 'instrument-1',
      frozenAmount: new Prisma.Decimal('200'),
      account: {
        userId: 'user-1',
        cashBalance: new Prisma.Decimal('1000'),
      },
      instrument: { symbol: 'TCS' },
    };

    const { service, tx } = createService(order);
    tx.order.update.mockResolvedValue({ id: 'order-1', status: 'CANCELLED' });

    await service.cancel('user-1', 'order-1');

    expect(freezeService.releaseBuy).toHaveBeenCalledWith(
      tx,
      'account-1',
      order.account.cashBalance,
      order.frozenAmount,
      'order-1',
      'Released funds after order cancellation',
    );
    expect(tx.notification.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        userId: 'user-1',
        type: 'TRADE',
        title: 'Order cancelled',
        referenceId: 'order-1',
      }),
    });
  });

  it('expires an active DAY BUY without a user ownership filter and releases funds', async () => {
    const order = {
      id: 'day-buy',
      status: 'OPEN',
      side: 'BUY',
      quantity: 2,
      filledQuantity: 0,
      accountId: 'account-1',
      instrumentId: 'instrument-1',
      frozenAmount: new Prisma.Decimal('200'),
      account: { cashBalance: new Prisma.Decimal('1000') },
    };
    const { service, tx } = createService(order);
    tx.order.update.mockResolvedValue({ id: order.id, status: 'CANCELLED' });

    await service.expireDayOrder(order.id);

    expect(tx.order.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: { id: order.id } }),
    );
    expect(freezeService.releaseBuy).toHaveBeenCalledWith(
      tx,
      'account-1',
      order.account.cashBalance,
      order.frozenAmount,
      order.id,
      'Released funds after DAY order expiry',
    );
  });

  it('treats an already-completed order as a no-op during system expiry', async () => {
    const order = {
      id: 'filled-order',
      status: 'FILLED',
      quantity: 2,
      filledQuantity: 2,
    };
    const { service, tx } = createService(order);

    await expect(service.expireDayOrder(order.id)).resolves.toEqual({
      cancelled: false,
      order,
    });
    expect(tx.order.update).not.toHaveBeenCalled();
    expect(freezeService.releaseBuy).not.toHaveBeenCalled();
    expect(freezeService.releaseSell).not.toHaveBeenCalled();
  });

  it('releases only the unfilled SELL quantity after a partial fill', async () => {
    const order = {
      id: 'sell-partial',
      status: 'PARTIALLY_FILLED',
      side: 'SELL',
      quantity: 8,
      filledQuantity: 5,
      accountId: 'account-1',
      instrumentId: 'instrument-1',
      frozenAmount: new Prisma.Decimal('0'),
      account: { cashBalance: new Prisma.Decimal('1500') },
    };

    const { service, tx } = createService(order);
    tx.position.findUnique.mockResolvedValue({
      id: 'position-1',
      quantity: 5,
      frozenQuantity: 3,
    });
    tx.order.update.mockResolvedValue({
      id: order.id,
      status: 'CANCELLED',
      filledQuantity: 5,
    });

    await service.cancel('user-1', order.id);

    expect(freezeService.releaseSell).toHaveBeenCalledWith(tx, 'position-1', 3);
    expect(freezeService.releaseBuy).not.toHaveBeenCalled();
    expect(tx.order.update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          status: 'CANCELLED',
          frozenAmount: new Prisma.Decimal(0),
        }),
      }),
    );
  });
});
