import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';

import { CreateIpoDto } from './dto/create-ipo.dto';
import { UpdateIpoStatusDto } from './dto/update-ipo-status.dto';

@Injectable()
export class IpoService {
  constructor(private readonly prisma: PrismaService) {}

  async create(dto: CreateIpoDto) {
    const openDate = new Date(dto.openDate);

    const closeDate = new Date(dto.closeDate);

    if (openDate >= closeDate) {
      throw new BadRequestException('openDate must be earlier than closeDate');
    }

    const ipo = await this.prisma.ipo.create({
      data: {
        symbol: dto.symbol.trim().toUpperCase(),
        companyName: dto.companyName.trim(),
        exchange: dto.exchange,

        instrumentId: dto.instrumentId,

        issuePrice: dto.issuePrice,
        lotSize: dto.lotSize,
        totalShares: dto.totalShares,
        availableShares: dto.totalShares,

        openDate,
        closeDate,
        status: 'DRAFT',
      },
    });

    return {
      message: 'IPO created successfully',

      ipo: {
        ...ipo,

        issuePrice: ipo.issuePrice.toFixed(2),
      },
    };
  }

  async list() {
    const ipos = await this.prisma.ipo.findMany({
      include: {
        _count: {
          select: {
            applications: true,
          },
        },
      },

      orderBy: {
        createdAt: 'desc',
      },
    });

    return {
      total: ipos.length,

      data: ipos.map((ipo) => ({
        id: ipo.id,

        symbol: ipo.symbol,

        companyName: ipo.companyName,

        exchange: ipo.exchange,

        issuePrice: ipo.issuePrice.toFixed(2),

        lotSize: ipo.lotSize,

        totalShares: ipo.totalShares,

        availableShares: ipo.availableShares,

        openDate: ipo.openDate,

        closeDate: ipo.closeDate,

        status: ipo.status,

        applicationCount: ipo._count.applications,

        createdAt: ipo.createdAt,

        updatedAt: ipo.updatedAt,
      })),
    };
  }

  async findOne(id: string) {
    const ipo = await this.prisma.ipo.findUnique({
      where: {
        id,
      },

      include: {
        applications: {
          include: {
            account: {
              select: {
                id: true,

                accountNumber: true,

                currency: true,

                user: {
                  select: {
                    id: true,
                    fullName: true,

                    phone: true,

                    role: true,

                    status: true,
                  },
                },
              },
            },
          },

          orderBy: {
            createdAt: 'desc',
          },
        },
      },
    });

    if (!ipo) {
      throw new NotFoundException('IPO not found');
    }

    return {
      ...ipo,

      issuePrice: ipo.issuePrice.toFixed(2),

      applications: ipo.applications.map((application) => ({
        ...application,

        allocatedPrice: application.allocatedPrice?.toFixed(2) ?? null,

        allocatedAmount: application.allocatedAmount?.toFixed(2) ?? null,
      })),
    };
  }

  async updateStatus(id: string, dto: UpdateIpoStatusDto) {
    const ipo = await this.prisma.ipo.findUnique({
      where: {
        id,
      },
    });

    if (!ipo) {
      throw new NotFoundException('IPO not found');
    }

    const updated = await this.prisma.ipo.update({
      where: {
        id,
      },

      data: {
        status: dto.status,
      },
    });

    return {
      message: 'IPO status updated successfully',

      previousStatus: ipo.status,

      ipo: {
        id: updated.id,

        symbol: updated.symbol,

        status: updated.status,
      },
    };
  }

  async listOpenIpos() {
    const now = new Date();

    const ipos = await this.prisma.ipo.findMany({
      where: {
        status: 'OPEN',

        openDate: {
          lte: now,
        },

        closeDate: {
          gte: now,
        },
      },

      include: {
        _count: {
          select: {
            applications: true,
          },
        },
      },

      orderBy: {
        openDate: 'asc',
      },
    });

    return {
      total: ipos.length,

      data: ipos.map((ipo) => ({
        id: ipo.id,

        symbol: ipo.symbol,

        companyName: ipo.companyName,

        exchange: ipo.exchange,

        issuePrice: ipo.issuePrice.toFixed(2),

        lotSize: ipo.lotSize,

        totalShares: ipo.totalShares,

        availableShares: ipo.availableShares,

        openDate: ipo.openDate,

        closeDate: ipo.closeDate,

        status: ipo.status,

        applicationCount: ipo._count.applications,
      })),
    };
  }

