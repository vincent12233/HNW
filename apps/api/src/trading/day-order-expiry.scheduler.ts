import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron, CronExpression } from '@nestjs/schedule';
import { MarketSessionService } from '../market-session/market-session.service';
import { PrismaService } from '../prisma/prisma.service';
import { OrderCancellationService } from './order-cancellation.service';

@Injectable()
export class DayOrderExpiryScheduler {
  private readonly logger = new Logger(DayOrderExpiryScheduler.name);
  private readonly batchSize: number;
  private running = false;

  constructor(
    private readonly prisma: PrismaService,
    private readonly marketSession: MarketSessionService,
    private readonly cancellation: OrderCancellationService,
    config: ConfigService,
  ) {
    this.batchSize = this.positiveInteger(
      config.get<string>('DAY_ORDER_EXPIRY_BATCH_SIZE'),
      500,
    );
  }

  @Cron(CronExpression.EVERY_MINUTE, { name: 'day-order-expiry' })
  async expireDayOrders(): Promise<void> {
    if (this.running) return;
    this.running = true;

    try {
      const now = new Date();
      const orders = await this.prisma.order.findMany({
        where: {
          timeInForce: 'DAY',
          status: { in: ['OPEN', 'PARTIALLY_FILLED'] },
        },
        select: { id: true, placedAt: true },
        orderBy: [{ placedAt: 'asc' }, { id: 'asc' }],
        take: this.batchSize,
      });

      for (const order of orders) {
        if (!this.marketSession.isDayOrderExpired(order.placedAt, now)) {
          continue;
        }

        try {
          await this.cancellation.expireDayOrder(order.id);
        } catch (error: unknown) {
          const message =
            error instanceof Error ? error.message : String(error);
          this.logger.error(
            `Could not expire DAY order ${order.id}: ${message}`,
          );
        }
      }
    } finally {
      this.running = false;
    }
  }

  private positiveInteger(value: string | undefined, fallback: number): number {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
  }
}
