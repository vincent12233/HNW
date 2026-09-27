import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import * as bcrypt from 'bcrypt';
import { randomInt } from 'crypto';

import {
  InviteCodeStatus,
  UserRole,
  UserStatus,
} from '../generated/prisma/enums';
import { Prisma } from '../generated/prisma/client';
import { ListAdminOrdersQueryDto } from '../orders/dto/list-admin-orders-query.dto';
import { ListAdminTradesQueryDto } from '../orders/dto/list-admin-trades-query.dto';
import { IpoService } from '../ipo/ipo.service';
import { PrismaService } from '../prisma/prisma.service';
import { AuditService } from '../audit/audit.service';
import { applyManualVipTierChange } from '../vip/vip-tier-change';
import { BusinessDashboardService } from './business-dashboard.service';
import { BusinessRiskService } from './business-risk.service';
import { BusinessTradingService } from './business-trading.service';

type CreateBusinessInput = {
  password: string;
  fullName: string;
  phone?: string;
  employeeNo: string;
  department?: string;
};

@Injectable()
export class BusinessService {
  private readonly dashboardService: BusinessDashboardService;
  private readonly riskService: BusinessRiskService;
  private readonly tradingService: BusinessTradingService;

  constructor(
    private readonly prisma: PrismaService,
    private readonly ipoService: IpoService,
    private readonly auditService: AuditService,
  ) {
    this.dashboardService = new BusinessDashboardService(prisma);
    this.riskService = new BusinessRiskService(prisma);
    this.tradingService = new BusinessTradingService(prisma);
  }

