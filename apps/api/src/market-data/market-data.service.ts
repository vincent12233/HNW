import { Injectable, NotFoundException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { Exchange, InstrumentType } from '../generated/prisma/enums';
import { PrismaService } from '../prisma/prisma.service';
import { QuoteIngestionService } from './quote-ingestion.service';

@Injectable()
export class MarketDataService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ingestion: QuoteIngestionService,
    private readonly config: ConfigService,
  ) {}

  async getMarketSnapshot() {
    const instruments = await this.prisma.instrument.findMany({
      where: { isActive: true },
      include: { quote: true },
      orderBy: { displayOrder: 'asc' },
    });

    return this.mapSnapshot(instruments);
  }

  async searchMarketSnapshot(query = '', page = 1, pageSize = 50) {
    const normalizedQuery = query.trim();
    const safePage = Math.max(1, Math.trunc(page) || 1);
    const safePageSize = Math.min(100, Math.max(1, Math.trunc(pageSize) || 50));

    const where = {
      isActive: true,
      exchange: { in: [Exchange.NSE, Exchange.BSE] },
      type: InstrumentType.EQUITY,
      quote: {
        is: {
          lastPrice: { gt: 0 },
        },
      },
      ...(normalizedQuery
        ? {
            OR: [
              { symbol: { contains: normalizedQuery, mode: 'insensitive' as const } },
              { name: { contains: normalizedQuery, mode: 'insensitive' as const } },
              { isin: { contains: normalizedQuery, mode: 'insensitive' as const } },
            ],
          }
        : {}),
    };

    const [total, instruments] = await this.prisma.$transaction([
      this.prisma.instrument.count({ where }),
      this.prisma.instrument.findMany({
        where,
        include: { quote: true },
        orderBy: [{ displayOrder: 'asc' }, { symbol: 'asc' }],
        skip: (safePage - 1) * safePageSize,
        take: safePageSize,
      }),
    ]);

    return {
      data: this.mapSnapshot(instruments),
      total,
      page: safePage,
      pageSize: safePageSize,
      hasMore: safePage * safePageSize < total,
    };
  }

  getIndexSnapshot() {
    return this.ingestion.getIndexSnapshot();
  }

  async updateQuote(symbol: string, price: string, volume?: string) {
    const instrument = await this.prisma.instrument.findFirst({
      where: { symbol },
      include: { quote: true },
    });

    if (!instrument) {
      throw new NotFoundException('Instrument not found');
    }

    const previousClose =
      instrument.quote?.previousClose?.toString() ??
      instrument.quote?.lastPrice?.toString() ??
      price;
    const previousCloseNumber = Number(previousClose);
    const priceNumber = Number(price);
    const change =
      previousCloseNumber > 0
        ? ((priceNumber - previousCloseNumber) / previousCloseNumber) * 100
        : 0;

    const updatedAt = new Date();
    await this.ingestion.ingest(instrument.exchange, {
      symbol: instrument.symbol,
      price,
      previousClose,
      openPrice: instrument.quote?.openPrice?.toString() ?? null,
      highPrice: instrument.quote?.highPrice?.toString() ?? null,
      lowPrice: instrument.quote?.lowPrice?.toString() ?? null,
      bidPrice: instrument.quote?.bidPrice?.toString() ?? price,
      askPrice: instrument.quote?.askPrice?.toString() ?? price,
      volume: volume ?? instrument.quote?.volume?.toString() ?? '0',
      change: Number(change.toFixed(2)),
      source: 'LIVE',
      updatedAt,
    });

    return {
      symbol: instrument.symbol,
      exchange: instrument.exchange,
      price: priceNumber,
      volume: volume ?? instrument.quote?.volume?.toString() ?? '0',
      updatedAt,
    };
  }

  private mapSnapshot(instruments: any[]) {
    const now = Date.now();
    const staleAfterMs = this.positiveInteger(
      this.config.get<string>('MARKET_DATA_STALE_AFTER_MS'),
      60000,
    );

    return instruments
      .filter((item) => Number(item.quote?.lastPrice ?? 0) > 0)
      .map((item) => {
        const lastPrice = Number(item.quote.lastPrice);
        const previousClose = Number(item.quote.previousClose ?? 0);
        const change =
          previousClose > 0
            ? ((lastPrice - previousClose) / previousClose) * 100
            : 0;
        const updatedAt = item.quote.asOf as Date;
        const quoteFresh = now - updatedAt.getTime() <= staleAfterMs;

        return {
          symbol: item.symbol,
          exchange: item.exchange,
          name: item.name,
          logoUrl: item.logoUrl,
          category: item.category,
          displayOrder: item.displayOrder,
          price: item.quote.lastPrice,
          change,
          previousClose: item.quote.previousClose ?? null,
          bid: item.quote.bidPrice ?? null,
          ask: item.quote.askPrice ?? null,
          volume: item.quote.volume?.toString() ?? '0',
          source: item.quote.source ?? null,
          updatedAt,
          quoteFresh,
        };
      })
      .sort((left, right) => {
        const freshnessDifference =
          Number(right.quoteFresh) - Number(left.quoteFresh);
        if (freshnessDifference !== 0) return freshnessDifference;
        if (left.displayOrder !== right.displayOrder) {
          return left.displayOrder - right.displayOrder;
        }
        return left.symbol.localeCompare(right.symbol);
      });
  }

  private positiveInteger(value: string | undefined, fallback: number) {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
  }
}
