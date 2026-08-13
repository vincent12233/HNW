import { BadRequestException, ConflictException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { IpoService } from './ipo.service';

describe('IpoService allocation safety', () => {
  it('rejects invalid allocation values before starting a transaction', async () => {
    const prisma = { $transaction: jest.fn() };
    const service = new IpoService(prisma as any);

    await expect(service.allocate('application-1', 0, 79.1)).rejects.toBeInstanceOf(BadRequestException);
    await expect(service.allocate('application-1', 10, 0)).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('does not debit cash or create debt when another operator claimed the application', async () => {
    const tx = {
      ipoApplication: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'application-1',
          status: 'PENDING',
          accountId: 'account-1',
          ipo: { symbol: 'VALIANTLAB', instrumentId: 'instrument-1' },
          account: { id: 'account-1', userId: 'client-1', cashBalance: new Prisma.Decimal(1000) },
        }),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      account: { update: jest.fn() },
      ipoDebt: { create: jest.fn() },
      notification: { create: jest.fn() },
    };
    const prisma = {
      $transaction: jest.fn((callback: (client: typeof tx) => unknown) => callback(tx)),
    };
    const service = new IpoService(prisma as any);

    await expect(service.allocate('application-1', 10, 79.1)).rejects.toBeInstanceOf(ConflictException);
    expect(tx.account.update).not.toHaveBeenCalled();
    expect(tx.ipoDebt.create).not.toHaveBeenCalled();
    expect(tx.notification.create).not.toHaveBeenCalled();
  });
});
