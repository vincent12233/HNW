import { BadRequestException, NotFoundException } from '@nestjs/common';

import { AuditService } from '../audit/audit.service';
import { Prisma } from '../generated/prisma/client';
import { UserRole, UserStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { applyManualVipTierChange } from '../vip/vip-tier-change';

export class BusinessCustomerService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly auditService: AuditService,
  ) {}

  async customersByBusiness(businessUserId: string) {
    const business = await this.prisma.businessProfile.findUnique({
      where: {
        userId: businessUserId,
      },
      select: {
        id: true,
        user: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            status: true,
          },
        },
      },
    });

    if (!business) {
      throw new NotFoundException('未找到业务员');
    }

    return this.prisma.user.findMany({
      where: {
        role: UserRole.CLIENT,
        assignedBusinessId: businessUserId,
      },
      select: {
        id: true,
        customerNo: true,
        fullName: true,
        phone: true,
        status: true,
        createdAt: true,

        account: {
          select: {
            id: true,
            accountNumber: true,
            cashBalance: true,
            buyingPower: true,
            frozenBalance: true,
            currency: true,
          },
        },

        usedInviteCode: {
          select: {
            code: true,
            usedAt: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async myCustomers(businessUserId: string) {
    return this.prisma.user.findMany({
      where: {
        role: UserRole.CLIENT,
        assignedBusinessId: businessUserId,
      },
      select: {
        id: true,
        customerNo: true,
        clientTier: true,
        fullName: true,
        phone: true,
        status: true,
        createdAt: true,

        account: {
          select: {
            id: true,
            accountNumber: true,
            cashBalance: true,
            buyingPower: true,
            frozenBalance: true,
            currency: true,
            isLive: true,
          },
        },

        usedInviteCode: {
          select: {
            id: true,
            code: true,
            usedAt: true,
          },
        },

        loginAudits: {
          take: 1,
          orderBy: {
            createdAt: 'desc',
          },
          select: {
            ipAddress: true,
            userAgent: true,
            createdAt: true,
            success: true,
          },
        },
      },

      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async updateMyCustomerStatus(
    businessUserId: string,
    customerId: string,
    status: UserStatus,
  ) {
    if (
      status !== UserStatus.ACTIVE &&
      status !== UserStatus.SUSPENDED &&
      status !== UserStatus.DISABLED
    ) {
      throw new BadRequestException('账户状态不正确');
    }

    const claimed = await this.prisma.user.updateMany({
      where: {
        id: customerId,
        role: UserRole.CLIENT,
        assignedBusinessId: businessUserId,
      },
      data: {
        status,
      },
    });
    if (claimed.count !== 1)
      throw new NotFoundException('客户不存在或不属于当前业务员');

    const updated = await this.prisma.user.findUniqueOrThrow({
      where: { id: customerId },
      select: {
        id: true,
        customerNo: true,
        fullName: true,
        phone: true,
        status: true,
        account: {
          select: {
            accountNumber: true,
            cashBalance: true,
            buyingPower: true,
            frozenBalance: true,
            currency: true,
          },
        },
      },
    });

    await this.auditService.createLog({
      actorId: businessUserId,
      action: 'BUSINESS_CUSTOMER_STATUS_UPDATE',
      resource: 'customer',
      resourceId: customerId,
      description: `业务员更新客户账户状态为 ${status}`,
      metadata: { status },
    });

    return updated;
  }

  async updateCustomerTier(
    actorId: string,
    customerId: string,
    tier: unknown,
    reason?: unknown,
  ) {
    return this.prisma.$transaction(
      (tx) =>
        applyManualVipTierChange(tx, {
          actorId,
          userId: customerId,
          tier,
          reason,
          source: 'MANUAL',
          requireReason: false,
        }),
      { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
    );
  }
}
