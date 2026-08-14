import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MarketSessionService } from '../market-session/market-session.service';
import { PrismaService } from '../prisma/prisma.service';
import { MatchingService } from './matching.service';

@Injectable()
export class MatchingScanService {
  private readonly logger = new Logger(MatchingScanService.name);
  private readonly batchSize: number;
  private readonly maxBatchesPerScan: number;
  private resumePlacedAt: Date | null = null;
  private resumeId: string | null = null;

  constructor(
    private readonly prisma: PrismaService,
    private readonly matchingService: MatchingService,
    private readonly marketSession: MarketSessionService,
    config: ConfigService,
  ) {
    this.batchSize = this.positiveInteger(
      config.get('MATCHING_BATCH_SIZE'),
      100,
    );
    this.maxBatchesPerScan = this.positiveInteger(
      config.get('MATCHING_MAX_SCAN_BATCHES'),
      10,
    );
  }

  async scanOpenOrders(): Promise<void> {
    if (!this.marketSession.isNormalMarketOpen()) {
      return;
    }

    let batches = 0;

    while (batches < this.maxBatchesPerScan) {
      const orders = await this.findNextBatch();

      if (orders.length === 0) {
        this.resetCursor();
        return;
      }

      for (const order of orders) {
        try {
          await this.matchingService.matchOrder(order.id);
        } catch (error: unknown) {
          const message = error instanceof Error ? error.message : String(error);
          this.logger.error(`Could not match order ${order.id}: ${message}`);
        }
      }

      const last = orders[orders.length - 1];
      this.resumePlacedAt = last.placedAt;
      this.resumeId = last.id;
      batches += 1;

      if (orders.length < this.batchSize) {
        this.resetCursor();
        return;
      }
    }
  }

  private findNextBatch() {
    const afterCursor =
      this.resumePlacedAt && this.resumeId
        ? {
            OR: [
              { placedAt: { gt: this.resumePlacedAt } },
              {
                placedAt: this.resumePlacedAt,
                id: { gt: this.resumeId },
              },
            ],
          }
        : {};

    return this.prisma.order.findMany({
      where: {
        status: { in: ['OPEN', 'PARTIALLY_FILLED'] },
        ...afterCursor,
      },
      select: { id: true, placedAt: true },
      orderBy: [{ placedAt: 'asc' }, { id: 'asc' }],
      take: this.batchSize,
    });
  }

  private resetCursor() {
    this.resumePlacedAt = null;
    this.resumeId = null;
  }

  private positiveInteger(value: string | undefined, fallback: number): number {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
  }
}
