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
    await this.promoteMaturedIpos();
    await this.refreshListedQuotes();
  }

  private async promoteMaturedIpos() {
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
        await this.prisma.instrument.update({
          where: { id: ipo.instrumentId },
          data: { category: 'IPO', isActive: true },
        });
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

  /** Keep live quotes flowing for already-listed IPO instruments. */
  private async refreshListedQuotes() {
    const listed = await this.prisma.ipo.findMany({
      where: { status: 'LISTED', instrumentId: { not: null } },
      take: 100,
      orderBy: { updatedAt: 'asc' },
    });
    for (const ipo of listed) {
      try {
        const quote = await this.provider.getQuote(ipo.symbol, ipo.exchange);
        await this.ingestion.ingest(ipo.exchange, quote, 'STOCK');
      } catch (error: unknown) {
        this.logger.warn(
          `Listed IPO quote refresh failed for ${ipo.symbol}: ${error instanceof Error ? error.message : String(error)}`,
        );
      }
    }
  }
}
