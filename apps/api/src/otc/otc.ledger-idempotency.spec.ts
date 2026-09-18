import { ConflictException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { OtcService } from './otc.service';

describe('OtcService ledger idempotency', () => {
  function buildOrder(id: string) {
    return {
      id,
      status: 'PENDING',
      accountId: 'account-1',
      instrumentId: 'inst-1',
      quantity: 2,
      price: new Prisma.Decimal(10),
      amount: new Prisma.Decimal(20),
      account: {
        id: 'account-1',
        cashBalance: new Prisma.Decimal(100),
        buyingPower: new Prisma.Decimal(100),
        frozenBalance: new Prisma.Decimal(0),
        user: {
          id: 'user-1',
          assignedBusinessId: 'biz-1',
          usedInviteCode: null,
        },
      },
    };
  }

  it('settles once with OTC_SETTLEMENT:{orderId}', async () => {
    const order = buildOrder('otc-1');
    const tx = {
      otcOrder: {
        findUnique: jest.fn().mockResolvedValue(order),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
        findUniqueOrThrow: jest.fn().mockResolvedValue({
          ...order,
          status: 'APPROVED',
          instrument: { symbol: 'ABC' },
        }),
      },
      user: { findUnique: jest.fn().mockResolvedValue({ role: 'ADMIN' }) },
      account: { update: jest.fn() },
      position: {
        findUnique: jest.fn().mockResolvedValue(null),
        upsert: jest.fn(),
      },
      order: { create: jest.fn().mockResolvedValue({ id: 'exec-order' }) },
      trade: { create: jest.fn() },
      accountTransaction: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest.fn().mockResolvedValue({
          id: 'ledger-1',
          idempotencyKey: 'OTC_SETTLEMENT:otc-1',
        }),
      },
      notification: { create: jest.fn() },
    };
    const service = new OtcService({
      $transaction: (fn: any) => fn(tx),
    } as any);

    await service.approve('admin-1', 'otc-1');
    expect(tx.accountTransaction.create).toHaveBeenCalledWith({
      data: expect.objectContaining({
        type: 'OTC_SETTLEMENT',
        idempotencyKey: 'OTC_SETTLEMENT:otc-1',
        referenceId: 'otc-1',
      }),
    });
  });

  it('rejects a second settlement for the same OTC order', async () => {
    const order = buildOrder('otc-1');
    const tx = {
      otcOrder: {
        findUnique: jest.fn().mockResolvedValue(order),
      },
      accountTransaction: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'existing',
          idempotencyKey: 'OTC_SETTLEMENT:otc-1',
        }),
        create: jest.fn(),
      },
      account: { update: jest.fn() },
    };
    const service = new OtcService({
      $transaction: (fn: any) => fn(tx),
    } as any);

    await expect(service.approve('admin-1', 'otc-1')).rejects.toBeInstanceOf(
      ConflictException,
    );
    expect(tx.account.update).not.toHaveBeenCalled();
    expect(tx.accountTransaction.create).not.toHaveBeenCalled();
  });

  it('allows different OTC orders to settle independently', async () => {
    async function settle(orderId: string) {
      const order = buildOrder(orderId);
      const tx = {
        otcOrder: {
          findUnique: jest.fn().mockResolvedValue(order),
          updateMany: jest.fn().mockResolvedValue({ count: 1 }),
          findUniqueOrThrow: jest.fn().mockResolvedValue({
            ...order,
            status: 'APPROVED',
            instrument: { symbol: 'ABC' },
          }),
        },
        user: { findUnique: jest.fn().mockResolvedValue({ role: 'ADMIN' }) },
        account: { update: jest.fn() },
        position: {
          findUnique: jest.fn().mockResolvedValue(null),
          upsert: jest.fn(),
        },
        order: { create: jest.fn().mockResolvedValue({ id: 'exec-order' }) },
        trade: { create: jest.fn() },
        accountTransaction: {
          findUnique: jest.fn().mockResolvedValue(null),
          create: jest.fn().mockResolvedValue({
            id: `ledger-${orderId}`,
            idempotencyKey: `OTC_SETTLEMENT:${orderId}`,
          }),
        },
        notification: { create: jest.fn() },
      };
      const service = new OtcService({
        $transaction: (fn: any) => fn(tx),
      } as any);
      await service.approve('admin-1', orderId);
      return tx.accountTransaction.create.mock.calls[0][0].data.idempotencyKey;
    }

    expect(await settle('otc-a')).toBe('OTC_SETTLEMENT:otc-a');
    expect(await settle('otc-b')).toBe('OTC_SETTLEMENT:otc-b');
  });
});
