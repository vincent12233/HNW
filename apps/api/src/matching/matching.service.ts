import { ConflictException, Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { randomUUID } from 'crypto';
import { Prisma } from '../generated/prisma/client';
import { PrismaService } from '../prisma/prisma.service';

type MatchableOrder = Prisma.OrderGetPayload<{
  include: { account: true; instrument: { include: { quote: true } } };
}>;

@Injectable()
export class MatchingService {
  private readonly logger = new Logger(MatchingService.name);
  private readonly batchSize: number;
  private readonly maxFillQuantity: number;
  private readonly quoteMaxAgeMs: number;

  constructor(
    private readonly prisma: PrismaService,
    config: ConfigService,
  ) {
    this.batchSize = this.positiveInteger(config.get('MATCHING_BATCH_SIZE'), 100);
    this.maxFillQuantity = this.positiveInteger(
      config.get('MATCHING_MAX_FILL_QUANTITY'),
      1000,
    );
    this.quoteMaxAgeMs = this.positiveInteger(
      config.get('ORDER_QUOTE_MAX_AGE_MS'),
      120000,
    );
  }

  async scanOpenOrders(): Promise<void> {
    const orders = await this.prisma.order.findMany({
      where: { status: { in: ['OPEN', 'PARTIALLY_FILLED'] } },
      select: { id: true },
      orderBy: [{ placedAt: 'asc' }, { id: 'asc' }],
      take: this.batchSize,
    });
    for (const order of orders) {
      try {
        await this.matchOrder(order.id);
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        this.logger.error(`Could not match order ${order.id}: ${message}`);
      }
    }
  }

  async matchOrder(orderId: string) {
    for (let attempt = 1; attempt <= 3; attempt += 1) {
      try {
        return await this.prisma.$transaction(
          async (tx) => {
            const order = await tx.order.findUnique({
              where: { id: orderId },
              include: {
                account: true,
                instrument: { include: { quote: true } },
              },
            });
            if (!order || !['OPEN', 'PARTIALLY_FILLED'].includes(order.status)) {
              return order;
            }
            const remaining = order.quantity - order.filledQuantity;
            if (remaining <= 0) return order;

            const quote = order.instrument.quote;
            if (!quote || !this.isQuoteFresh(quote.asOf)) {
              if (order.timeInForce !== 'DAY') {
                await this.cancelRemainder(tx, order);
              }
              return tx.order.findUnique({ where: { id: order.id } });
            }

            const price =
              order.side === 'BUY'
                ? (quote.askPrice ?? quote.lastPrice)
                : (quote.bidPrice ?? quote.lastPrice);
            const marketable =
              order.type === 'MARKET' ||
              (order.side === 'BUY' && order.limitPrice?.gte(price)) ||
              (order.side === 'SELL' && order.limitPrice?.lte(price));

            if (!marketable) {
              if (order.timeInForce !== 'DAY') {
                await this.cancelRemainder(tx, order);
              }
              return tx.order.findUnique({ where: { id: order.id } });
            }
            if (order.timeInForce === 'FOK' && remaining > this.maxFillQuantity) {
              await this.cancelRemainder(tx, order);
              return tx.order.findUnique({ where: { id: order.id } });
            }

            const fillQuantity =
              order.timeInForce === 'FOK'
                ? remaining
                : Math.min(remaining, this.maxFillQuantity);
            await this.settleFill(tx, order, fillQuantity, price);

            if (remaining > fillQuantity && order.timeInForce === 'IOC') {
              const updated = await tx.order.findUniqueOrThrow({
                where: { id: order.id },
                include: {
                  account: true,
                  instrument: { include: { quote: true } },
                },
              });
              await this.cancelRemainder(tx, updated);
            }
            return tx.order.findUnique({
              where: { id: order.id },
              include: { instrument: true, trades: true },
            });
          },
          { isolationLevel: Prisma.TransactionIsolationLevel.Serializable },
        );
      } catch (error: unknown) {
        if (this.hasPrismaCode(error, 'P2034')) {
          if (attempt < 3) continue;
          throw new ConflictException(
            'Concurrent order update detected; please retry',
          );
        }
        throw error;
      }
    }

    throw new ConflictException(
      'Concurrent order update detected; please retry',
    );
  }

  private async settleFill(
    tx: Prisma.TransactionClient,
    order: MatchableOrder,
    quantity: number,
    price: Prisma.Decimal,
  ): Promise<void> {
    const grossAmount = price.mul(quantity).toDecimalPlaces(2);
    const fees = new Prisma.Decimal(0);
    const netAmount = grossAmount.add(fees);
    const executionId = `INT-${randomUUID()}`;
    const newFilledQuantity = order.filledQuantity + quantity;
    const averageFillPrice = (order.averageFillPrice ?? new Prisma.Decimal(0))
      .mul(order.filledQuantity)
      .add(price.mul(quantity))
      .div(newFilledQuantity)
      .toDecimalPlaces(4);
    const complete = newFilledQuantity === order.quantity;
    let frozenAmountAfter = order.frozenAmount;

    if (order.side === 'BUY') {
      let frozenRelease = Prisma.Decimal.min(
        order.frozenAmount,
        (order.limitPrice ?? price).mul(quantity).toDecimalPlaces(2),
      );
      frozenAmountAfter = order.frozenAmount.sub(frozenRelease);
      if (complete && frozenAmountAfter.gt(0)) {
        frozenRelease = frozenRelease.add(frozenAmountAfter);
        frozenAmountAfter = new Prisma.Decimal(0);
      }

      const currentAccount = await tx.account.findUniqueOrThrow({
        where: { id: order.accountId },
      });
      if (currentAccount.frozenBalance.lessThan(frozenRelease)) {
        throw new ConflictException(
          'Account frozen balance is inconsistent with the order',
        );
      }
      if (currentAccount.cashBalance.lessThan(netAmount)) {
        throw new ConflictException('Insufficient cash balance during settlement');
      }

      const updatedAccount = await tx.account.update({
        where: { id: order.accountId },
        data: {
          cashBalance: { decrement: netAmount },
          frozenBalance: { decrement: frozenRelease },
          buyingPower: { increment: frozenRelease.sub(netAmount) },
        },
      });
      await this.createSettlement(
        tx,
        order,
        executionId,
        quantity,
        price,
        netAmount.negated(),
        currentAccount.cashBalance,
        updatedAccount.cashBalance,
      );

      const position = await tx.position.findUnique({
        where: {
          accountId_instrumentId: {
            accountId: order.accountId,
            instrumentId: order.instrumentId,
          },
        },
      });
      const oldQuantity = position?.quantity ?? 0;
      const newAveragePrice = (position?.averagePrice ?? new Prisma.Decimal(0))
        .mul(oldQuantity)
        .add(price.mul(quantity))
        .div(oldQuantity + quantity)
        .toDecimalPlaces(4);
      await tx.position.upsert({
        where: {
          accountId_instrumentId: {
            accountId: order.accountId,
            instrumentId: order.instrumentId,
          },
        },
        create: {
          accountId: order.accountId,
          instrumentId: order.instrumentId,
          quantity,
          averagePrice: price,
        },
        update: {
          quantity: { increment: quantity },
          averagePrice: newAveragePrice,
        },
      });
    } else {
      const position = await tx.position.findUniqueOrThrow({
        where: {
          accountId_instrumentId: {
            accountId: order.accountId,
            instrumentId: order.instrumentId,
          },
        },
      });
      if (position.quantity < quantity || position.frozenQuantity < quantity) {
        throw new ConflictException(
          'Position quantity is inconsistent with the SELL order',
        );
      }
      const newQuantity = position.quantity - quantity;
      const realizedPnl = price
        .sub(position.averagePrice)
        .mul(quantity)
        .toDecimalPlaces(2);
      const currentAccount = await tx.account.findUniqueOrThrow({
        where: { id: order.accountId },
      });
      const updatedAccount = await tx.account.update({
        where: { id: order.accountId },
        data: {
          cashBalance: { increment: netAmount },
          buyingPower: { increment: netAmount },
        },
      });
      await tx.position.update({
        where: { id: position.id },
        data: {
          quantity: { decrement: quantity },
          frozenQuantity: { decrement: quantity },
          averagePrice:
            newQuantity === 0 ? new Prisma.Decimal(0) : position.averagePrice,
          realizedPnl: { increment: realizedPnl },
        },
      });
      await this.createSettlement(
        tx,
        order,
        executionId,
        quantity,
        price,
        netAmount,
        currentAccount.cashBalance,
        updatedAccount.cashBalance,
      );
    }

    await tx.trade.create({
      data: {
        executionId,
        orderId: order.id,
        accountId: order.accountId,
        instrumentId: order.instrumentId,
        quantity,
        price,
        grossAmount,
        fees,
        netAmount,
      },
    });
    await tx.order.update({
      where: { id: order.id },
      data: {
        status: complete ? 'FILLED' : 'PARTIALLY_FILLED',
        filledQuantity: newFilledQuantity,
        averageFillPrice,
        frozenAmount: frozenAmountAfter,
        completedAt: complete ? new Date() : null,
      },
    });
  }

  private async createSettlement(
    tx: Prisma.TransactionClient,
    order: MatchableOrder,
    executionId: string,
    quantity: number,
    price: Prisma.Decimal,
    amount: Prisma.Decimal,
    balanceBefore: Prisma.Decimal,
    balanceAfter: Prisma.Decimal,
  ): Promise<void> {
    await tx.accountTransaction.create({
      data: {
        accountId: order.accountId,
        type: 'TRADE_SETTLEMENT',
        status: 'COMPLETED',
        amount,
        balanceBefore,
        balanceAfter,
        referenceId: `EXECUTION:${executionId}:SETTLEMENT`,
        note: `${order.side} ${quantity} ${order.instrument.exchange}:${order.instrument.symbol} at ${price.toFixed(4)}`,
      },
    });
  }

  private async cancelRemainder(
    tx: Prisma.TransactionClient,
    order: MatchableOrder,
  ): Promise<void> {
    const remaining = order.quantity - order.filledQuantity;
    if (order.side === 'BUY' && order.frozenAmount.gt(0)) {
      const account = await tx.account.findUniqueOrThrow({
        where: { id: order.accountId },
      });
      if (account.frozenBalance.lessThan(order.frozenAmount)) {
        throw new ConflictException(
          'Account frozen balance is inconsistent with the order',
        );
      }
      await tx.account.update({
        where: { id: order.accountId },
        data: {
          buyingPower: { increment: order.frozenAmount },
          frozenBalance: { decrement: order.frozenAmount },
        },
      });
      await tx.accountTransaction.create({
        data: {
          accountId: order.accountId,
          type: 'ORDER_RELEASE',
          status: 'COMPLETED',
          amount: order.frozenAmount,
          balanceBefore: account.cashBalance,
          balanceAfter: account.cashBalance,
          referenceId: `ORDER:${order.id}:RELEASE`,
          note: 'Released funds for unfilled order quantity',
        },
      });
    } else if (order.side === 'SELL' && remaining > 0) {
      const position = await tx.position.findUniqueOrThrow({
        where: {
          accountId_instrumentId: {
            accountId: order.accountId,
            instrumentId: order.instrumentId,
          },
        },
      });
      if (position.frozenQuantity < remaining) {
        throw new ConflictException(
          'Frozen position quantity is inconsistent with the order',
        );
      }
      await tx.position.update({
        where: { id: position.id },
        data: { frozenQuantity: { decrement: remaining } },
      });
    }
    await tx.order.update({
      where: { id: order.id },
      data: {
        status: 'CANCELLED',
        frozenAmount: new Prisma.Decimal(0),
        cancelledAt: new Date(),
        completedAt: new Date(),
      },
    });
  }

  private isQuoteFresh(asOf: Date | null | undefined): boolean {
    if (!asOf) return false;
    const ageMs = Date.now() - asOf.getTime();
    return ageMs >= 0 && ageMs <= this.quoteMaxAgeMs;
  }

  private positiveInteger(value: string | undefined, fallback: number): number {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
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
