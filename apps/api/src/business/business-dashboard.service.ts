import { Prisma } from '../generated/prisma/client';
import { InviteCodeStatus, UserRole } from '../generated/prisma/enums';
import { moneyDecimal } from '../common/money';
import { PrismaService } from '../prisma/prisma.service';

export class BusinessDashboardService {
  constructor(private readonly prisma: PrismaService) {}

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
}
