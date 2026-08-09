import {
  BadRequestException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';
import { ListAdminOrdersQueryDto } from './dto/list-admin-orders-query.dto';

@Injectable()
export class AdminOrdersService {
  constructor(private readonly prisma: PrismaService) {}

  async listOrders(query: ListAdminOrdersQueryDto) {
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
              {
                clientOrderId: {
                  contains: search,
                  mode: 'insensitive',
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
      filters: {
        search: search ?? null,
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

  async getOrder(orderId: string) {
    const order = await this.prisma.order.findUnique({
      where: {
        id: orderId,
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
        trades: {
          orderBy: {
            executedAt: 'asc',
          },
        },
      },
    });

    if (!order) {
      throw new NotFoundException('Order not found');
    }

    return {
      ...order,
      instrument: {
        ...order.instrument,
        quote: order.instrument.quote
          ? {
              ...order.instrument.quote,
              volume: order.instrument.quote.volume.toString(),
            }
          : null,
      },
    };
  }
}
