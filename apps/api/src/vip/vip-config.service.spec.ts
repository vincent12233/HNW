import { BadRequestException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { VipConfigService } from './vip-config.service';

describe('VIP configuration', () => {
  it('rejects a negative threshold before writing', async () => {
    const service = new VipConfigService({} as never, { createLog: jest.fn() } as never);
    await expect(
      service.update('admin-1', 'SILVER', { minimumCumulativeDeposit: '-1' }),
    ).rejects.toBeInstanceOf(BadRequestException);
  });

  it('rejects a non-increasing active threshold set', async () => {
    const rows = [
      {
        id: '1',
        tierCode: 'STANDARD',
        displayName: '标准',
        description: '',
        minimumCumulativeDeposit: null,
        displayOrder: 1,
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        updatedById: null,
      },
      {
        id: '2',
        tierCode: 'SILVER',
        displayName: '白银',
        description: '',
        minimumCumulativeDeposit: new Prisma.Decimal('10000'),
        displayOrder: 2,
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        updatedById: null,
      },
      {
        id: '3',
        tierCode: 'GOLD',
        displayName: '黄金',
        description: '',
        minimumCumulativeDeposit: new Prisma.Decimal('5000'),
        displayOrder: 3,
        isActive: true,
        createdAt: new Date(),
        updatedAt: new Date(),
        updatedById: null,
      },
    ];
    const tx = {
      $executeRaw: jest.fn(),
      vipTierConfiguration: {
        findUnique: jest.fn().mockResolvedValue(rows[2]),
        findMany: jest.fn().mockResolvedValue(rows),
        update: jest.fn(),
      },
    };
    const prisma = {
      $transaction: (fn: (client: typeof tx) => unknown) => fn(tx),
    };
    const audit = { createLog: jest.fn() };
    const service = new VipConfigService(prisma as never, audit as never);
    await expect(
      service.update('admin-1', 'GOLD', { minimumCumulativeDeposit: '5000.00' }),
    ).rejects.toThrow(/strictly/);
    expect(tx.vipTierConfiguration.update).not.toHaveBeenCalled();
    expect(audit.createLog).not.toHaveBeenCalled();
  });
});
