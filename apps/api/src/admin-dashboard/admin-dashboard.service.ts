import { Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class AdminDashboardService {
  constructor(private readonly prisma: PrismaService) {}

  async getSummary() {
    const [
      totalUsers,
      activeUsers,
      totalAccounts,
      totalOrders,
      openOrders,
      filledOrders,
      cancelledOrders,
      totalTrades,
      accounts,
      tradeTotals,
    ] = await this.prisma.$transaction([
      this.prisma.user.count(),
      this.prisma.user.count({
        where: {
          status: 'ACTIVE',
        },
      }),
      this.prisma.account.count(),
      this.prisma.order.count(),
      this.prisma.order.count({
        where: {
          status: {
            in: ['OPEN', 'PARTIALLY_FILLED'],
          },
        },
      }),
      this.prisma.order.count({
        where: {
          status: 'FILLED',
        },
      }),
      this.prisma.order.count({
        where: {
          status: 'CANCELLED',
        },
      }),
      this.prisma.trade.count(),
      this.prisma.account.findMany({
        select: {
          cashBalance: true,
          buyingPower: true,
          frozenBalance: true,
          positions: {
            where: {
              quantity: {
                gt: 0,
              },
            },
            select: {
              quantity: true,
              instrument: {
                select: {
                  quote: {
                    select: {
                      lastPrice: true,
                    },
                  },
                },
              },
            },
          },
        },
      }),
      this.prisma.trade.aggregate({
        _sum: {
          grossAmount: true,
          fees: true,
          netAmount: true,
          quantity: true,
        },
      }),
    ]);

    let totalCashBalance = new Prisma.Decimal(0);
    let totalBuyingPower = new Prisma.Decimal(0);
    let totalFrozenBalance = new Prisma.Decimal(0);
    let totalHoldingsMarketValue = new Prisma.Decimal(0);

    for (const account of accounts) {
      totalCashBalance = totalCashBalance.add(account.cashBalance);
      totalBuyingPower = totalBuyingPower.add(account.buyingPower);
      totalFrozenBalance = totalFrozenBalance.add(account.frozenBalance);

      for (const position of account.positions) {
        const lastPrice =
          position.instrument.quote?.lastPrice ?? new Prisma.Decimal(0);

        totalHoldingsMarketValue = totalHoldingsMarketValue.add(
          lastPrice.mul(position.quantity),
        );
      }
    }

    const totalAssets = totalCashBalance
      .add(totalHoldingsMarketValue)
      .toDecimalPlaces(2);

    return {
      users: {
        total: totalUsers,
        active: activeUsers,
        inactive: totalUsers - activeUsers,
      },
      accounts: {
        total: totalAccounts,
        cashBalance: totalCashBalance.toFixed(2),
        buyingPower: totalBuyingPower.toFixed(2),
        frozenBalance: totalFrozenBalance.toFixed(2),
        holdingsMarketValue: totalHoldingsMarketValue.toFixed(2),
        totalAssets: totalAssets.toFixed(2),
      },
      orders: {
        total: totalOrders,
        open: openOrders,
        filled: filledOrders,
        cancelled: cancelledOrders,
      },
      trades: {
        total: totalTrades,
        totalQuantity: tradeTotals._sum.quantity ?? 0,
        grossAmount: tradeTotals._sum.grossAmount?.toFixed(2) ?? '0.00',
        fees: tradeTotals._sum.fees?.toFixed(2) ?? '0.00',
        netAmount: tradeTotals._sum.netAmount?.toFixed(2) ?? '0.00',
      },
      generatedAt: new Date(),
    };
  }

  async getRecentActivity() {
    const [orders, trades, transactions] = await this.prisma.$transaction([
      this.prisma.order.findMany({
        take: 10,
        orderBy: {
          placedAt: 'desc',
        },
        include: {
          account: {
            select: {
              accountNumber: true,
              user: {
                select: {
                  fullName: true,
                  phone: true,
                },
              },
            },
          },
          instrument: {
            select: {
              exchange: true,
              symbol: true,
              name: true,
            },
          },
        },
      }),
      this.prisma.trade.findMany({
        take: 10,
        orderBy: {
          executedAt: 'desc',
        },
        include: {
          account: {
            select: {
              accountNumber: true,
              user: {
                select: {
                  fullName: true,
                  phone: true,
                },
              },
            },
          },
          instrument: {
            select: {
              exchange: true,
              symbol: true,
              name: true,
            },
          },
          order: {
            select: {
              clientOrderId: true,
              side: true,
              type: true,
              timeInForce: true,
              status: true,
            },
          },
        },
      }),
      this.prisma.accountTransaction.findMany({
        take: 10,
        orderBy: {
          createdAt: 'desc',
        },
        include: {
          account: {
            select: {
              accountNumber: true,
              user: {
                select: {
                  fullName: true,
                  phone: true,
                },
              },
            },
          },
          createdBy: {
            select: {
              fullName: true,
              phone: true,
              role: true,
            },
          },
        },
      }),
    ]);

    return {
      orders,
      trades,
      transactions: transactions.map((transaction) => ({
        ...transaction,
        amount: transaction.amount.toFixed(2),
        balanceBefore: transaction.balanceBefore.toFixed(2),
        balanceAfter: transaction.balanceAfter.toFixed(2),
      })),
      generatedAt: new Date(),
    };
  }
}
