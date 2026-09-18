import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron } from '@nestjs/schedule';
import { OrderStatus } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { MarketDataProviderService } from './providers/market-data-provider.service';
import { QuoteIngestionService } from './quote-ingestion.service';

type PollingCandidate = {
  symbol: string;
  exchange: string;
  category: string | null;
  quote: { asOf: Date } | null;
  positions: { id: string }[];
  orders: { id: string }[];
};

const PRIORITY_CATEGORIES = new Set(['INSTITUTIONAL', 'INST', 'OTC', 'IPO']);

@Injectable()
export class NseSyncService {
  private readonly logger = new Logger(NseSyncService.name);
  private readonly indices = ['NIFTY50', 'SENSEX', 'BANKNIFTY'];
  private readonly lastPollingAttempt = new Map<string, number>();
  private syncing = false;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly provider: MarketDataProviderService,
    private readonly ingestion: QuoteIngestionService,
  ) {}

  // Temporary development provider is a snapshot endpoint, so poll frequently
  // and relay each accepted update over the existing authenticated WebSocket.
  @Cron('*/10 * * * * *')
  async sync() {
    if (this.syncing) {
      this.logger.debug('Market polling cycle still running; skipping overlap');
      return;
    }

    this.syncing = true;
    try {
      this.logger.log(
        `Updating market quotes via ${this.provider.providerName}...`,
      );
      await this.syncStocks();
      await this.syncIndices();
    } finally {
      this.syncing = false;
    }
  }

  private async syncStocks() {
    const instruments = await this.prisma.instrument.findMany({
      where: {
        isActive: true,
        exchange: { in: ['NSE', 'BSE'] },
      },
      select: {
        symbol: true,
        exchange: true,
        category: true,
        quote: { select: { asOf: true } },
        positions: {
          where: { quantity: { not: 0 } },
          select: { id: true },
          take: 1,
        },
        orders: {
          where: {
            status: {
              in: [
                OrderStatus.PENDING,
                OrderStatus.OPEN,
                OrderStatus.PARTIALLY_FILLED,
              ],
            },
          },
          select: { id: true },
          take: 1,
        },
      },
    });

    const batchSize = this.pollBatchSize();
    const batch = this.selectPollingBatch(instruments, batchSize);
    const priorityCount = batch.filter((instrument) =>
      this.isPriority(instrument),
    ).length;

    if (instruments.length > batch.length) {
      this.logger.debug(
        `Polling ${batch.length}/${instruments.length} active stocks this cycle ` +
          `(${priorityCount} priority; batch size ${batchSize})`,
      );
    }

    // Bound concurrency to avoid overwhelming the public snapshot provider.
    for (let offset = 0; offset < batch.length; offset += 8) {
      const group = batch.slice(offset, offset + 8);
      await Promise.allSettled(
        group.map(async (instrument) => {
          const key = this.pollingKey(instrument.exchange, instrument.symbol);
          this.lastPollingAttempt.set(key, Date.now());
          try {
            const quote = await this.provider.getQuote(
              instrument.symbol,
              instrument.exchange,
            );
            await this.ingestion.ingest(instrument.exchange, quote, 'STOCK');
          } catch (error: unknown) {
            const message =
              error instanceof Error ? error.message : String(error);
            this.logger.error(
              `${instrument.exchange}:${instrument.symbol} update failed: ${message}`,
            );
          }
        }),
      );
    }
  }

  selectPollingBatch(
    instruments: PollingCandidate[],
    batchSize = this.pollBatchSize(),
  ): PollingCandidate[] {
    if (batchSize <= 0 || instruments.length === 0) return [];

    return [...instruments]
      .sort((left, right) => {
        const priorityDifference =
          Number(this.isPriority(right)) - Number(this.isPriority(left));
        if (priorityDifference !== 0) return priorityDifference;

        const pollingDifference =
          this.lastPolledAt(left) - this.lastPolledAt(right);
        if (pollingDifference !== 0) return pollingDifference;

        const exchangeDifference = left.exchange.localeCompare(right.exchange);
        if (exchangeDifference !== 0) return exchangeDifference;
        return left.symbol.localeCompare(right.symbol);
      })
      .slice(0, batchSize);
  }

  private lastPolledAt(instrument: PollingCandidate) {
    const attemptedAt = this.lastPollingAttempt.get(
      this.pollingKey(instrument.exchange, instrument.symbol),
    );
    if (attemptedAt !== undefined) return attemptedAt;
    return instrument.quote?.asOf.getTime() ?? 0;
  }

  private isPriority(instrument: PollingCandidate) {
    const category = (instrument.category ?? '').trim().toUpperCase();
    return (
      instrument.positions.length > 0 ||
      instrument.orders.length > 0 ||
      PRIORITY_CATEGORIES.has(category)
    );
  }

  private pollingKey(exchange: string, symbol: string) {
    return `${exchange}:${symbol}`;
  }

  private pollBatchSize() {
    return this.positiveInteger(
      this.config.get<string>('MARKET_DATA_POLL_BATCH_SIZE'),
      24,
    );
  }

  private async syncIndices() {
    await Promise.allSettled(
      this.indices.map(async (symbol) => {
        try {
          const quote = await this.provider.getQuote(symbol, 'NSE');
          await this.ingestion.ingest('NSE', quote, 'INDEX');
        } catch (error: unknown) {
          const message =
            error instanceof Error ? error.message : String(error);
          this.logger.error(`${symbol} index update failed: ${message}`);
        }
      }),
    );
  }

  private positiveInteger(value: string | undefined, fallback: number) {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
  }
}
