import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ListTransactionsQueryDto } from './dto/list-transactions-query.dto';
@Injectable()
export class AccountService {
  constructor(private readonly prisma: PrismaService) {}

  async getMyAccount(userId: string) {
    const account = await this.prisma.account.findUnique({
      where: { userId },
      select: {
        id: true,
        accountNumber: true,
        cashBalance: true,
        buyingPower: true,
        frozenBalance: true,
        currency: true,
        isLive: true,
        createdAt: true,
        updatedAt: true,
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
    });

    if (!account) {
      throw new NotFoundException('Account not found');
    }

    const holdingsMarketValue = account.positions.reduce((total, position) => {
      const lastPrice =
        position.instrument.quote?.lastPrice ?? new Prisma.Decimal(0);

      return total.add(lastPrice.mul(position.quantity));
    }, new Prisma.Decimal(0));

    const totalAsset = account.cashBalance
      .add(holdingsMarketValue)
      .toDecimalPlaces(2);

    return {
      id: account.id,
      accountNumber: account.accountNumber,
      currency: account.currency,
      isLive: account.isLive,
      balances: {
        cashBalance: account.cashBalance.toFixed(2),
        buyingPower: account.buyingPower.toFixed(2),
        frozenBalance: account.frozenBalance.toFixed(2),
        holdingsMarketValue: holdingsMarketValue.toFixed(2),
        totalAsset: totalAsset.toFixed(2),
      },
      createdAt: account.createdAt,
      updatedAt: account.updatedAt,
    };
  }
  async getPortfolioSummary(userId: string) {
    const account = await this.prisma.account.findUnique({
      where: { userId },
      include: {
        positions: {
          where: {
            quantity: {
              gt: 0,
            },
          },
          include: {
            instrument: {
              include: {
                quote: true,
              },
            },
          },
        },
      },
    });

    if (!account) {
      throw new NotFoundException('Account not found');
    }

    let holdingsMarketValue = new Prisma.Decimal(0);
    let totalUnrealizedPnl = new Prisma.Decimal(0);
    let totalRealizedPnl = new Prisma.Decimal(0);

    const positions = account.positions.map((position) => {
      const lastPrice =
        position.instrument.quote?.lastPrice ?? new Prisma.Decimal(0);

      const marketValue = lastPrice.mul(position.quantity).toDecimalPlaces(2);

      const unrealizedPnl = lastPrice
        .sub(position.averagePrice)
        .mul(position.quantity)
        .toDecimalPlaces(2);

      holdingsMarketValue = holdingsMarketValue.add(marketValue);

      totalUnrealizedPnl = totalUnrealizedPnl.add(unrealizedPnl);

      totalRealizedPnl = totalRealizedPnl.add(position.realizedPnl);

      return {
        exchange: position.instrument.exchange,
        symbol: position.instrument.symbol,
        name: position.instrument.name,
        logoUrl: position.instrument.logoUrl,
        category: position.instrument.category,
        currency: position.instrument.currency,
        quantity: position.quantity,
        frozenQuantity: position.frozenQuantity,
        availableQuantity: Math.max(
          0,
          position.quantity - position.frozenQuantity,
        ),
        averagePrice: position.averagePrice.toFixed(4),
        lastPrice: lastPrice.toFixed(4),
        marketValue: marketValue.toFixed(2),
        realizedPnl: position.realizedPnl.toFixed(2),
        unrealizedPnl: unrealizedPnl.toFixed(2),
      };
    });

    const totalAsset = account.cashBalance
      .add(holdingsMarketValue)
      .toDecimalPlaces(2);

    return {
      accountNumber: account.accountNumber,
      currency: account.currency,
      balances: {
        cashBalance: account.cashBalance.toFixed(2),
        buyingPower: account.buyingPower.toFixed(2),
        frozenBalance: account.frozenBalance.toFixed(2),
        holdingsMarketValue: holdingsMarketValue.toFixed(2),
        totalAsset: totalAsset.toFixed(2),
      },
      pnl: {
        realizedPnl: totalRealizedPnl.toFixed(2),
        unrealizedPnl: totalUnrealizedPnl.toFixed(2),
        totalPnl: totalRealizedPnl.add(totalUnrealizedPnl).toFixed(2),
      },
      positionCount: positions.length,
      positions,
    };
  }
  async getAssetAllocation(userId: string) {
    const portfolio = await this.getPortfolioSummary(userId);

    const totalAsset = new Prisma.Decimal(portfolio.balances.totalAsset);

    const cashBalance = new Prisma.Decimal(portfolio.balances.cashBalance);

    const percentage = (value: Prisma.Decimal) =>
      totalAsset.greaterThan(0)
        ? value.div(totalAsset).mul(100).toDecimalPlaces(2).toFixed(2)
        : '0.00';

    return {
      accountNumber: portfolio.accountNumber,
      currency: portfolio.currency,
      totalAsset: totalAsset.toFixed(2),
      allocation: [
        {
          type: 'CASH',
          label: 'Cash',
          value: cashBalance.toFixed(2),
          percentage: percentage(cashBalance),
        },
        ...portfolio.positions.map((position) => {
          const marketValue = new Prisma.Decimal(position.marketValue);

          return {
            type: 'POSITION',
            exchange: position.exchange,
            symbol: position.symbol,
            label: position.name,
            value: marketValue.toFixed(2),
            percentage: percentage(marketValue),
          };
        }),
      ],
    };
  }
  async getMyTransactions(userId: string, query: ListTransactionsQueryDto) {
    const account = await this.prisma.account.findUnique({
      where: { userId },
      select: {
        id: true,
        accountNumber: true,
        currency: true,
      },
    });

    if (!account) {
      throw new NotFoundException('Account not found');
    }

    if (
      query.dateFrom &&
      query.dateTo &&
      new Date(query.dateFrom) > new Date(query.dateTo)
    ) {
      throw new BadRequestException(
        'dateFrom must be earlier than or equal to dateTo',
      );
    }

    const where: Prisma.AccountTransactionWhereInput = {
      accountId: account.id,
      ...(query.type ? { type: query.type } : {}),
      ...(query.status ? { status: query.status } : {}),
      ...(query.dateFrom || query.dateTo
        ? {
            createdAt: {
              ...(query.dateFrom ? { gte: new Date(query.dateFrom) } : {}),
              ...(query.dateTo ? { lte: new Date(query.dateTo) } : {}),
            },
          }
        : {}),
    };

    const skip = (query.page - 1) * query.pageSize;

    const [total, transactions] = await this.prisma.$transaction([
      this.prisma.accountTransaction.count({
        where,
      }),
      this.prisma.accountTransaction.findMany({
        where,
        orderBy: {
          createdAt: 'desc',
        },
        skip,
        take: query.pageSize,
        select: {
          id: true,
          type: true,
          status: true,
          amount: true,
          balanceBefore: true,
          balanceAfter: true,
          referenceId: true,
          note: true,
          createdAt: true,
          updatedAt: true,
        },
      }),
    ]);

    return {
      accountNumber: account.accountNumber,
      currency: account.currency,
      filters: {
        type: query.type ?? null,
        status: query.status ?? null,
        dateFrom: query.dateFrom ?? null,
        dateTo: query.dateTo ?? null,
      },
      data: transactions.map((transaction) => ({
        ...transaction,
        amount: transaction.amount.toFixed(2),
        balanceBefore: transaction.balanceBefore.toFixed(2),
        balanceAfter: transaction.balanceAfter.toFixed(2),
      })),
      pagination: {
        page: query.page,
        pageSize: query.pageSize,
        total,
        totalPages: Math.ceil(total / query.pageSize),
      },
    };
  }
}
