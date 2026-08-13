import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';

import { PrismaService } from '../prisma/prisma.service';
import { Prisma } from '../generated/prisma/client';
import { UserRole } from '../generated/prisma/enums';

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

  async listDebts(userId: string, role: UserRole, search?: string) {
    const keyword = search?.trim();
    const debts = await this.prisma.ipoDebt.findMany({
      where: {
        ...(role === UserRole.BUSINESS
          ? {
              account: {
                user: {
                  assignedBusinessId: userId,
                },
              },
            }
          : {}),
        ...(keyword
          ? {
              OR: [
                { account: { accountNumber: { contains: keyword, mode: 'insensitive' } } },
                { account: { user: { fullName: { contains: keyword, mode: 'insensitive' } } } },
                { account: { user: { phone: { contains: keyword, mode: 'insensitive' } } } },
                { account: { user: { customerNo: { contains: keyword, mode: 'insensitive' } } } },
                { ipoApplication: { ipo: { symbol: { contains: keyword, mode: 'insensitive' } } } },
                { ipoApplication: { ipo: { companyName: { contains: keyword, mode: 'insensitive' } } } },
              ],
            }
          : {}),
      },
      include: {
        account: {
          select: {
            accountNumber: true,
            user: {
              select: {
                customerNo: true,
                fullName: true,
                phone: true,
              },
            },
          },
        },
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

    return debts.map((debt) => ({
      id: debt.id,
      amount: debt.amount.toFixed(2),
      paidAmount: debt.paidAmount.toFixed(2),
      outstandingAmount: debt.amount.sub(debt.paidAmount).toFixed(2),
      status: debt.status,
      createdAt: debt.createdAt,
      updatedAt: debt.updatedAt,
      account: debt.account,
      application: {
        id: debt.ipoApplication.id,
        allocatedQuantity: debt.ipoApplication.allocatedQuantity,
        allocatedPrice: debt.ipoApplication.allocatedPrice?.toFixed(2) ?? null,
        paymentStatus: debt.ipoApplication.paymentStatus,
        status: debt.ipoApplication.status,
      },
      ipo: {
        symbol: debt.ipoApplication.ipo.symbol,
        companyName: debt.ipoApplication.ipo.companyName,
        issuePrice: debt.ipoApplication.ipo.issuePrice.toFixed(2),
      },
    }));
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
    if (!Number.isInteger(quantity) || quantity < 1 || quantity > 1_000_000) {
      throw new BadRequestException('IPO allocation quantity is invalid');
    }
    if (!Number.isFinite(price) || price <= 0 || price > 100_000_000) {
      throw new BadRequestException('IPO allocation price is invalid');
    }
    const totalAmount = Number((quantity * price).toFixed(2));
    if (!Number.isSafeInteger(Math.round(totalAmount * 100))) {
      throw new BadRequestException('IPO allocation amount is too large');
    }

    return this.prisma.$transaction(async (tx) => {
      const application = await tx.ipoApplication.findUnique({
        where: { id: applicationId },
        include: { ipo: true, account: true },
      });
      if (!application) throw new NotFoundException('IPO application not found');
      if (application.status !== 'PENDING') throw new ConflictException('IPO application already processed');
      if (!application.ipo.instrumentId) throw new BadRequestException('IPO instrument not configured');

      const instrumentId = application.ipo.instrumentId;
      const account = application.account;

      const cashBalance = Number(account.cashBalance);
      let debtAmount = 0;

      const claimed = await tx.ipoApplication.updateMany({
        where: { id: application.id, status: 'PENDING' },
        data: {
          allocatedQuantity: quantity,
          allocatedPrice: price,
          allocatedAmount: totalAmount,
          status: 'ALLOTTED',
          paymentStatus: cashBalance >= totalAmount ? 'PAID' : 'PENDING',
        },
      });
      if (claimed.count !== 1) throw new ConflictException('IPO application was processed by another operator');

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

      if (debtAmount <= 0) {
        await this.settleIpoApplication(tx, {
          applicationId: application.id,
          accountId: account.id,
          instrumentId,
          quantity,
          price,
          totalAmount,
        });
      }

      const updated = await tx.ipoApplication.findUniqueOrThrow({ where: { id: application.id } });

      await tx.notification.create({
        data: {
          userId: account.userId,
          type: 'IPO',
          title: debtAmount > 0 ? 'IPO allotment payment required' : 'IPO allotment completed',
          body: debtAmount > 0
            ? `${application.ipo.symbol} was allotted. Pay the outstanding amount to complete settlement.`
            : `${application.ipo.symbol} was settled and added to your holdings.`,
          referenceId: application.id,
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
    }, { isolationLevel: Prisma.TransactionIsolationLevel.Serializable });
  }

  async settleIpoApplication(
    tx: any,
    input: {
      applicationId: string;
      accountId: string;
      instrumentId: string;
      quantity: number;
      price: number;
      totalAmount: number;
    },
  ) {
    const existingOrder = await tx.order.findUnique({
      where: {
        accountId_clientOrderId: {
          accountId: input.accountId,
          clientOrderId: `IPO-${input.applicationId}`,
        },
      },
    });

    if (existingOrder) {
      return existingOrder;
    }

    const order = await tx.order.create({
      data: {
        clientOrderId: `IPO-${input.applicationId}`,
        accountId: input.accountId,
        instrumentId: input.instrumentId,
        side: 'BUY',
        type: 'MARKET',
        status: 'FILLED',
        quantity: input.quantity,
        filledQuantity: input.quantity,
        limitPrice: input.price,
        averageFillPrice: input.price,
        completedAt: new Date(),
      },
    });

    await tx.trade.create({
      data: {
        executionId: `IPO-EXEC-${input.applicationId}`,
        orderId: order.id,
        accountId: input.accountId,
        instrumentId: input.instrumentId,
        quantity: input.quantity,
        price: input.price,
        grossAmount: input.totalAmount,
        fees: 0,
        netAmount: input.totalAmount,
      },
    });

    const position = await tx.position.findUnique({
      where: {
        accountId_instrumentId: {
          accountId: input.accountId,
          instrumentId: input.instrumentId,
        },
      },
    });

    if (position) {
      const oldQty = position.quantity;
      const newQty = oldQty + input.quantity;
      const avgPrice =
        (Number(position.averagePrice) * oldQty +
          input.price * input.quantity) /
        newQty;

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
          accountId: input.accountId,
          instrumentId: input.instrumentId,
          quantity: input.quantity,
          averagePrice: input.price,
        },
      });
    }

    return order;
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
    return this.prisma.$transaction(async (tx) => {
      await tx.instrument.update({
        where: { id: instrumentId },
        data: { category: 'IPO' },
      });
      return tx.ipo.update({
        where: { id: ipoId },
        data: { instrumentId },
      });
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
