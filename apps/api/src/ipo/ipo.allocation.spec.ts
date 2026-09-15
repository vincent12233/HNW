import {
  BadRequestException,
  ConflictException,
  ForbiddenException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { IpoService } from './ipo.service';

describe('IpoService allocation safety', () => {
  it('rejects invalid allocation quantity before starting a transaction', async () => {
    const prisma = { $transaction: jest.fn() };
    const service = new IpoService(prisma as any);

    await expect(
      service.allocate('application-1', 0, 79.1),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.$transaction).not.toHaveBeenCalled();
  });

  it('locks allocation price to IPO issuePrice and ignores caller price', async () => {
    const tx = {
      ipoApplication: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'application-1',
          status: 'PENDING',
          accountId: 'account-1',
          ipo: {
            id: 'ipo-1',
            symbol: 'VALIANTLAB',
            instrumentId: 'instrument-1',
            issuePrice: new Prisma.Decimal('100.50'),
            availableShares: 1000,
          },
          account: {
            id: 'account-1',
            userId: 'client-1',
            cashBalance: new Prisma.Decimal(1000),
            user: { assignedBusinessId: 'business-owner' },
          },
        }),
        aggregate: jest.fn().mockResolvedValue({ _sum: { draftQuantity: 0 } }),
        updateMany: jest.fn().mockResolvedValue({ count: 1 }),
      },
    };
    const prisma = {
      $transaction: jest.fn((callback: (client: typeof tx) => unknown) =>
        callback(tx),
      ),
    };
    const service = new IpoService(prisma as any);

    await service.allocate('application-1', 10, 999.99);
    expect(tx.ipoApplication.updateMany).toHaveBeenCalledWith({
      where: { id: 'application-1', status: 'PENDING', publishedAt: null },
      data: {
        draftQuantity: 10,
        draftPrice: expect.any(Prisma.Decimal),
      },
    });
    const call = tx.ipoApplication.updateMany.mock.calls[0][0];
    expect(call.data.draftPrice.toFixed(2)).toBe('100.50');
  });

  it('rejects draft allocation that exceeds remaining IPO shares', async () => {
    const tx = {
      ipoApplication: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'application-1',
          status: 'PENDING',
          ipo: {
            id: 'ipo-1',
            issuePrice: new Prisma.Decimal('100'),
            availableShares: 50,
          },
          account: {
            id: 'account-1',
            user: { assignedBusinessId: 'business-owner' },
          },
        }),
        aggregate: jest.fn().mockResolvedValue({ _sum: { draftQuantity: 40 } }),
        updateMany: jest.fn(),
      },
    };
    const prisma = {
      $transaction: jest.fn((callback: (client: typeof tx) => unknown) =>
        callback(tx),
      ),
    };
    const service = new IpoService(prisma as any);

    await expect(
      service.allocate('application-1', 20, 100),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(tx.ipoApplication.updateMany).not.toHaveBeenCalled();
  });

  it('does not debit cash or create debt when another operator claimed the application', async () => {
    const tx = {
      ipoApplication: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'application-1',
          status: 'PENDING',
          accountId: 'account-1',
          ipo: {
            id: 'ipo-1',
            symbol: 'VALIANTLAB',
            instrumentId: 'instrument-1',
            issuePrice: new Prisma.Decimal('79.1'),
            availableShares: 1000,
          },
          account: {
            id: 'account-1',
            userId: 'client-1',
            cashBalance: new Prisma.Decimal(1000),
            user: { assignedBusinessId: 'business-owner' },
          },
        }),
        aggregate: jest.fn().mockResolvedValue({ _sum: { draftQuantity: 0 } }),
        updateMany: jest.fn().mockResolvedValue({ count: 0 }),
      },
      account: { update: jest.fn() },
      ipoDebt: { create: jest.fn() },
      notification: { create: jest.fn() },
    };
    const prisma = {
      $transaction: jest.fn((callback: (client: typeof tx) => unknown) =>
        callback(tx),
      ),
    };
    const service = new IpoService(prisma as any);

    await expect(
      service.allocate('application-1', 10, 79.1),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(tx.account.update).not.toHaveBeenCalled();
    expect(tx.ipoDebt.create).not.toHaveBeenCalled();
    expect(tx.notification.create).not.toHaveBeenCalled();
  });

  it('prevents a business operator from allocating another operator customer application', async () => {
    const tx = {
      ipoApplication: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'application-1',
          status: 'PENDING',
          ipo: {
            id: 'ipo-1',
            instrumentId: 'instrument-1',
            issuePrice: new Prisma.Decimal('79.1'),
            availableShares: 1000,
          },
          account: {
            id: 'account-1',
            cashBalance: new Prisma.Decimal(1000),
            user: { assignedBusinessId: 'business-owner' },
          },
        }),
        aggregate: jest.fn(),
        updateMany: jest.fn(),
      },
      account: { update: jest.fn() },
    };
    const prisma = {
      $transaction: jest.fn((callback: (client: typeof tx) => unknown) =>
        callback(tx),
      ),
    };
    const service = new IpoService(prisma as any);

    await expect(
      service.allocate('application-1', 10, 79.1, 'business-other'),
    ).rejects.toBeInstanceOf(ForbiddenException);
    expect(tx.ipoApplication.updateMany).not.toHaveBeenCalled();
    expect(tx.account.update).not.toHaveBeenCalled();
  });
});
