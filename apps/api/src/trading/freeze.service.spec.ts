import { BadRequestException, ConflictException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { FreezeService } from './freeze.service';

describe('FreezeService consistency guards', () => {
  const service = new FreezeService();

  beforeEach(() => jest.clearAllMocks());

  it('freezes BUY funds from the current account state', async () => {
    const tx = {
      account: {
        findUnique: jest.fn().mockResolvedValue({
          buyingPower: new Prisma.Decimal('600'),
          cashBalance: new Prisma.Decimal('700'),
        }),
        update: jest.fn(),
      },
      accountTransaction: { create: jest.fn() },
    } as any;

    await service.freezeBuy(
      tx,
      'account-1',
      new Prisma.Decimal('9999'),
      new Prisma.Decimal('500'),
      'order-1',
      'freeze',
    );

    expect(tx.account.update).toHaveBeenCalledWith({
      where: { id: 'account-1' },
      data: {
        buyingPower: { decrement: new Prisma.Decimal('500') },
        frozenBalance: { increment: new Prisma.Decimal('500') },
      },
    });
  });

  it('rejects a second BUY reservation when current buying power was consumed by another order', async () => {
    const tx = {
      account: {
        findUnique: jest.fn().mockResolvedValue({
          buyingPower: new Prisma.Decimal('300'),
          cashBalance: new Prisma.Decimal('1000'),
        }),
        update: jest.fn(),
      },
      accountTransaction: { create: jest.fn() },
    } as any;

    await expect(
      service.freezeBuy(
        tx,
        'account-1',
        new Prisma.Decimal('1000'),
        new Prisma.Decimal('500'),
        'order-2',
        'freeze',
      ),
    ).rejects.toBeInstanceOf(BadRequestException);

    expect(tx.account.update).not.toHaveBeenCalled();
    expect(tx.accountTransaction.create).not.toHaveBeenCalled();
  });

  it('rejects a BUY reservation when current cash was spent by another immediate order', async () => {
    const tx = {
      account: {
        findUnique: jest.fn().mockResolvedValue({
          buyingPower: new Prisma.Decimal('800'),
          cashBalance: new Prisma.Decimal('200'),
        }),
        update: jest.fn(),
      },
      accountTransaction: { create: jest.fn() },
    } as any;

    await expect(
      service.freezeBuy(
        tx,
        'account-1',
        new Prisma.Decimal('1000'),
        new Prisma.Decimal('500'),
        'order-3',
        'freeze',
      ),
    ).rejects.toThrow('Insufficient buying power or cash balance');
  });

  it('freezes SELL quantity from the current position state', async () => {
    const tx = {
      position: {
        findUnique: jest.fn().mockResolvedValue({
          quantity: 10,
          frozenQuantity: 4,
        }),
        update: jest.fn(),
      },
    } as any;

    await service.freezeSell(tx, 'position-1', 6);

    expect(tx.position.update).toHaveBeenCalledWith({
      where: { id: 'position-1' },
      data: { frozenQuantity: { increment: 6 } },
    });
  });

  it('rejects a second SELL reservation when current available quantity is already frozen', async () => {
    const tx = {
      position: {
        findUnique: jest.fn().mockResolvedValue({
          quantity: 10,
          frozenQuantity: 7,
        }),
        update: jest.fn(),
      },
    } as any;

    await expect(service.freezeSell(tx, 'position-1', 4)).rejects.toThrow(
      'Insufficient available position',
    );
    expect(tx.position.update).not.toHaveBeenCalled();
  });

  it('rejects BUY release with zero amount', async () => {
    const tx = {} as any;

    await expect(
      service.releaseBuy(
        tx,
        'account-1',
        new Prisma.Decimal('1000'),
        new Prisma.Decimal('0'),
        'order-1',
        'release',
      ),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('rejects BUY release when frozen balance is too small', async () => {
    const tx = {
      account: {
        findUnique: jest.fn().mockResolvedValue({
          frozenBalance: new Prisma.Decimal('50'),
        }),
      },
    } as any;

    await expect(
      service.releaseBuy(
        tx,
        'account-1',
        new Prisma.Decimal('1000'),
        new Prisma.Decimal('100'),
        'order-1',
        'release',
      ),
    ).rejects.toThrow('Account frozen balance is inconsistent with the order');
  });

  it('rejects SELL release with zero quantity', async () => {
    const tx = {} as any;

    await expect(
      service.releaseSell(tx, 'position-1', 0),
    ).rejects.toBeInstanceOf(ConflictException);
  });

  it('rejects SELL release when frozen quantity is too small', async () => {
    const tx = {
      position: {
        findUnique: jest.fn().mockResolvedValue({ frozenQuantity: 2 }),
      },
    } as any;

    await expect(
      service.releaseSell(tx, 'position-1', 3),
    ).rejects.toThrow('Frozen position quantity is inconsistent with the order');
  });
});
