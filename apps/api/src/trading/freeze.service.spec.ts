import { ConflictException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { FreezeService } from './freeze.service';

describe('FreezeService release guards', () => {
  const service = new FreezeService();

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
