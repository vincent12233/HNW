import {
  BadRequestException,
  ConflictException,
  Injectable,
  NotFoundException,
} from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Exchange, Prisma } from '../generated/prisma/client';
import { MatchingService } from '../matching/matching.service';
import { PrismaService } from '../prisma/prisma.service';
import { CreateOrderDto } from './dto/create-order.dto';
import { ListOrdersQueryDto } from './dto/list-orders-query.dto';
import { ListTradesQueryDto } from './dto/list-trades-query.dto';
import { ListPositionsQueryDto } from './dto/list-positions-query.dto';
type OrderWithDetails = Prisma.OrderGetPayload<{
  include: {
    instrument: true;
    trades: true;
  };
}>;

@Injectable()
export class OrdersService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly matchingService: MatchingService,
  ) {}

  async createOrder(userId: string, dto: CreateOrderDto) {
    this.validateOrderRequest(dto);

    let attempt = 0;

    while (attempt < 3) {
      attempt += 1;

      try {
        const result = await this.prisma.$transaction(
          async (tx) => {
            const account = await tx.account.findUnique({
              where: { userId },
            });

            if (!account) {
              throw new NotFoundException('Trading account not found');
            }

            if (!account.isSandbox) {
              throw new BadRequestException(
                'Only Trading Accounts are currently supported',
              );
            }

            const symbol = dto.symbol.trim().toUpperCase();
            const clientOrderId = dto.clientOrderId.trim();

            const existingOrder = await tx.order.findUnique({
              where: {
                accountId_clientOrderId: {
                  accountId: account.id,
                  clientOrderId,
                },
              },
              include: {
                instrument: true,
                trades: true,
              },
            });

            if (existingOrder) {
              this.assertSameOrderRequest(existingOrder, dto);

              return {
                idempotentReplay: true,
                order: existingOrder,
              };
            }

            const instrument = await tx.instrument.findUnique({
              where: {
                exchange_symbol: {
                  exchange: dto.exchange,
                  symbol,
                },
              },
              include: {
                quote: true,
              },
            });

            if (!instrument || !instrument.isActive) {
              throw new NotFoundException('Tradable instrument not found');
            }

            if (!instrument.quote) {
              throw new BadRequestException('Market quote is unavailable');
            }

            if (instrument.currency !== account.currency) {
              throw new BadRequestException(
                'Instrument and account currencies do not match',
              );
            }

            const limitPrice = dto.limitPrice
              ? new Prisma.Decimal(dto.limitPrice)
              : null;

            if (limitPrice && !limitPrice.mod(instrument.tickSize).equals(0)) {
              throw new BadRequestException(
                `limitPrice must follow tick size ${instrument.tickSize.toString()}`,
              );
            }

            const marketPrice =
              dto.side === 'BUY'
                ? (instrument.quote.askPrice ?? instrument.quote.lastPrice)
                : (instrument.quote.bidPrice ?? instrument.quote.lastPrice);

            const shouldExecute =
              dto.type === 'MARKET' ||
              (dto.side === 'BUY' &&
                limitPrice !== null &&
                limitPrice.greaterThanOrEqualTo(marketPrice)) ||
              (dto.side === 'SELL' &&
                limitPrice !== null &&
                limitPrice.lessThanOrEqualTo(marketPrice));

            const shouldExecuteImmediately =
              shouldExecute &&
              (dto.type === 'MARKET' || dto.timeInForce === 'DAY');

            if (shouldExecuteImmediately) {
              const order = await this.executeImmediately(
                tx,
                account,
                instrument,
                dto,
                clientOrderId,
                marketPrice,
              );

              return {
                idempotentReplay: false,
                order,
              };
            }

            if (!limitPrice) {
              throw new BadRequestException(
                'limitPrice is required for an open limit order',
              );
            }

            const order = await this.createOpenLimitOrder(
              tx,
              account,
              instrument,
              dto,
              clientOrderId,
              limitPrice,
            );

            return {
              idempotentReplay: false,
              order,
            };
          },
          {
            isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
          },
        );

        if (
          !result.idempotentReplay &&
          result.order.status === 'OPEN' &&
          result.order.timeInForce !== 'DAY'
        ) {
          const matchedOrder = await this.matchingService.matchOrder(
            result.order.id,
          );

          return {
            ...result,
            order: matchedOrder ?? result.order,
          };
        }

        return result;
      } catch (error: unknown) {
        if (this.hasPrismaCode(error, 'P2034') && attempt < 3) {
          continue;
        }

        if (this.hasPrismaCode(error, 'P2002')) {
          return this.getIdempotentOrder(userId, dto);
        }

        throw error;
      }
    }

    throw new ConflictException(
      'Concurrent order update detected; please retry',
    );
  }

  async cancelOrder(userId: string, orderId: string) {
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      try {
        return await this.prisma.$transaction(
          async (tx) => {
            const order = await tx.order.findFirst({
              where: {
                id: orderId,
                account: {
                  userId,
                },
              },
              include: {
                account: true,
                instrument: true,
                trades: true,
              },
            });

            if (!order) {
              throw new NotFoundException('Order not found');
            }

            if (
              order.status !== 'OPEN' &&
              order.status !== 'PARTIALLY_FILLED'
            ) {
              throw new BadRequestException(
                `Only active orders can be cancelled. Current status: ${order.status}`,
              );
            }

            const remainingQuantity = order.quantity - order.filledQuantity;

            if (remainingQuantity <= 0) {
              throw new BadRequestException(
                'Order has no remaining quantity to cancel',
              );
            }

            if (order.side === 'BUY') {
              const frozenAmount = order.frozenAmount;

              if (frozenAmount.lessThanOrEqualTo(0)) {
                throw new ConflictException(
                  'BUY order has no frozen amount to release',
                );
              }

              if (order.account.frozenBalance.lessThan(frozenAmount)) {
                throw new ConflictException(
                  'Account frozen balance is inconsistent with the order',
                );
              }

              await tx.account.update({
                where: {
                  id: order.accountId,
                },
                data: {
                  buyingPower: {
                    increment: frozenAmount,
                  },
                  frozenBalance: {
                    decrement: frozenAmount,
                  },
                },
              });

              await tx.accountTransaction.create({
                data: {
                  accountId: order.accountId,
                  type: 'ORDER_RELEASE',
                  status: 'COMPLETED',
                  amount: frozenAmount,
                  balanceBefore: order.account.cashBalance,
                  balanceAfter: order.account.cashBalance,
                  referenceId: `ORDER:${order.id}:RELEASE`,
                  note: 'Released funds after order cancellation',
                },
              });
            } else {
              const position = await tx.position.findUnique({
                where: {
                  accountId_instrumentId: {
                    accountId: order.accountId,
                    instrumentId: order.instrumentId,
                  },
                },
              });

              if (!position) {
                throw new ConflictException(
                  'Position for this SELL order no longer exists',
                );
              }

              if (position.frozenQuantity < remainingQuantity) {
                throw new ConflictException(
                  'Frozen position quantity is inconsistent with the order',
                );
              }

              await tx.position.update({
                where: {
                  id: position.id,
                },
                data: {
                  frozenQuantity: {
                    decrement: remainingQuantity,
                  },
                },
              });
            }

            const cancelledOrder = await tx.order.update({
              where: {
                id: order.id,
              },
              data: {
                status: 'CANCELLED',
                frozenAmount: new Prisma.Decimal(0),
                completedAt: new Date(),
                cancelledAt: new Date(),
              },
              include: {
                instrument: true,
                trades: true,
              },
            });

            return {
              cancelled: true,
              order: cancelledOrder,
            };
          },
          {
            isolationLevel: Prisma.TransactionIsolationLevel.Serializable,
          },
        );
      } catch (error: unknown) {
        if (this.hasPrismaCode(error, 'P2034') && attempt < 3) {
          continue;
        }

        throw error;
      }
    }

    throw new ConflictException(
      'Concurrent order update detected; please retry',
    );
  }

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
      ...(query.status
        ? {
            status: query.status,
          }
        : {}),
      ...(query.side
        ? {
            side: query.side,
          }
        : {}),
      ...(query.type
        ? {
            type: query.type,
          }
        : {}),
      ...(query.timeInForce
        ? {
            timeInForce: query.timeInForce,
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
      ...(query.dateFrom || query.dateTo
        ? {
            placedAt: {
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
      this.prisma.order.count({
        where,
      }),
      this.prisma.order.findMany({
        where,
        include: {
          instrument: true,
          trades: true,
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
        account: {
          userId,
        },
      },
      include: {
        instrument: true,
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
        where: {
          accountId: account.id,
        },
      }),
      this.prisma.trade.findMany({
        where: {
          accountId: account.id,
        },
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
                ? {
                    exchange: normalizedExchange as any,
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
        orderBy: {
          updatedAt: 'desc',
        },
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
        quantity: {
          gt: 0,
        },
        instrument: {
          exchange: normalizedExchange as any,
          symbol: normalizedSymbol,
        },
      },
      include: {
        instrument: {
          include: {
            quote: true,
          },
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
  private async executeImmediately(
    tx: Prisma.TransactionClient,
    account: Prisma.AccountGetPayload<object>,
    instrument: Prisma.InstrumentGetPayload<{
      include: { quote: true };
    }>,
    dto: CreateOrderDto,
    clientOrderId: string,
    fillPrice: Prisma.Decimal,
  ): Promise<OrderWithDetails> {
    const grossAmount = fillPrice.mul(dto.quantity).toDecimalPlaces(2);

    const fees = new Prisma.Decimal(0);
    const netAmount = grossAmount.add(fees);

    const existingPosition = await tx.position.findUnique({
      where: {
        accountId_instrumentId: {
          accountId: account.id,
          instrumentId: instrument.id,
        },
      },
    });

    if (dto.side === 'BUY') {
      if (
        account.buyingPower.lessThan(netAmount) ||
        account.cashBalance.lessThan(netAmount)
      ) {
        throw new BadRequestException('Insufficient buying power');
      }
    } else {
      const availableQuantity = existingPosition
        ? existingPosition.quantity - existingPosition.frozenQuantity
        : 0;

      if (availableQuantity < dto.quantity) {
        throw new BadRequestException('Insufficient available position');
      }
    }

    const order = await tx.order.create({
      data: {
        clientOrderId,
        accountId: account.id,
        instrumentId: instrument.id,
        side: dto.side,
        type: dto.type,
        timeInForce: dto.timeInForce,
        status: 'FILLED',
        quantity: dto.quantity,
        filledQuantity: dto.quantity,
        limitPrice:
          dto.type === 'LIMIT' ? new Prisma.Decimal(dto.limitPrice!) : null,
        averageFillPrice: fillPrice,
        frozenAmount: new Prisma.Decimal(0),
        completedAt: new Date(),
      },
    });

    const executionId = `SBX-${randomUUID()}`;

    await tx.trade.create({
      data: {
        executionId,
        orderId: order.id,
        accountId: account.id,
        instrumentId: instrument.id,
        quantity: dto.quantity,
        price: fillPrice,
        grossAmount,
        fees,
        netAmount,
      },
    });

    const balanceBefore = account.cashBalance;

    const updatedAccount = await tx.account.update({
      where: {
        id: account.id,
      },
      data:
        dto.side === 'BUY'
          ? {
              cashBalance: {
                decrement: netAmount,
              },
              buyingPower: {
                decrement: netAmount,
              },
            }
          : {
              cashBalance: {
                increment: netAmount,
              },
              buyingPower: {
                increment: netAmount,
              },
            },
    });

    await tx.accountTransaction.create({
      data: {
        accountId: account.id,
        type: 'TRADE_SETTLEMENT',
        status: 'COMPLETED',
        amount: dto.side === 'BUY' ? netAmount.negated() : netAmount,
        balanceBefore,
        balanceAfter: updatedAccount.cashBalance,
        referenceId: `ORDER:${order.id}:SETTLEMENT`,
        note: `${dto.side} ${dto.quantity} ${instrument.exchange}:${instrument.symbol} at ${fillPrice.toFixed(4)}`,
      },
    });

    if (dto.side === 'BUY') {
      const oldQuantity = existingPosition?.quantity ?? 0;

      const oldAveragePrice =
        existingPosition?.averagePrice ?? new Prisma.Decimal(0);

      const newQuantity = oldQuantity + dto.quantity;

      const newAveragePrice = oldAveragePrice
        .mul(oldQuantity)
        .add(fillPrice.mul(dto.quantity))
        .div(newQuantity)
        .toDecimalPlaces(4);

      await tx.position.upsert({
        where: {
          accountId_instrumentId: {
            accountId: account.id,
            instrumentId: instrument.id,
          },
        },
        create: {
          accountId: account.id,
          instrumentId: instrument.id,
          quantity: dto.quantity,
          frozenQuantity: 0,
          averagePrice: fillPrice,
          realizedPnl: new Prisma.Decimal(0),
        },
        update: {
          quantity: {
            increment: dto.quantity,
          },
          averagePrice: newAveragePrice,
        },
      });
    } else {
      const newQuantity = existingPosition!.quantity - dto.quantity;

      const realizedPnl = fillPrice
        .sub(existingPosition!.averagePrice)
        .mul(dto.quantity)
        .toDecimalPlaces(2);

      await tx.position.update({
        where: {
          id: existingPosition!.id,
        },
        data: {
          quantity: {
            decrement: dto.quantity,
          },
          averagePrice:
            newQuantity === 0
              ? new Prisma.Decimal(0)
              : existingPosition!.averagePrice,
          realizedPnl: {
            increment: realizedPnl,
          },
        },
      });
    }

    return tx.order.findUniqueOrThrow({
      where: {
        id: order.id,
      },
      include: {
        instrument: true,
        trades: true,
      },
    });
  }

  private async createOpenLimitOrder(
    tx: Prisma.TransactionClient,
    account: Prisma.AccountGetPayload<object>,
    instrument: Prisma.InstrumentGetPayload<{
      include: { quote: true };
    }>,
    dto: CreateOrderDto,
    clientOrderId: string,
    limitPrice: Prisma.Decimal,
  ): Promise<OrderWithDetails> {
    if (dto.side === 'BUY') {
      const frozenAmount = limitPrice.mul(dto.quantity).toDecimalPlaces(2);

      if (
        account.buyingPower.lessThan(frozenAmount) ||
        account.cashBalance.lessThan(frozenAmount)
      ) {
        throw new BadRequestException(
          'Insufficient buying power or cash balance',
        );
      }

      const order = await tx.order.create({
        data: {
          clientOrderId,
          accountId: account.id,
          instrumentId: instrument.id,
          side: dto.side,
          type: 'LIMIT',
          timeInForce: dto.timeInForce,
          status: 'OPEN',
          quantity: dto.quantity,
          limitPrice,
          frozenAmount,
        },
      });

      await tx.account.update({
        where: {
          id: account.id,
        },
        data: {
          buyingPower: {
            decrement: frozenAmount,
          },
          frozenBalance: {
            increment: frozenAmount,
          },
        },
      });

      await tx.accountTransaction.create({
        data: {
          accountId: account.id,
          type: 'ORDER_FREEZE',
          status: 'COMPLETED',
          amount: frozenAmount.negated(),
          balanceBefore: account.cashBalance,
          balanceAfter: account.cashBalance,
          referenceId: `ORDER:${order.id}:FREEZE`,
          note: `Funds reserved for BUY limit order ${instrument.exchange}:${instrument.symbol}`,
        },
      });

      return tx.order.findUniqueOrThrow({
        where: {
          id: order.id,
        },
        include: {
          instrument: true,
          trades: true,
        },
      });
    }

    const position = await tx.position.findUnique({
      where: {
        accountId_instrumentId: {
          accountId: account.id,
          instrumentId: instrument.id,
        },
      },
    });

    const availableQuantity = position
      ? position.quantity - position.frozenQuantity
      : 0;

    if (!position || availableQuantity < dto.quantity) {
      throw new BadRequestException('Insufficient available position');
    }

    const order = await tx.order.create({
      data: {
        clientOrderId,
        accountId: account.id,
        instrumentId: instrument.id,
        side: dto.side,
        type: 'LIMIT',
        timeInForce: dto.timeInForce,
        status: 'OPEN',
        quantity: dto.quantity,
        limitPrice,
        frozenAmount: new Prisma.Decimal(0),
      },
    });

    await tx.position.update({
      where: {
        id: position.id,
      },
      data: {
        frozenQuantity: {
          increment: dto.quantity,
        },
      },
    });

    return tx.order.findUniqueOrThrow({
      where: {
        id: order.id,
      },
      include: {
        instrument: true,
        trades: true,
      },
    });
  }

  private validateOrderRequest(dto: CreateOrderDto) {
    if (dto.type === 'LIMIT' && !dto.limitPrice) {
      throw new BadRequestException('limitPrice is required for LIMIT orders');
    }

    if (dto.type === 'MARKET' && dto.limitPrice !== undefined) {
      throw new BadRequestException(
        'limitPrice must not be supplied for MARKET orders',
      );
    }
  }

  private assertSameOrderRequest(
    existing: OrderWithDetails,
    dto: CreateOrderDto,
  ) {
    const incomingLimitPrice = dto.limitPrice
      ? new Prisma.Decimal(dto.limitPrice)
      : null;

    const sameLimitPrice =
      (existing.limitPrice === null && incomingLimitPrice === null) ||
      (existing.limitPrice !== null &&
        incomingLimitPrice !== null &&
        existing.limitPrice.equals(incomingLimitPrice));

    const matches =
      existing.instrument.exchange === dto.exchange &&
      existing.instrument.symbol === dto.symbol.trim().toUpperCase() &&
      existing.side === dto.side &&
      existing.type === dto.type &&
      existing.timeInForce === dto.timeInForce &&
      existing.quantity === dto.quantity &&
      sameLimitPrice;

    if (!matches) {
      throw new ConflictException(
        'clientOrderId is already used for a different order',
      );
    }
  }

  private async getIdempotentOrder(userId: string, dto: CreateOrderDto) {
    const existing = await this.prisma.order.findFirst({
      where: {
        clientOrderId: dto.clientOrderId.trim(),
        account: {
          userId,
        },
      },
      include: {
        instrument: true,
        trades: true,
      },
    });

    if (!existing) {
      throw new ConflictException('clientOrderId has already been processed');
    }

    this.assertSameOrderRequest(existing, dto);

    return {
      idempotentReplay: true,
      order: existing,
    };
  }

  private hasPrismaCode(error: unknown, expectedCode: string): boolean {
    return (
      typeof error === 'object' &&
      error !== null &&
      'code' in error &&
      (error as { code?: unknown }).code === expectedCode
    );
  }
}
