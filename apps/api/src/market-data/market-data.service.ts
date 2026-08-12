import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { QuoteIngestionService } from './quote-ingestion.service';

@Injectable()
export class MarketDataService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly ingestion: QuoteIngestionService,
  ) {}

  async getMarketSnapshot() {
    const instruments = await this.prisma.instrument.findMany({
      where: { isActive: true },
      include: { quote: true },
      orderBy: { displayOrder: 'asc' },
    });

    return instruments.map((item) => {
      const lastPrice = Number(item.quote?.lastPrice ?? 0);
      const previousClose = Number(item.quote?.previousClose ?? 0);
      const change =
        previousClose > 0
          ? ((lastPrice - previousClose) / previousClose) * 100
          : 0;

      return {
        symbol: item.symbol,
        exchange: item.exchange,
        name: item.name,
        logoUrl: item.logoUrl,
        category: item.category,
        displayOrder: item.displayOrder,
        price: item.quote?.lastPrice ?? null,
        change,
        previousClose: item.quote?.previousClose ?? null,
        bid: item.quote?.bidPrice ?? null,
        ask: item.quote?.askPrice ?? null,
        volume: item.quote?.volume?.toString() ?? '0',
        source: item.quote?.source ?? null,
        updatedAt: item.quote?.asOf ?? null,
      };
    });
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
}
