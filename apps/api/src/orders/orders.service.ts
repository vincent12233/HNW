import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ListOrdersQueryDto } from './dto/list-orders-query.dto';
import { ListPositionsQueryDto } from './dto/list-positions-query.dto';
import { ListTradesQueryDto } from './dto/list-trades-query.dto';

@Injectable()
export class OrdersService {
  constructor(private readonly prisma: PrismaService) {}

  async listOrders(userId: string, query: ListOrdersQueryDto) {
    const account = await this.prisma.account.findUnique({
      where: { userId },
      select: { id: true },
    });

    if (!account) {
      throw new NotFoundException('Trading account not found');
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

    const normalizedSymbol = query.symbol?.trim().toUpperCase();

    const where: Prisma.OrderWhereInput = {
      accountId: account.id,
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
          instrument: true,
          trades: true,
        },
        orderBy: { placedAt: 'desc' },
        skip,
        take: query.pageSize,
      }),
    ]);

    return {
      page: query.page,
      pageSize: query.pageSize,
      total,
      totalPages: Math.ceil(total / query.pageSize),
      filters: {
        status: query.status ?? null,
        side: query.side ?? null,
        type: query.type ?? null,
        timeInForce: query.timeInForce ?? null,
        exchange: query.exchange ?? null,
        symbol: normalizedSymbol ?? null,
        dateFrom: query.dateFrom ?? null,
        dateTo: query.dateTo ?? null,
      },
      data,
    };
  }

  async getOrder(userId: string, orderId: string) {
    const order = await this.prisma.order.findFirst({
      where: {
        id: orderId,
        account: { userId },
      },
      include: {
        instrument: true,
        trades: {
          orderBy: { executedAt: 'asc' },
        },
      },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    return order;
  }

  async listTrades(userId: string, query: ListTradesQueryDto) {
    const account = await this.prisma.account.findUnique({
      where: { userId },
      select: { id: true },
    });

    if (!account) {
      throw new NotFoundException('Trading account not found');
    }

    const skip = (query.page - 1) * query.pageSize;

    const [total, data] = await this.prisma.$transaction([
      this.prisma.trade.count({
        where: { accountId: account.id },
      }),
      this.prisma.trade.findMany({
        where: { accountId: account.id },
        include: {
          instrument: true,
          order: {
            select: {
              id: true,
              clientOrderId: true,
              side: true,
              type: true,
              timeInForce: true,
              status: true,
            },
          },
        },
        orderBy: { executedAt: 'desc' },
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

  async listPositions(userId: string, query: ListPositionsQueryDto) {
    const account = await this.prisma.account.findUnique({
      where: { userId },
      select: { id: true },
    });

    if (!account) {
      throw new NotFoundException('Trading account not found');
    }

    const normalizedExchange = query.exchange?.trim().toUpperCase();
    const normalizedSymbol = query.symbol?.trim().toUpperCase();

    const where: Prisma.PositionWhereInput = {
      accountId: account.id,
      quantity: { gt: 0 },
      ...(normalizedExchange || normalizedSymbol
        ? {
            instrument: {
              ...(normalizedExchange
                ? { exchange: normalizedExchange as any }
                : {}),
              ...(normalizedSymbol ? { symbol: normalizedSymbol } : {}),
            },
          }
        : {}),
    };

    const skip = (query.page - 1) * query.pageSize;

    const [total, positions] = await this.prisma.$transaction([
      this.prisma.position.count({ where }),
      this.prisma.position.findMany({
        where,
        include: {
          instrument: {
            include: {
              quote: {
                select: {
                  lastPrice: true,
                  asOf: true,
                  source: true,
                },
              },
            },
          },
        },
        orderBy: { updatedAt: 'desc' },
        skip,
        take: query.pageSize,
      }),
    ]);

    const data = positions.map((position) => {
      const availableQuantity = position.quantity - position.frozenQuantity;
      const lastPrice = position.instrument.quote?.lastPrice ?? null;
      const marketValue = lastPrice
        ? lastPrice.mul(position.quantity).toDecimalPlaces(2)
        : null;
      const unrealizedPnl = lastPrice
        ? lastPrice
            .sub(position.averagePrice)
            .mul(position.quantity)
            .toDecimalPlaces(2)
        : null;

      return {
        id: position.id,
        instrument: {
          id: position.instrument.id,
          exchange: position.instrument.exchange,
          symbol: position.instrument.symbol,
          name: position.instrument.name,
          currency: position.instrument.currency,
        },
        quantity: position.quantity,
        frozenQuantity: position.frozenQuantity,
        availableQuantity,
        averagePrice: position.averagePrice.toFixed(4),
        realizedPnl: position.realizedPnl.toFixed(2),
        lastPrice: lastPrice?.toFixed(4) ?? null,
        marketValue: marketValue?.toFixed(2) ?? null,
        unrealizedPnl: unrealizedPnl?.toFixed(2) ?? null,
        quoteSource: position.instrument.quote?.source ?? null,
        quoteAsOf: position.instrument.quote?.asOf ?? null,
        updatedAt: position.updatedAt,
      };
    });

    return {
      page: query.page,
      pageSize: query.pageSize,
      total,
      totalPages: Math.ceil(total / query.pageSize),
      filters: {
        exchange: normalizedExchange ?? null,
        symbol: normalizedSymbol ?? null,
      },
      data,
    };
  }

  async getPosition(userId: string, exchange: string, symbol: string) {
    const account = await this.prisma.account.findUnique({
      where: { userId },
      select: { id: true },
    });

    if (!account) {
      throw new NotFoundException('Trading account not found');
    }

    const normalizedExchange = exchange.trim().toUpperCase();
    const normalizedSymbol = symbol.trim().toUpperCase();

    const position = await this.prisma.position.findFirst({
      where: {
        accountId: account.id,
        quantity: { gt: 0 },
        instrument: {
          exchange: normalizedExchange as any,
          symbol: normalizedSymbol,
        },
      },
      include: {
        instrument: {
          include: { quote: true },
        },
      },
    });

    if (!position) {
      throw new NotFoundException('Position not found');
    }

    const availableQuantity = position.quantity - position.frozenQuantity;
    const lastPrice = position.instrument.quote?.lastPrice ?? null;
    const marketValue = lastPrice
      ? lastPrice.mul(position.quantity).toDecimalPlaces(2)
      : null;
    const unrealizedPnl = lastPrice
      ? lastPrice
          .sub(position.averagePrice)
          .mul(position.quantity)
          .toDecimalPlaces(2)
      : null;

    return {
      id: position.id,
      instrument: {
        id: position.instrument.id,
        exchange: position.instrument.exchange,
        symbol: position.instrument.symbol,
        name: position.instrument.name,
        currency: position.instrument.currency,
      },
      quantity: position.quantity,
      frozenQuantity: position.frozenQuantity,
      availableQuantity,
      averagePrice: position.averagePrice.toFixed(4),
      realizedPnl: position.realizedPnl.toFixed(2),
      lastPrice: lastPrice?.toFixed(4) ?? null,
      marketValue: marketValue?.toFixed(2) ?? null,
      unrealizedPnl: unrealizedPnl?.toFixed(2) ?? null,
      quoteSource: position.instrument.quote?.source ?? null,
      quoteAsOf: position.instrument.quote?.asOf ?? null,
      updatedAt: position.updatedAt,
    };
  }
}
