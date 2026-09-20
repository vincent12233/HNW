import { ForbiddenException } from '@nestjs/common';
import { VipClientsService } from './vip-clients.service';
import { Prisma } from '../generated/prisma/client';

describe('VIP client scope', () => {
  it('limits manager lists to businessCreatorId-owned customers', async () => {
    const prisma = {
      user: {
        findMany: jest.fn().mockResolvedValue([]),
        findFirst: jest.fn().mockResolvedValue(null),
      },
      vipTierConfiguration: { findMany: jest.fn().mockResolvedValue([]) },
    };
    const service = new VipClientsService(prisma as never);
    await service.list('MANAGER', 'manager-1');
    expect(prisma.user.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          role: 'CLIENT',
          deletedAt: null,
          assignedBusiness: {
            is: {
              role: 'BUSINESS',
              deletedAt: null,
              businessCreatorId: 'manager-1',
            },
          },
        },
      }),
    );
    await expect(
      service.history('MANAGER', 'manager-1', 'foreign-client'),
    ).rejects.toBeInstanceOf(ForbiddenException);
  });

  it('limits business lists to assignedBusinessId', async () => {
    const prisma = {
      user: { findMany: jest.fn().mockResolvedValue([]) },
      vipTierConfiguration: { findMany: jest.fn().mockResolvedValue([]) },
    };
    const service = new VipClientsService(prisma as never);
    await service.list('BUSINESS', 'business-1');
    expect(prisma.user.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: {
          role: 'CLIENT',
          deletedAt: null,
          assignedBusinessId: 'business-1',
        },
      }),
    );
  });

  it('does not treat a suggestion as a current-tier write', async () => {
    const prisma = {
      user: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'client-1',
            customerNo: 'C1',
            fullName: 'Test Client',
            phone: '9876543210',
            clientTier: 'STANDARD',
            assignedBusinessId: 'business-1',
            assignedBusiness: {
              id: 'business-1',
              fullName: 'Agent',
              businessCreatorId: 'manager-1',
              businessProfile: { employeeNo: 'B001' },
            },
            account: { id: 'acct-1' },
            vipTierChanges: [],
          },
        ]),
        update: jest.fn(),
        updateMany: jest.fn(),
      },
      vipTierConfiguration: {
        findMany: jest.fn().mockResolvedValue([
          {
            tierCode: 'STANDARD',
            displayOrder: 1,
            isActive: true,
            minimumCumulativeDeposit: null,
            updatedAt: new Date(),
          },
          {
            tierCode: 'SILVER',
            displayOrder: 2,
            isActive: true,
            minimumCumulativeDeposit: new Prisma.Decimal('1000'),
            updatedAt: new Date(),
          },
        ]),
      },
      depositRequest: {
        aggregate: jest
          .fn()
          .mockResolvedValue({ _sum: { amount: new Prisma.Decimal('5000') } }),
      },
      accountTransaction: {
        aggregate: jest
          .fn()
          .mockResolvedValue({ _sum: { amount: new Prisma.Decimal('0') } }),
      },
    };
    const service = new VipClientsService(prisma as never);
    const result = await service.list('BUSINESS', 'business-1');
    expect(result.clients[0]).toMatchObject({
      currentTier: 'STANDARD',
      suggestedTier: 'SILVER',
      suggestionStatus: 'UPGRADE',
      maskedPhone: '******3210',
    });
    expect(prisma.user.update).not.toHaveBeenCalled();
    expect(prisma.user.updateMany).not.toHaveBeenCalled();
  });
});