  async apply(userId: string, ipoId: string) {
    const now = new Date();

    const account = await this.prisma.account.findUnique({
      where: {
        userId,
      },

      select: {
        id: true,

        accountNumber: true,
      },
    });

    if (!account) {
      throw new NotFoundException('Trading account not found');
    }

    const ipo = await this.prisma.ipo.findUnique({
      where: {
        id: ipoId,
      },

      select: {
        id: true,

        symbol: true,

        companyName: true,

        exchange: true,

        issuePrice: true,

        openDate: true,

        closeDate: true,

        status: true,
      },
    });

    if (!ipo) {
      throw new NotFoundException('IPO not found');
    }

    if (ipo.status !== 'OPEN') {
      throw new BadRequestException('IPO is not open for applications');
    }

    if (now < ipo.openDate || now > ipo.closeDate) {
      throw new BadRequestException('IPO application period is not active');
    }

    const appliedCount = await this.prisma.ipoApplication.count({
      where: {
        accountId: account.id,

        ipoId: ipo.id,
      },
    });

    // 达到5次，不报错，只返回不可申请状态

    if (appliedCount >= 5) {
      return {
        message: 'Maximum IPO applications reached',

        canApply: false,

        appliedCount,

        maxApplyCount: 5,
      };
    }

    const application = await this.prisma.ipoApplication.create({
      data: {
        ipoId: ipo.id,

        accountId: account.id,

        quantity: 1,

        amount: ipo.issuePrice,

        status: 'PENDING',

        paymentStatus: 'PENDING',
      },
    });

    return {
      message: 'IPO application submitted successfully',

      canApply: true,

      appliedCount: appliedCount + 1,

      maxApplyCount: 5,

      application: {
        id: application.id,

        status: application.status,

        paymentStatus: application.paymentStatus,

        createdAt: application.createdAt,

        accountNumber: account.accountNumber,

        ipo: {
          id: ipo.id,

          symbol: ipo.symbol,

          companyName: ipo.companyName,

          exchange: ipo.exchange,

          issuePrice: ipo.issuePrice.toFixed(2),
        },
      },
    };
  }

  async listMyApplications(userId: string) {
    const account = await this.prisma.account.findUnique({
      where: {
        userId,
      },

      select: {
        id: true,
        accountNumber: true,
      },
    });

    if (!account) {
      throw new NotFoundException('Trading account not found');
    }

    const applications = await this.prisma.ipoApplication.findMany({
      where: {
        accountId: account.id,
      },

      include: {
        ipo: true,
      },

      orderBy: {
        createdAt: 'desc',
      },
    });

    return {
      accountNumber: account.accountNumber,

      total: applications.length,

      data: applications.map((application) => ({
        id: application.id,

        status: application.status,

        paymentStatus: application.paymentStatus,

        allocatedQuantity: application.allocatedQuantity ?? null,

        allocatedPrice: application.allocatedPrice?.toFixed(2) ?? null,

        allocatedAmount: application.allocatedAmount?.toFixed(2) ?? null,

        createdAt: application.createdAt,

        updatedAt: application.updatedAt,

        ipo: {
          id: application.ipo.id,

          symbol: application.ipo.symbol,

          companyName: application.ipo.companyName,

          exchange: application.ipo.exchange,

          issuePrice: application.ipo.issuePrice.toFixed(2),

          status: application.ipo.status,

          openDate: application.ipo.openDate,

          closeDate: application.ipo.closeDate,
        },
      })),
    };
  }

