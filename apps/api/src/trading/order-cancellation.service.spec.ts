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
      account: { cashBalance: new Prisma.Decimal('1000') },
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
  });
});
