import { BadRequestException, NotFoundException } from '@nestjs/common';

import { Prisma } from '../generated/prisma/client';
import { UserRole } from '../generated/prisma/enums';
import { ListAdminOrdersQueryDto } from '../orders/dto/list-admin-orders-query.dto';
import { ListAdminTradesQueryDto } from '../orders/dto/list-admin-trades-query.dto';
import { PrismaService } from '../prisma/prisma.service';

export class BusinessTradingService {
  constructor(private readonly prisma: PrismaService) {}

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
    type TradePairRow = {
      id: string;
      status: string;
      quantity: number;
      customer: (typeof trades)[number]['account']['user'];
      accountNumber: string;
      instrument: (typeof trades)[number]['instrument'];
      buyExecutionId: string;
      buyTime: Date;
      buyPrice: number;
      buyFee: number;
      sellExecutionId: string | null;
      sellTime: Date | null;
      sellPrice: number | null;
      sellFee: number | null;
      holdingSeconds: number | null;
      realizedPnl: number | null;
    };
    const rows: TradePairRow[] = [];
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
}