  async allocate(applicationId: string, quantity: number, price: number) {
    const application = await this.prisma.ipoApplication.findUnique({
      where: {
        id: applicationId,
      },
      include: {
        ipo: true,
        account: true,
      },
    });

    if (!application) {
      throw new NotFoundException('IPO application not found');
    }

    if (application.status !== 'PENDING') {
      throw new BadRequestException('IPO application already processed');
    }

    if (!application.ipo.instrumentId) {
      throw new BadRequestException('IPO instrument not configured');
    }

    const instrumentId = application.ipo.instrumentId;
    const totalAmount = quantity * price;

    return await this.prisma.$transaction(async (tx) => {
      const account = await tx.account.findUnique({
        where: {
          id: application.accountId,
        },
      });

      if (!account) {
        throw new NotFoundException('Account not found');
      }

      const cashBalance = Number(account.cashBalance);

      let debtAmount = 0;

      if (cashBalance >= totalAmount) {
        await tx.account.update({
          where: {
            id: account.id,
          },
          data: {
            cashBalance: {
              decrement: totalAmount,
            },
          },
        });
      } else {
        debtAmount = totalAmount - cashBalance;

        await tx.account.update({
          where: {
            id: account.id,
          },
          data: {
            cashBalance: 0,
          },
        });

        await tx.ipoDebt.create({
          data: {
            accountId: account.id,

            ipoApplicationId: application.id,

            amount: debtAmount,

            paidAmount: 0,

            status: 'OPEN',
          },
        });
      }

      // 创建系统 IPO BUY Order

      const order = await tx.order.create({
        data: {
          clientOrderId: `IPO-${application.id}`,

          accountId: account.id,

          instrumentId,

          side: 'BUY',

          type: 'MARKET',

          status: 'FILLED',

          quantity,

          filledQuantity: quantity,

          limitPrice: price,

          averageFillPrice: price,

          completedAt: new Date(),
        },
      });

      // 创建 Trade

      await tx.trade.create({
        data: {
          executionId: `IPO-EXEC-${application.id}`,

          orderId: order.id,

          accountId: account.id,

          instrumentId,

          quantity,

          price,

          grossAmount: totalAmount,

          fees: 0,

          netAmount: totalAmount,
        },
      });

      // 增加 Position

      const position = await tx.position.findUnique({
        where: {
          accountId_instrumentId: {
            accountId: account.id,

            instrumentId,
          },
        },
      });

      if (position) {
        const oldQty = position.quantity;

        const newQty = oldQty + quantity;

        const avgPrice =
          (Number(position.averagePrice) * oldQty + price * quantity) / newQty;

        await tx.position.update({
          where: {
            id: position.id,
          },

          data: {
            quantity: newQty,

            averagePrice: avgPrice,
          },
        });
      } else {
        await tx.position.create({
          data: {
            accountId: account.id,

            instrumentId,

            quantity,

            averagePrice: price,
          },
        });
      }

      // 更新 IPO Application

      const updated = await tx.ipoApplication.update({
        where: {
          id: application.id,
        },

        data: {
          allocatedQuantity: quantity,
          allocatedPrice: price,
          allocatedAmount: totalAmount,
          status: 'ALLOTTED',
          paymentStatus: debtAmount > 0 ? 'PENDING' : 'PAID',
        },
      });

      return {
        application: updated,

        debtAmount,

        message:
          debtAmount > 0
            ? 'IPO allocated with outstanding debt'
            : 'IPO allocated and settled successfully',
      };
    });
  }

  async getApplicationLimit(userId: string, ipoId: string) {
    const account = await this.prisma.account.findUnique({
      where: {
        userId,
      },
      select: {
        id: true,
      },
    });

    if (!account) {
      throw new NotFoundException('Trading account not found');
    }

    const count = await this.prisma.ipoApplication.count({
      where: {
        accountId: account.id,
        ipoId,
      },
    });

    const maxApplyCount = 5;

    return {
      appliedCount: count,
      maxApplyCount,
      canApply: count < maxApplyCount,
    };
  }

  async setInstrument(ipoId: string, instrumentId: string) {
    return this.prisma.ipo.update({
      where: {
        id: ipoId,
      },
      data: {
        instrumentId,
      },
    });
  }

  async listMyDebts(userId: string) {
    const account = await this.prisma.account.findUnique({
      where: {
        userId,
      },
      select: {
        id: true,
      },
    });

    if (!account) {
      throw new NotFoundException('Trading account not found');
    }

    const debts = await this.prisma.ipoDebt.findMany({
      where: {
        accountId: account.id,
      },
      include: {
        ipoApplication: {
          include: {
            ipo: true,
          },
        },
      },
      orderBy: {
        createdAt: 'desc',
      },
    });

    return debts;
  }

  async payDebt(userId: string, amount: number) {
    const account = await this.prisma.account.findUnique({
      where: {
        userId,
      },
    });

    if (!account) {
      throw new NotFoundException('Trading account not found');
    }

    return this.prisma.$transaction(async (tx) => {
      let remaining = amount;

      const debts = await tx.ipoDebt.findMany({
        where: {
          accountId: account.id,
          status: {
            in: ['OPEN', 'PARTIAL'],
          },
        },
        orderBy: {
          createdAt: 'asc',
        },
      });

      for (const debt of debts) {
        if (remaining <= 0) break;

        const unpaid = Number(debt.amount) - Number(debt.paidAmount);

        const pay = Math.min(unpaid, remaining);

        const newPaid = Number(debt.paidAmount) + pay;

        await tx.ipoDebt.update({
          where: {
            id: debt.id,
          },
          data: {
            paidAmount: newPaid,
            status: newPaid >= Number(debt.amount) ? 'PAID' : 'PARTIAL',
          },
        });

        if (newPaid >= Number(debt.amount)) {
          await tx.ipoApplication.update({
            where: {
              id: debt.ipoApplicationId,
            },
            data: {
              paymentStatus: 'PAID',
            },
          });
        }

        remaining -= pay;
      }

      await tx.account.update({
        where: {
          id: account.id,
        },
        data: {
          cashBalance: {
            increment: amount - remaining,
          },
        },
      });

      return {
        paid: amount - remaining,
        remainingDebtPayment: remaining,
      };
    });
  }
}
