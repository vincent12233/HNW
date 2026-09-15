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
import { moneyDecimal } from '../common/money';

type CreateBusinessInput = {
  password: string;
  fullName: string;
  phone?: string;
  employeeNo: string;
  department?: string;
};

@Injectable()
export class BusinessService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ipoService: IpoService,
    private readonly auditService: AuditService,
  ) {}

  private generateInviteCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return Array.from({ length: 7 }, () => chars[randomInt(chars.length)]).join(
      '',
    );
  }

  private normalizePositionCategory(value?: string) {
    const normalized = value?.trim().toUpperCase();

    if (normalized === 'IPO' || normalized === 'OTC') {
      return normalized;
    }

    if (normalized === 'INSTITUTIONAL' || normalized === 'LIMIT_UP') {
      return 'INSTITUTIONAL';
    }

    return null;
  }

  private positionCategory(instrument: {
    symbol: string;
    name: string;
    category: string | null;
  }) {
    const text = [instrument.symbol, instrument.name, instrument.category ?? '']
      .join(' ')
      .toUpperCase();

    if (text.includes('IPO')) {
      return 'IPO';
    }

    if (text.includes('OTC') || text.includes('BLOCK')) {
      return 'OTC';
    }

    return 'INSTITUTIONAL';
  }

  async myDashboard(businessUserId: string) {
    const startOfToday = new Date();
    startOfToday.setHours(0, 0, 0, 0);

    const [
      totalCustomers,
      todayCustomers,
      pendingDeposits,
      pendingWithdrawals,
      depositTotals,
      withdrawalTotals,
      todayDepositTotals,
      todayWithdrawalTotals,
      pendingIpoApplications,
      openIpoDebts,
      loanOutstanding,
      accounts,
      businessProfile,
    ] = await this.prisma.$transaction([
      this.prisma.user.count({
        where: {
          role: UserRole.CLIENT,
          assignedBusinessId: businessUserId,
        },
      }),

      this.prisma.user.count({
        where: {
          role: UserRole.CLIENT,
          assignedBusinessId: businessUserId,
          createdAt: {
            gte: startOfToday,
          },
        },
      }),

      this.prisma.depositRequest.count({
        where: {
          status: 'PENDING',
          account: {
            user: {
              assignedBusinessId: businessUserId,
            },
          },
        },
      }),

      this.prisma.withdrawalRequest.count({
        where: {
          status: 'PENDING',
          account: {
            user: {
              assignedBusinessId: businessUserId,
            },
          },
        },
      }),

      this.prisma.accountTransaction.aggregate({
        where: {
          type: 'ADMIN_CREDIT',
          status: 'COMPLETED',
          account: {
            user: {
              assignedBusinessId: businessUserId,
            },
          },
        },
        _sum: {
          amount: true,
        },
        _count: true,
      }),

      this.prisma.withdrawalRequest.aggregate({
        where: {
          account: {
            user: {
              assignedBusinessId: businessUserId,
            },
          },
        },
        _sum: {
          amount: true,
        },
        _count: true,
      }),

      this.prisma.accountTransaction.aggregate({
        where: {
          type: 'ADMIN_CREDIT',
          status: 'COMPLETED',
          createdAt: {
            gte: startOfToday,
          },
          account: {
            user: {
              assignedBusinessId: businessUserId,
            },
          },
        },
        _sum: {
          amount: true,
        },
        _count: true,
      }),

      this.prisma.withdrawalRequest.aggregate({
        where: {
          createdAt: {
            gte: startOfToday,
          },
          account: {
            user: {
              assignedBusinessId: businessUserId,
            },
          },
        },
        _sum: {
          amount: true,
        },
        _count: true,
      }),

      this.prisma.ipoApplication.count({
        where: {
          status: 'PENDING',
          account: {
            user: {
              assignedBusinessId: businessUserId,
            },
          },
        },
      }),

      this.prisma.ipoDebt.aggregate({
        where: {
          status: {
            in: ['OPEN', 'PARTIAL'],
          },
          account: {
            user: {
              assignedBusinessId: businessUserId,
            },
          },
        },
        _sum: {
          amount: true,
          paidAmount: true,
        },
        _count: true,
      }),

      this.prisma.loanApplication.aggregate({
        where: {
          status: {
            in: ['DISBURSED', 'PARTIAL_REPAID', 'OVERDUE'],
          },
          account: {
            user: {
              assignedBusinessId: businessUserId,
            },
          },
        },
        _sum: {
          outstandingAmount: true,
        },
        _count: true,
      }),

      this.prisma.account.findMany({
        where: {
          user: {
            assignedBusinessId: businessUserId,
          },
        },
        select: {
          cashBalance: true,
          frozenBalance: true,
        },
      }),

      this.prisma.businessProfile.findUnique({
        where: {
          userId: businessUserId,
        },
        select: {
          id: true,
        },
      }),
    ]);

    const totalAssets = accounts
      .reduce(
        (sum, account) =>
          sum
            .add(moneyDecimal(account.cashBalance))
            .add(moneyDecimal(account.frozenBalance)),
        new Prisma.Decimal(0),
      )
      .toFixed(2);

    const pendingKycRows = await this.prisma.$queryRaw<{ count: bigint }[]>`
      SELECT COUNT(*)::bigint AS count
      FROM "kyc_submissions" k
      JOIN "users" u ON u."id" = k."userId"
      WHERE u."assignedBusinessId" = ${businessUserId}
        AND k."status" = 'PENDING'
    `;

    let unusedInviteCodes = 0;

    if (businessProfile) {
      unusedInviteCodes = await this.prisma.inviteCode.count({
        where: {
          businessProfileId: businessProfile.id,
          status: InviteCodeStatus.UNUSED,
        },
      });
    }

    return {
      totalCustomers,
      todayCustomers,
      pendingDeposits,
      pendingWithdrawals,
      pendingKyc: Number(pendingKycRows[0]?.count ?? 0),
      totalDepositAmount: depositTotals._sum.amount?.toFixed(2) ?? '0.00',
      totalDepositCount: depositTotals._count,
      totalWithdrawalAmount: withdrawalTotals._sum.amount?.toFixed(2) ?? '0.00',
      totalWithdrawalCount: withdrawalTotals._count,
      todayDepositAmount: todayDepositTotals._sum.amount?.toFixed(2) ?? '0.00',
      todayDepositCount: todayDepositTotals._count,
      todayWithdrawalAmount:
        todayWithdrawalTotals._sum.amount?.toFixed(2) ?? '0.00',
      todayWithdrawalCount: todayWithdrawalTotals._count,
      pendingIpoApplications,
      ipoDebtCustomers: openIpoDebts._count,
      ipoDebtAmount: moneyDecimal(openIpoDebts._sum.amount ?? 0)
        .sub(moneyDecimal(openIpoDebts._sum.paidAmount ?? 0))
        .toFixed(2),
      loanOutstandingAmount:
        loanOutstanding._sum.outstandingAmount?.toFixed(2) ?? '0.00',
      loanOutstandingCount: loanOutstanding._count,
      totalAssets,
      unusedInviteCodes,
    };
  }

  async myDeposits(businessUserId: string) {
    return this.prisma.accountTransaction.findMany({
      where: {
        type: 'ADMIN_CREDIT',
        status: 'COMPLETED',
        account: {
          user: {
            assignedBusinessId: businessUserId,
          },
        },
      },
      select: {
        id: true,
        type: true,
        amount: true,
        status: true,
        referenceId: true,
        note: true,
        createdAt: true,
        updatedAt: true,
        createdBy: {
          select: {
            id: true,
            fullName: true,
            role: true,
          },
        },

        account: {
          select: {
            id: true,
            accountNumber: true,
            currency: true,

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
  }

  async myWithdrawals(businessUserId: string) {
    return this.prisma.withdrawalRequest.findMany({
      where: {
        account: {
          user: {
            assignedBusinessId: businessUserId,
          },
        },
      },
      select: {
        id: true,
        orderNo: true,
        amount: true,
        bankName: true,
        accountNumber: true,
        ifscCode: true,
        upiId: true,
        note: true,
        status: true,
        createdAt: true,
        updatedAt: true,

        account: {
          select: {
            id: true,
            accountNumber: true,
            currency: true,

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
  }

  async createBusiness(input: CreateBusinessInput) {
    const employeeNo = input.employeeNo.trim().toUpperCase();
    const email = `${employeeNo.toLowerCase()}@internal.hnw.local`;

    if (!input.password || input.password.length < 6) {
      throw new BadRequestException('密码至少需要 6 个字符');
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
    if (!newPassword || newPassword.length < 6) {
      throw new BadRequestException('新密码至少需要 6 个字符');
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

  async updateCustomerTier(actorId: string, customerId: string, tier: unknown) {
    if (
      typeof tier !== 'string' ||
      !['STANDARD', 'SILVER', 'GOLD', 'PLATINUM'].includes(tier)
    ) {
      throw new BadRequestException('Invalid membership tier');
    }
    return this.prisma.$transaction(async (tx) => {
      const scope = {
        id: customerId,
        role: UserRole.CLIENT,
        assignedBusinessId: actorId,
      };
      const previous = await tx.user.findFirst({
        where: scope,
        select: { clientTier: true },
      });
      if (!previous)
        throw new NotFoundException(
          'Customer not assigned to this business user',
        );
      const result = await tx.user.updateMany({
        where: scope,
        data: { clientTier: tier },
      });
      if (result.count !== 1)
        throw new NotFoundException('Customer assignment changed');
      await tx.auditLog.create({
        data: {
          actorId,
          action: 'BUSINESS_CLIENT_TIER_UPDATED',
          resource: 'User',
          resourceId: customerId,
          metadata: { previous: previous.clientTier, tier },
        },
      });
      return { id: customerId, clientTier: tier };
    });
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

  async myOrders(businessUserId: string, query: ListAdminOrdersQueryDto) {
    if (
      query.dateFrom &&
      query.dateTo &&
      new Date(query.dateFrom) > new Date(query.dateTo)
    ) {
      throw new BadRequestException(
        'dateFrom must be earlier than or equal to dateTo',
      );
    }

    const search = query.search?.trim();
    const normalizedSymbol = query.symbol?.trim().toUpperCase();

    const where: Prisma.OrderWhereInput = {
      account: {
        user: {
          role: UserRole.CLIENT,
          assignedBusinessId: businessUserId,
        },
      },
      ...(query.status ? { status: query.status } : {}),
      ...(query.side ? { side: query.side } : {}),
      ...(query.type ? { type: query.type } : {}),
      ...(query.timeInForce ? { timeInForce: query.timeInForce } : {}),
      ...(query.exchange || normalizedSymbol
        ? {
            instrument: {
              ...(query.exchange ? { exchange: query.exchange } : {}),
              ...(normalizedSymbol ? { symbol: normalizedSymbol } : {}),
            },
          }
        : {}),
      ...(search
        ? {
            OR: [
              { clientOrderId: { contains: search, mode: 'insensitive' } },
              {
                account: {
                  accountNumber: { contains: search, mode: 'insensitive' },
                },
              },
              {
                account: {
                  user: { fullName: { contains: search, mode: 'insensitive' } },
                },
              },
              {
                account: {
                  user: { phone: { contains: search, mode: 'insensitive' } },
                },
              },
              {
                account: {
                  user: {
                    customerNo: { contains: search, mode: 'insensitive' },
                  },
                },
              },
              {
                instrument: {
                  symbol: { contains: search, mode: 'insensitive' },
                },
              },
            ],
          }
        : {}),
      ...(query.dateFrom || query.dateTo
        ? {
            placedAt: {
              ...(query.dateFrom ? { gte: new Date(query.dateFrom) } : {}),
              ...(query.dateTo ? { lte: new Date(query.dateTo) } : {}),
            },
          }
        : {}),
    };

    const skip = (query.page - 1) * query.pageSize;

    const [total, data] = await this.prisma.$transaction([
      this.prisma.order.count({ where }),
      this.prisma.order.findMany({
        where,
        include: {
          account: {
            select: {
              accountNumber: true,
              currency: true,
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
          instrument: true,
          trades: {
            orderBy: {
              executedAt: 'asc',
            },
          },
        },
        orderBy: {
          placedAt: 'desc',
        },
        skip,
        take: query.pageSize,
      }),
    ]);

    return {
      page: query.page,
      pageSize: query.pageSize,
      total,
      totalPages: Math.ceil(total / query.pageSize),
      data,
    };
  }

  async myTrades(businessUserId: string, query: ListAdminTradesQueryDto) {
    if (
      query.dateFrom &&
      query.dateTo &&
      new Date(query.dateFrom) > new Date(query.dateTo)
    ) {
      throw new BadRequestException(
        'dateFrom must be earlier than or equal to dateTo',
      );
    }

    const search = query.search?.trim();
    const normalizedSymbol = query.symbol?.trim().toUpperCase();

    const where: Prisma.TradeWhereInput = {
      account: {
        user: {
          role: UserRole.CLIENT,
          assignedBusinessId: businessUserId,
          ...(query.customerId ? { id: query.customerId } : {}),
        },
      },
      ...(query.side ? { order: { side: query.side } } : {}),
      ...(query.exchange || normalizedSymbol
        ? {
            instrument: {
              ...(query.exchange ? { exchange: query.exchange } : {}),
              ...(normalizedSymbol ? { symbol: normalizedSymbol } : {}),
            },
          }
        : {}),
      ...(search
        ? {
            OR: [
              { executionId: { contains: search, mode: 'insensitive' } },
              {
                order: {
                  clientOrderId: { contains: search, mode: 'insensitive' },
                },
              },
              {
                account: {
                  accountNumber: { contains: search, mode: 'insensitive' },
                },
              },
              {
                account: {
                  user: { fullName: { contains: search, mode: 'insensitive' } },
                },
              },
              {
                account: {
                  user: { phone: { contains: search, mode: 'insensitive' } },
                },
              },
              {
                account: {
                  user: {
                    customerNo: { contains: search, mode: 'insensitive' },
                  },
                },
              },
              {
                instrument: {
                  symbol: { contains: search, mode: 'insensitive' },
                },
              },
            ],
          }
        : {}),
      ...(query.dateFrom || query.dateTo
        ? {
            executedAt: {
              ...(query.dateFrom ? { gte: new Date(query.dateFrom) } : {}),
              ...(query.dateTo ? { lte: new Date(query.dateTo) } : {}),
            },
          }
        : {}),
    };

    const skip = (query.page - 1) * query.pageSize;

    const [total, data] = await this.prisma.$transaction([
      this.prisma.trade.count({ where }),
      this.prisma.trade.findMany({
        where,
        include: {
          account: {
            select: {
              accountNumber: true,
              currency: true,
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
          instrument: true,
          order: {
            select: {
              id: true,
              clientOrderId: true,
              side: true,
              type: true,
              status: true,
            },
          },
        },
        orderBy: {
          executedAt: 'desc',
        },
        skip,
        take: query.pageSize,
      }),
    ]);

    return {
      page: query.page,
      pageSize: query.pageSize,
      total,
      totalPages: Math.ceil(total / query.pageSize),
      data,
    };
  }

  async myTradePairs(businessUserId: string, customerId?: string) {
    if (customerId) {
      const assigned = await this.prisma.user.count({
        where: {
          id: customerId,
          role: UserRole.CLIENT,
          assignedBusinessId: businessUserId,
        },
      });
      if (!assigned) throw new NotFoundException('Customer not found');
    }

    const trades = await this.prisma.trade.findMany({
      where: {
        account: {
          user: {
            role: UserRole.CLIENT,
            assignedBusinessId: businessUserId,
            ...(customerId ? { id: customerId } : {}),
          },
        },
      },
      include: {
        account: {
          select: {
            id: true,
            accountNumber: true,
            user: {
              select: {
                id: true,
                customerNo: true,
                fullName: true,
                phone: true,
              },
            },
          },
        },
        instrument: {
          select: { id: true, exchange: true, symbol: true, name: true },
        },
        order: { select: { side: true } },
      },
      orderBy: { executedAt: 'asc' },
    });

    type Lot = { trade: (typeof trades)[number]; remaining: number };
    const queues = new Map<string, Lot[]>();
    const rows: any[] = [];
    for (const trade of trades) {
      const key = `${trade.account.id}:${trade.instrument.id}`;
      const queue = queues.get(key) ?? [];
      queues.set(key, queue);
      if (trade.order.side === 'BUY') {
        queue.push({ trade, remaining: trade.quantity });
        continue;
      }
      let sellRemaining = trade.quantity;
      while (sellRemaining > 0 && queue.length) {
        const lot = queue[0];
        const quantity = Math.min(sellRemaining, lot.remaining);
        const buyFee = (Number(lot.trade.fees) * quantity) / lot.trade.quantity;
        const sellFee = (Number(trade.fees) * quantity) / trade.quantity;
        const buyPrice = Number(lot.trade.price);
        const sellPrice = Number(trade.price);
        rows.push({
          id: `${lot.trade.id}:${trade.id}:${lot.trade.quantity - lot.remaining}`,
          status: 'CLOSED',
          quantity,
          customer: lot.trade.account.user,
          accountNumber: lot.trade.account.accountNumber,
          instrument: lot.trade.instrument,
          buyExecutionId: lot.trade.executionId,
          buyTime: lot.trade.executedAt,
          buyPrice,
          buyFee,
          sellExecutionId: trade.executionId,
          sellTime: trade.executedAt,
          sellPrice,
          sellFee,
          holdingSeconds: Math.max(
            0,
            Math.floor(
              (trade.executedAt.getTime() - lot.trade.executedAt.getTime()) /
                1000,
            ),
          ),
          realizedPnl: (sellPrice - buyPrice) * quantity - buyFee - sellFee,
        });
        lot.remaining -= quantity;
        sellRemaining -= quantity;
        if (lot.remaining <= 0) queue.shift();
      }
    }

    for (const queue of queues.values()) {
      for (const lot of queue) {
        if (lot.remaining <= 0) continue;
        const buyFee =
          (Number(lot.trade.fees) * lot.remaining) / lot.trade.quantity;
        rows.push({
          id: `${lot.trade.id}:OPEN`,
          status: 'OPEN',
          quantity: lot.remaining,
          customer: lot.trade.account.user,
          accountNumber: lot.trade.account.accountNumber,
          instrument: lot.trade.instrument,
          buyExecutionId: lot.trade.executionId,
          buyTime: lot.trade.executedAt,
          buyPrice: Number(lot.trade.price),
          buyFee,
          sellExecutionId: null,
          sellTime: null,
          sellPrice: null,
          sellFee: null,
          holdingSeconds: null,
          realizedPnl: null,
        });
      }
    }
    rows.sort(
      (a, b) =>
        new Date(b.sellTime ?? b.buyTime).getTime() -
        new Date(a.sellTime ?? a.buyTime).getTime(),
    );
    return { data: rows, total: rows.length, matchingMethod: 'FIFO' };
  }

  async myPositions(
    businessUserId: string,
    query: { category?: string; search?: string },
  ) {
    const category = this.normalizePositionCategory(query.category);
    const search = query.search?.trim();

    const positions = await this.prisma.position.findMany({
      where: {
        quantity: { gt: 0 },
        account: {
          user: {
            role: UserRole.CLIENT,
            assignedBusinessId: businessUserId,
          },
        },
        ...(search
          ? {
              OR: [
                {
                  account: {
                    accountNumber: { contains: search, mode: 'insensitive' },
                  },
                },
                {
                  account: {
                    user: {
                      customerNo: { contains: search, mode: 'insensitive' },
                    },
                  },
                },
                {
                  account: {
                    user: {
                      fullName: { contains: search, mode: 'insensitive' },
                    },
                  },
                },
                {
                  account: {
                    user: { phone: { contains: search, mode: 'insensitive' } },
                  },
                },
                {
                  instrument: {
                    symbol: { contains: search, mode: 'insensitive' },
                  },
                },
                {
                  instrument: {
                    name: { contains: search, mode: 'insensitive' },
                  },
                },
                {
                  instrument: {
                    category: { contains: search, mode: 'insensitive' },
                  },
                },
              ],
            }
          : {}),
      },
      include: {
        account: {
          select: {
            accountNumber: true,
            currency: true,
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
        instrument: {
          include: {
            quote: true,
          },
        },
      },
      orderBy: {
        updatedAt: 'desc',
      },
    });

    const rows = positions
      .map((position) => {
        const positionCategory = this.positionCategory(position.instrument);
        const lastPrice =
          position.instrument.quote?.lastPrice ?? new Prisma.Decimal(0);
        const marketValue = lastPrice.mul(position.quantity).toDecimalPlaces(2);
        const unrealizedPnl = lastPrice
          .sub(position.averagePrice)
          .mul(position.quantity)
          .toDecimalPlaces(2);

        return {
          id: position.id,
          category: positionCategory,
          account: position.account,
          instrument: {
            id: position.instrument.id,
            exchange: position.instrument.exchange,
            symbol: position.instrument.symbol,
            name: position.instrument.name,
            logoUrl: position.instrument.logoUrl,
            category: position.instrument.category,
            currency: position.instrument.currency,
          },
          quantity: position.quantity,
          frozenQuantity: position.frozenQuantity,
          availableQuantity: position.quantity - position.frozenQuantity,
          averagePrice: position.averagePrice.toFixed(4),
          lastPrice: lastPrice.toFixed(4),
          marketValue: marketValue.toFixed(2),
          unrealizedPnl: unrealizedPnl.toFixed(2),
          realizedPnl: position.realizedPnl.toFixed(2),
          updatedAt: position.updatedAt,
        };
      })
      .filter((row) => !category || row.category === category);

    const summary = rows.reduce(
      (total, row) => {
        total.quantity += row.quantity;
        total.marketValue = total.marketValue.add(row.marketValue);
        total.unrealizedPnl = total.unrealizedPnl.add(row.unrealizedPnl);
        total[row.category as 'INSTITUTIONAL' | 'IPO' | 'OTC'] += 1;
        return total;
      },
      {
        quantity: 0,
        marketValue: new Prisma.Decimal(0),
        unrealizedPnl: new Prisma.Decimal(0),
        INSTITUTIONAL: 0,
        IPO: 0,
        OTC: 0,
      },
    );

    return {
      summary: {
        count: rows.length,
        quantity: summary.quantity,
        marketValue: summary.marketValue.toFixed(2),
        unrealizedPnl: summary.unrealizedPnl.toFixed(2),
        categories: {
          INSTITUTIONAL: summary.INSTITUTIONAL,
          IPO: summary.IPO,
          OTC: summary.OTC,
        },
      },
      data: rows,
    };
  }

  async customerLastLogin(businessUserId: string, customerId: string) {
    const customer = await this.prisma.user.findFirst({
      where: {
        id: customerId,
        role: UserRole.CLIENT,
        assignedBusinessId: businessUserId,
      },
      select: {
        id: true,
        fullName: true,
      },
    });

    if (!customer) {
      throw new NotFoundException('客户不存在');
    }

    const login = await this.prisma.loginAudit.findFirst({
      where: {
        userId: customerId,
        success: true,
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return {
      customer,
      lastLogin: login,
    };
  }

  async customerLoginAudits(businessUserId: string, customerId: string) {
    const customer = await this.prisma.user.findFirst({
      where: {
        id: customerId,
        role: UserRole.CLIENT,
        assignedBusinessId: businessUserId,
      },
      select: {
        id: true,
        fullName: true,
      },
    });

    if (!customer) {
      throw new NotFoundException('客户不存在');
    }

    return this.prisma.loginAudit.findMany({
      where: {
        userId: customerId,
      },
      orderBy: {
        createdAt: 'desc',
      },
      take: 100,
    });
  }

  async customerLoginRisk(businessUserId: string, customerId: string) {
    const customer = await this.prisma.user.findFirst({
      where: {
        id: customerId,
        role: UserRole.CLIENT,
        assignedBusinessId: businessUserId,
      },
      select: {
        id: true,
        fullName: true,
      },
    });

    if (!customer) {
      throw new NotFoundException('客户不存在');
    }

    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const [failedCount, lastFailed, lastSuccess] =
      await this.prisma.$transaction([
        this.prisma.loginAudit.count({
          where: {
            userId: customerId,
            success: false,
            createdAt: {
              gte: since,
            },
          },
        }),

        this.prisma.loginAudit.findFirst({
          where: {
            userId: customerId,
            success: false,
          },
          orderBy: {
            createdAt: 'desc',
          },
        }),

        this.prisma.loginAudit.findFirst({
          where: {
            userId: customerId,
            success: true,
          },
          orderBy: {
            createdAt: 'desc',
          },
        }),
      ]);

    let riskLevel: 'LOW' | 'MEDIUM' | 'HIGH' = 'LOW';

    if (failedCount >= 10) {
      riskLevel = 'HIGH';
    } else if (failedCount >= 5) {
      riskLevel = 'MEDIUM';
    }

    return {
      customer,
      failedLoginCount24h: failedCount,
      riskLevel,
      lastFailedLogin: lastFailed,
      lastSuccessfulLogin: lastSuccess,
    };
  }

  async sharedIpRisks(businessUserId: string) {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const audits = await this.prisma.loginAudit.findMany({
      where: {
        success: true,
        createdAt: {
          gte: since,
        },
        ipAddress: {
          not: null,
        },
        user: {
          role: UserRole.CLIENT,
          assignedBusinessId: businessUserId,
        },
      },

      select: {
        ipAddress: true,
        createdAt: true,

        user: {
          select: {
            id: true,
            fullName: true,
            phone: true,
          },
        },
      },

      orderBy: {
        createdAt: 'desc',
      },
    });

    const ipMap = new Map<
      string,
      {
        ipAddress: string;
        customers: Map<
          string,
          {
            id: string;
            fullName: string;
            phone: string | null;
            lastLoginAt: Date;
          }
        >;
      }
    >();

    for (const audit of audits) {
      if (!audit.ipAddress) {
        continue;
      }

      let entry = ipMap.get(audit.ipAddress);

      if (!entry) {
        entry = {
          ipAddress: audit.ipAddress,
          customers: new Map(),
        };

        ipMap.set(audit.ipAddress, entry);
      }

      const existing = entry.customers.get(audit.user.id);

      if (!existing || audit.createdAt > existing.lastLoginAt) {
        entry.customers.set(audit.user.id, {
          id: audit.user.id,
          fullName: audit.user.fullName,
          phone: audit.user.phone,
          lastLoginAt: audit.createdAt,
        });
      }
    }

    return Array.from(ipMap.values())
      .map((item) => ({
        ipAddress: item.ipAddress,
        customerCount: item.customers.size,
        customers: Array.from(item.customers.values()),
      }))
      .filter((item) => item.customerCount >= 2)
      .sort((a, b) => b.customerCount - a.customerCount);
  }

  async myRiskDashboard(businessUserId: string) {
    const [
      sharedIpRisks,
      sharedDeviceRisks,
      failedLogin24h,
      highRiskCustomers,
    ] = await Promise.all([
      this.sharedIpRisks(businessUserId),

      this.sharedDeviceRisks(businessUserId),

      this.prisma.loginAudit.count({
        where: {
          success: false,

          createdAt: {
            gte: new Date(Date.now() - 24 * 60 * 60 * 1000),
          },

          user: {
            assignedBusinessId: businessUserId,
          },
        },
      }),

      this.prisma.user.count({
        where: {
          role: UserRole.CLIENT,

          assignedBusinessId: businessUserId,

          loginAudits: {
            some: {
              success: false,

              createdAt: {
                gte: new Date(Date.now() - 24 * 60 * 60 * 1000),
              },
            },
          },
        },
      }),
    ]);

    return {
      sharedIpCustomers: new Set(
        sharedIpRisks.flatMap((item) =>
          item.customers.map((customer) => customer.id),
        ),
      ).size,

      sharedDeviceCustomers: new Set(
        sharedDeviceRisks.flatMap((item) =>
          item.customers.map((customer) => customer.id),
        ),
      ).size,

      failedLogin24h,

      highRiskCustomers,
    };
  }

  async sharedDeviceRisks(businessUserId: string) {
    const since = new Date(Date.now() - 24 * 60 * 60 * 1000);

    const audits = await this.prisma.loginAudit.findMany({
      where: {
        success: true,

        createdAt: {
          gte: since,
        },

        userAgent: {
          not: null,
        },

        user: {
          role: UserRole.CLIENT,
          assignedBusinessId: businessUserId,
        },
      },

      select: {
        userAgent: true,
        createdAt: true,

        user: {
          select: {
            id: true,
            fullName: true,
            phone: true,
          },
        },
      },

      orderBy: {
        createdAt: 'desc',
      },
    });

    const deviceMap = new Map<string, Map<string, any>>();

    for (const audit of audits) {
      if (!audit.userAgent) {
        continue;
      }

      if (!deviceMap.has(audit.userAgent)) {
        deviceMap.set(audit.userAgent, new Map());
      }

      const customers = deviceMap.get(audit.userAgent)!;

      const old = customers.get(audit.user.id);

      if (!old || audit.createdAt > old.lastLoginAt) {
        customers.set(audit.user.id, {
          id: audit.user.id,
          fullName: audit.user.fullName,
          phone: audit.user.phone,
          lastLoginAt: audit.createdAt,
        });
      }
    }

    return Array.from(deviceMap.entries())
      .map(([userAgent, customers]) => ({
        userAgent,
        customerCount: customers.size,
        customers: Array.from(customers.values()),
      }))
      .filter((item) => item.customerCount >= 2)
      .sort((a, b) => b.customerCount - a.customerCount);
  }
}
