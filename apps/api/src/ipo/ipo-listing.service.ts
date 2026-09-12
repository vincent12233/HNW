import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { MarketDataProviderService } from '../market-data/providers/market-data-provider.service';
import { QuoteIngestionService } from '../market-data/quote-ingestion.service';
import { PrismaService } from '../prisma/prisma.service';

@Injectable()
export class IpoListingService {
  private readonly logger = new Logger(IpoListingService.name);
  constructor(
    private readonly prisma: PrismaService,
    private readonly provider: MarketDataProviderService,
    private readonly ingestion: QuoteIngestionService,
  ) {}

  @Cron('0 */15 * * * *')
  async syncMaturedIpos() {
    const candidates = await this.prisma.ipo.findMany({
      where: {
        status: { in: ['PUBLISHED', 'OPEN'] },
        closeDate: { lt: new Date() },
        instrumentId: { not: null },
      },
      take: 100,
    });
    for (const ipo of candidates) {
      if (!ipo.instrumentId) continue;
      try {
        const quote = await this.provider.getQuote(ipo.symbol, ipo.exchange);
        await this.ingestion.ingest(ipo.exchange, quote, 'STOCK');
        await this.prisma.ipo.update({
          where: { id: ipo.id },
          data: { status: 'LISTED' },
        });
        this.logger.log(`IPO ${ipo.exchange}:${ipo.symbol} marked LISTED`);
      } catch (error: unknown) {
        this.logger.warn(
          `IPO listing check failed for ${ipo.symbol}: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    }
  }
}
