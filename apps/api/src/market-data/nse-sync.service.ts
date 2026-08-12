import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '../prisma/prisma.service';
import { MarketDataHealthService } from './market-data-health.service';
import { MarketDataProviderService } from './providers/market-data-provider.service';
import { QuoteIngestionService } from './quote-ingestion.service';

@Injectable()
export class NseSyncService {
  private readonly logger = new Logger(NseSyncService.name);
  private readonly indices = ['NIFTY50', 'SENSEX', 'BANKNIFTY'];
  private syncing = false;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
    private readonly provider: MarketDataProviderService,
    private readonly ingestion: QuoteIngestionService,
    private readonly health: MarketDataHealthService,
  ) {}

  @Cron('*/30 * * * * *')
  async sync() {
    if (this.syncing) {
      this.logger.debug('Market polling cycle still running; skipping overlap');
      return;
    }
    if (this.streamingEnabled() && !this.health.getStatus().stale) {
      return;
    }

    this.syncing = true;
    try {
      this.logger.log(
        `Updating market quotes via polling fallback ${this.provider.providerName}...`,
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
      select: { symbol: true, exchange: true },
      orderBy: [{ displayOrder: 'asc' }, { symbol: 'asc' }],
    });

    for (const instrument of instruments) {
      try {
        const quote = await this.provider.getQuote(
          instrument.symbol,
          instrument.exchange,
        );
        await this.ingestion.ingest(instrument.exchange, quote, 'STOCK');
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        this.logger.error(
          `${instrument.exchange}:${instrument.symbol} update failed: ${message}`,
        );
      }
    }
  }

  private async syncIndices() {
    for (const symbol of this.indices) {
      try {
        const quote = await this.provider.getQuote(symbol, 'NSE');
        await this.ingestion.ingest('NSE', quote, 'INDEX');
      } catch (error: unknown) {
        const message = error instanceof Error ? error.message : String(error);
        this.logger.error(`${symbol} index update failed: ${message}`);
      }
    }
  }

  private streamingEnabled() {
    return (
      (this.config.get<string>('MARKET_DATA_STREAMING_ENABLED') ?? 'false')
        .trim()
        .toLowerCase() === 'true'
    );
  }
}
