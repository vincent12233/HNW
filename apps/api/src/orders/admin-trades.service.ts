import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ListAdminTradesQueryDto } from './dto/list-admin-trades-query.dto';

@Injectable()
export class AdminTradesService {
  constructor(private readonly prisma: PrismaService) {}

  async listTrades(query: ListAdminTradesQueryDto) {
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
      ...(query.side
        ? {
            order: {
              side: query.side,
            },
          }
        : {}),
      ...(query.exchange || normalizedSymbol
        ? {
            instrument: {
              ...(query.exchange
                ? {
                    exchange: query.exchange,
                  }
                : {}),
              ...(normalizedSymbol
                ? {
                    symbol: normalizedSymbol,
                  }
                : {}),
            },
          }
        : {}),
      ...(search
        ? {
            OR: [
              {
                executionId: {
                  contains: search,
                  mode: 'insensitive',
                },
              },
              {
                order: {
                  clientOrderId: {
                    contains: search,
                    mode: 'insensitive',
                  },
                },
              },
              {
                account: {
                  accountNumber: {
                    contains: search,
                    mode: 'insensitive',
                  },
                },
              },
              {
                account: {
                  user: {
                    fullName: {
                      contains: search,
                      mode: 'insensitive',
                    },
                  },
                },
              },
            ],
          }
        : {}),
      ...(query.dateFrom || query.dateTo
        ? {
            executedAt: {
              ...(query.dateFrom
                ? {
                    gte: new Date(query.dateFrom),
                  }
                : {}),
              ...(query.dateTo
                ? {
                    lte: new Date(query.dateTo),
                  }
                : {}),
            },
          }
        : {}),
    };

    const skip = (query.page - 1) * query.pageSize;

    const [total, data] = await this.prisma.$transaction([
      this.prisma.trade.count({
        where,
      }),
      this.prisma.trade.findMany({
        where,
        include: {
          account: {
            select: {
              id: true,
              accountNumber: true,
              currency: true,
              isSandbox: true,
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
          instrument: true,
          order: {
            select: {
              id: true,
              clientOrderId: true,
              side: true,
              type: true,
              timeInForce: true,
              status: true,
              quantity: true,
              filledQuantity: true,
              limitPrice: true,
              averageFillPrice: true,
              placedAt: true,
              completedAt: true,
              cancelledAt: true,
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
      filters: {
        search: search ?? null,
        side: query.side ?? null,
        exchange: query.exchange ?? null,
        symbol: normalizedSymbol ?? null,
        dateFrom: query.dateFrom ?? null,
        dateTo: query.dateTo ?? null,
      },
      data,
    };
  }

  async getTrade(executionId: string) {
    const normalizedExecutionId = executionId.trim();

    const trade = await this.prisma.trade.findUnique({
      where: {
        executionId: normalizedExecutionId,
      },
      include: {
        account: {
          select: {
            id: true,
            accountNumber: true,
            currency: true,
            isSandbox: true,
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
        instrument: {
          include: {
            quote: true,
          },
        },
        order: true,
      },
    });

    if (!trade) {
      throw new NotFoundException('Trade not found');
    }

    return {
      ...trade,
      instrument: {
        ...trade.instrument,
        quote: trade.instrument.quote
          ? {
              ...trade.instrument.quote,
              volume: trade.instrument.quote.volume.toString(),
            }
          : null,
      },
    };
  }
}