  private generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return Array.from({ length: 7 }, () => chars[randomInt(chars.length)]).join(
      '',
    );
  }

  myDashboard(businessUserId: string) {
    return this.dashboardService.myDashboard(businessUserId);
  }

  myDeposits(businessUserId: string) {
    return this.dashboardService.myDeposits(businessUserId);
  }

  myWithdrawals(businessUserId: string) {
    return this.dashboardService.myWithdrawals(businessUserId);
  }

  async createBusiness(input: CreateBusinessInput) {
    const employeeNo = input.employeeNo.trim().toUpperCase();
    const email = `${employeeNo.toLowerCase()}@internal.hnw.local`;

    if (!input.password || input.password.length < 12) {
      throw new BadRequestException('密码至少需要 12 个字符');
    }

    if (!input.fullName?.trim()) {
      throw new BadRequestException('请输入业务员姓名');
    }

    if (!employeeNo) {
      throw new BadRequestException('请输入员工编号');
    }

    const existingEmployee = await this.prisma.businessProfile.findUnique({
      where: {
        employeeNo,
      },
      select: {
        id: true,
      },
    });

    if (existingEmployee) {
      throw new ConflictException('该员工编号已经存在');
    }

    const existingUser = await this.prisma.user.findUnique({
      where: {
        email,
      },
      select: {
        id: true,
      },
    });

    if (existingUser) {
      throw new ConflictException('该员工编号已经存在');
    }

    const passwordHash = await bcrypt.hash(input.password, 12);

    return this.prisma.$transaction(async (tx) => {
      const user = await tx.user.create({
        data: {
          email,
          passwordHash,
          fullName: input.fullName.trim(),
          phone: input.phone?.trim() || null,
          role: UserRole.BUSINESS,
          status: UserStatus.ACTIVE,
        },
      });

      const businessProfile = await tx.businessProfile.create({
        data: {
          userId: user.id,
          employeeNo,
          department: input.department?.trim() || null,
          isActive: true,
        },
      });

      return {
        message: '业务员创建成功',
        user: {
          id: user.id,
          fullName: user.fullName,
          phone: user.phone,
          role: user.role,
          status: user.status,
        },
        businessProfile,
      };
    });
  }

  async listBusinesses() {
    return this.prisma.businessProfile.findMany({
      include: {
        user: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            role: true,
            status: true,
            createdAt: true,

            _count: {
              select: {
                assignedCustomers: true,
              },
            },
          },
        },

        inviteCodes: {
          where: {
            status: InviteCodeStatus.UNUSED,
          },
          select: {
            id: true,
          },
        },

        _count: {
          select: {
            inviteCodes: true,
          },
        },
      },

      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async generateInviteCodes(
    businessUserId: string,
    count: number,
    expiresAt?: Date,
  ) {
    if (!Number.isInteger(count) || count < 1 || count > 100) {
      throw new BadRequestException('每次只能生成 1 到 100 个邀请码');
    }

    if (expiresAt && Number.isNaN(expiresAt.getTime())) {
      throw new BadRequestException('邀请码有效期格式不正确');
    }

    if (expiresAt && expiresAt.getTime() <= Date.now()) {
      throw new BadRequestException('邀请码有效期必须晚于当前时间');
    }

    const profile = await this.prisma.businessProfile.findUnique({
      where: {
        userId: businessUserId,
      },
      select: {
        id: true,
        isActive: true,
      },
    });

    if (!profile) {
      throw new NotFoundException('未找到业务员资料');
    }

    if (!profile.isActive) {
      throw new BadRequestException('该业务员账号已停用');
    }

    const codes: string[] = [];

    while (codes.length < count) {
      const code = this.generateInviteCode();

      const exists = await this.prisma.inviteCode.findUnique({
        where: {
          code,
        },
        select: {
          id: true,
        },
      });

      if (!exists && !codes.includes(code)) {
        codes.push(code);
      }
    }

    await this.prisma.inviteCode.createMany({
      data: codes.map((code) => ({
        code,
        businessProfileId: profile.id,
        expiresAt: expiresAt ?? null,
        status: InviteCodeStatus.UNUSED,
      })),
    });

    return this.prisma.inviteCode.findMany({
      where: {
        businessProfileId: profile.id,
        code: {
          in: codes,
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });
  }

  async currentInviteCode(businessUserId: string, previousId?: string) {
    const where = {
      businessProfile: {
        userId: businessUserId,
        isActive: true,
        user: { role: UserRole.BUSINESS, status: UserStatus.ACTIVE },
      },
      status: InviteCodeStatus.UNUSED,
      OR: [{ expiresAt: null }, { expiresAt: { gt: new Date() } }],
    };
    const select = { id: true, code: true, expiresAt: true };
    const next = await this.prisma.inviteCode.findFirst({
      where: { ...where, ...(previousId ? { id: { not: previousId } } : {}) },
      select,
      orderBy: [{ createdAt: 'asc' }, { id: 'asc' }],
    });
    const code =
      next ??
      (previousId
        ? await this.prisma.inviteCode.findFirst({
            where: { ...where, id: previousId },
            select,
          })
        : null);
    return { code };
  }

  async listInviteCodes(
    currentUserId: string,
    currentRole: UserRole,
    businessUserId?: string,
  ) {
    let targetBusinessUserId = currentUserId;

    if (currentRole === UserRole.ADMIN || currentRole === UserRole.FINANCE) {
      if (!businessUserId) {
        throw new BadRequestException('请选择业务员');
      }

      targetBusinessUserId = businessUserId;
    }

    const profile = await this.prisma.businessProfile.findUnique({
      where: {
        userId: targetBusinessUserId,
      },
      select: {
        id: true,
      },
    });

    if (!profile) {
      throw new NotFoundException('未找到业务员资料');
    }

    const inviteCodes = await this.prisma.inviteCode.findMany({
      where: {
        businessProfileId: profile.id,
      },
      include: {
        customers: {
          select: {
            id: true,
            fullName: true,
            phone: true,
            status: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return inviteCodes.map(({ customers, ...code }) => ({
      ...code,
      customer: customers[0] ?? null,
      customers,
    }));
  }

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

  async setBusinessActive(businessUserId: string, isActive: boolean) {
    const profile = await this.prisma.businessProfile.findUnique({
      where: {
        userId: businessUserId,
      },
      select: {
        id: true,
        userId: true,
        isActive: true,
      },
    });

    if (!profile) {
      throw new NotFoundException('未找到业务员');
    }

    const businessProfile = await this.prisma.businessProfile.update({
      where: {
        userId: businessUserId,
      },
      data: {
        isActive,
      },
    });

    return {
      message: isActive ? '业务员已启用' : '业务员已停用',
      businessProfile,
    };
  }

  async resetBusinessPassword(businessUserId: string, newPassword: string) {
    if (!newPassword || newPassword.length < 12) {
      throw new BadRequestException('新密码至少需要 12 个字符');
    }

    const business = await this.prisma.user.findFirst({
      where: {
        id: businessUserId,
        role: UserRole.BUSINESS,
      },
      select: {
        id: true,
      },
    });

    if (!business) {
      throw new NotFoundException('未找到业务员');
    }

    const passwordHash = await bcrypt.hash(newPassword, 12);

    await this.prisma.user.update({
      where: {
        id: businessUserId,
      },
      data: {
        passwordHash,
      },
    });

    return {
      message: '业务员密码已重置',
    };
  }

  async disableInviteCode(
    codeId: string,
    currentUserId: string,
    currentRole: UserRole,
  ) {
    const inviteCode = await this.prisma.inviteCode.findUnique({
      where: {
        id: codeId,
      },
      include: {
        businessProfile: {
          select: {
            userId: true,
          },
        },
      },
    });

    if (!inviteCode) {
      throw new NotFoundException('未找到邀请码');
    }

    if (
      currentRole === UserRole.BUSINESS &&
      inviteCode.businessProfile.userId !== currentUserId
    ) {
      throw new NotFoundException('未找到邀请码');
    }

    if (inviteCode.status !== InviteCodeStatus.UNUSED) {
      throw new BadRequestException('只有未使用的邀请码可以作废');
    }

    return this.prisma.inviteCode.update({
      where: {
        id: codeId,
      },
      data: {
        status: InviteCodeStatus.DISABLED,
        disabledAt: new Date(),
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

  async myIpoApplications(businessUserId: string) {
    const applications = await this.prisma.ipoApplication.findMany({
      where: {
        account: {
          user: {
            assignedBusinessId: businessUserId,
          },
        },
      },
      include: {
        ipo: true,
        ipoDebt: true,
        account: {
          select: {
            accountNumber: true,
            cashBalance: true,
            user: {
              select: {
                id: true,
                customerNo: true,
                fullName: true,
                phone: true,
                status: true,
              },
            },
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    const reservedRows =
      applications.length === 0
        ? []
        : await this.prisma.ipoApplication.groupBy({
            by: ['ipoId'],
            where: {
              ipoId: { in: [...new Set(applications.map((row) => row.ipoId))] },
              status: 'PENDING',
              publishedAt: null,
              draftQuantity: { not: null },
            },
            _sum: { draftQuantity: true },
          });
    const reservedByIpo = new Map(
      reservedRows.map((row) => [row.ipoId, row._sum.draftQuantity ?? 0]),
    );

    return applications.map((application) => {
      const totalReserved = reservedByIpo.get(application.ipoId) ?? 0;
      const ownDraft =
        application.status === 'PENDING' &&
        application.publishedAt == null &&
        application.draftQuantity != null
          ? application.draftQuantity
          : 0;
      const reservedByOthers = Math.max(0, totalReserved - ownDraft);
      const remainingShares = IpoService.remainingAfterDrafts(
        application.ipo.availableShares,
        reservedByOthers,
      );
      return {
        id: application.id,
        quantity: application.quantity,
        amount: application.amount.toFixed(2),
        status: application.status,
        paymentStatus: application.paymentStatus,
        allocatedQuantity: application.allocatedQuantity,
        draftQuantity: application.draftQuantity,
        draftPrice: application.draftPrice?.toFixed(2) ?? null,
        publishedAt: application.publishedAt,
        allocatedPrice: application.allocatedPrice?.toFixed(2) ?? null,
        allocatedAmount: application.allocatedAmount?.toFixed(2) ?? null,
        createdAt: application.createdAt,
        ipo: {
          id: application.ipo.id,
          symbol: application.ipo.symbol,
          companyName: application.ipo.companyName,
          issuePrice: application.ipo.issuePrice.toFixed(2),
          totalShares: application.ipo.totalShares,
          availableShares: application.ipo.availableShares,
          reservedDraftShares: reservedByOthers,
          remainingShares,
          status: application.ipo.status,
        },
        account: {
          ...application.account,
          cashBalance: application.account.cashBalance.toFixed(2),
        },
        debt: application.ipoDebt
          ? {
              amount: application.ipoDebt.amount.toFixed(2),
              paidAmount: application.ipoDebt.paidAmount.toFixed(2),
              status: application.ipoDebt.status,
            }
          : null,
      };
    });
  }

  async allocateMyIpoApplication(
    businessUserId: string,
    applicationId: string,
    quantity: number,
    price: number | string,
  ) {
    const ownedApplication = await this.prisma.ipoApplication.findFirst({
      where: {
        id: applicationId,
        account: { user: { assignedBusinessId: businessUserId } },
      },
      select: { id: true },
    });
    if (!ownedApplication) {
      throw new NotFoundException(
        'IPO application is not assigned to this operator',
      );
    }
    const result = await this.ipoService.allocate(
      applicationId,
      quantity,
      price,
      businessUserId,
    );

    await this.auditService.createLog({
      actorId: businessUserId,
      action: 'BUSINESS_IPO_ALLOCATE',
      resource: 'ipo_application',
      resourceId: applicationId,
      description: `业务员分配 IPO 申请`,
      metadata: { quantity, price, debtAmount: result.debtAmount },
    });

    return result;
  }

  async publishMyIpoApplications(businessUserId: string, ids: string[]) {
    return this.ipoService.publish(ids, businessUserId, businessUserId);
  }

  myOrders(businessUserId: string, query: ListAdminOrdersQueryDto) {
    return this.tradingService.myOrders(businessUserId, query);
  }

  myTrades(businessUserId: string, query: ListAdminTradesQueryDto) {
    return this.tradingService.myTrades(businessUserId, query);
  }

  myTradePairs(businessUserId: string, customerId?: string) {
    return this.tradingService.myTradePairs(businessUserId, customerId);
  }

  myPositions(
    businessUserId: string,
    query: { category?: string; search?: string },
  ) {
    return this.tradingService.myPositions(businessUserId, query);
  }

  customerLastLogin(businessUserId: string, customerId: string) {
    return this.riskService.customerLastLogin(businessUserId, customerId);
  }

  customerLoginAudits(businessUserId: string, customerId: string) {
    return this.riskService.customerLoginAudits(businessUserId, customerId);
  }

  customerLoginRisk(businessUserId: string, customerId: string) {
    return this.riskService.customerLoginRisk(businessUserId, customerId);
  }

  sharedIpRisks(businessUserId: string) {
    return this.riskService.sharedIpRisks(businessUserId);
  }

  myRiskDashboard(businessUserId: string) {
    return this.riskService.myRiskDashboard(businessUserId);
  }

  sharedDeviceRisks(businessUserId: string) {
    return this.riskService.sharedDeviceRisks(businessUserId);
  }
}
