import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { BusinessDashboardService } from './business-dashboard.service';

describe('BusinessDashboardService', () => {
  it('aggregates scoped cash and frozen balances without loading account rows', async () => {
    const account = {
      aggregate: jest.fn().mockResolvedValue({
        _sum: {
          cashBalance: new Prisma.Decimal('125.10'),
          frozenBalance: new Prisma.Decimal('4.25'),
        },
      }),
      findMany: jest.fn().mockResolvedValue([]),
    };
    const prisma = {
      account,
      user: { count: jest.fn().mockResolvedValue(0) },
      depositRequest: { count: jest.fn().mockResolvedValue(0) },
      withdrawalRequest: {
        count: jest.fn().mockResolvedValue(0),
        aggregate: jest.fn().mockResolvedValue({
          _sum: { amount: null },
          _count: 0,
        }),
      },
      accountTransaction: {
        aggregate: jest.fn().mockResolvedValue({
          _sum: { amount: null },
          _count: 0,
        }),
      },
      ipoApplication: { count: jest.fn().mockResolvedValue(0) },
      ipoDebt: {
        aggregate: jest.fn().mockResolvedValue({
          _sum: { amount: null, paidAmount: null },
          _count: 0,
        }),
      },
      loanApplication: {
        aggregate: jest.fn().mockResolvedValue({
          _sum: { outstandingAmount: null },
          _count: 0,
        }),
      },
      businessProfile: { findUnique: jest.fn().mockResolvedValue(null) },
      $transaction: jest.fn((queries: Promise<unknown>[]) =>
        Promise.all(queries),
      ),
      $queryRaw: jest.fn().mockResolvedValue([{ count: 0n }]),
    } as unknown as PrismaService;

    const service = new BusinessDashboardService(prisma);
    const result = await service.myDashboard('business-1');

    expect(account.aggregate).toHaveBeenCalledWith({
      where: { user: { assignedBusinessId: 'business-1' } },
      _sum: { cashBalance: true, frozenBalance: true },
    });
    expect(account.findMany).not.toHaveBeenCalled();
    expect(result.totalAssets).toBe('129.35');
  });
});
