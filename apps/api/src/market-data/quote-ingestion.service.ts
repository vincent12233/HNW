import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { MarketDataHealthService } from './market-data-health.service';
import { MarketQuoteResult } from './providers/market-data-provider.interface';
import { MarketDataGateway } from './websocket/market-data/market-data.gateway';

@Injectable()
export class QuoteIngestionService {
  private readonly latestIndices = new Map<string, Record<string, unknown>>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly gateway: MarketDataGateway,
    private readonly health: MarketDataHealthService,
  ) {}

  async ingest(
    exchange: string,
    quote: MarketQuoteResult,
    type: 'STOCK' | 'INDEX' = 'STOCK',
  ) {
    if (
      Number.isNaN(quote.updatedAt.getTime()) ||
      quote.updatedAt.getTime() > Date.now() + 2 * 60 * 1000
    ) {
      return;
    }
    const payload = this.toPayload(exchange, quote, type);

    if (type === 'INDEX') {
      this.latestIndices.set(quote.symbol, payload);
      this.health.recordQuote(quote.source, quote.updatedAt);
      this.gateway.emitQuoteUpdate(payload);
      return;
    }

    const instrument = await this.prisma.instrument.findUnique({
      where: {
        exchange_symbol: {
          exchange: exchange as any,
          symbol: quote.symbol,
        },
      },
      include: { quote: { select: { asOf: true } } },
    });

    if (!instrument) {
      throw new NotFoundException(
        `Instrument not found: ${exchange}:${quote.symbol}`,
      );
    }

    if (instrument.quote && quote.updatedAt < instrument.quote.asOf) {
      return;
    }

    await this.prisma.marketQuote.upsert({
      where: { instrumentId: instrument.id },
      create: {
        instrumentId: instrument.id,
        lastPrice: quote.price,
        previousClose: quote.previousClose,
        openPrice: quote.openPrice,
        highPrice: quote.highPrice,
        lowPrice: quote.lowPrice,
        bidPrice: quote.bidPrice ?? quote.price,
        askPrice: quote.askPrice ?? quote.price,
        volume: BigInt(quote.volume || 0),
        source: quote.source,
        asOf: quote.updatedAt,
      },
      update: {
        lastPrice: quote.price,
        previousClose: quote.previousClose,
        openPrice: quote.openPrice,
        highPrice: quote.highPrice,
        lowPrice: quote.lowPrice,
        bidPrice: quote.bidPrice ?? quote.price,
        askPrice: quote.askPrice ?? quote.price,
        volume: BigInt(quote.volume || 0),
        source: quote.source,
        asOf: quote.updatedAt,
      },
    });

    this.health.recordQuote(quote.source, quote.updatedAt);
    this.gateway.emitQuoteUpdate(payload);
  }

  getIndexSnapshot() {
    return Array.from(this.latestIndices.values()).map((item) => ({ ...item }));
  }

  private toPayload(
    exchange: string,
    quote: MarketQuoteResult,
    type: 'STOCK' | 'INDEX',
  ) {
    return {
      type,
      symbol: quote.symbol,
      exchange,
      price: Number(quote.price),
      change: quote.change,
      volume: quote.volume,
      previousClose: Number(quote.previousClose),
      openPrice: quote.openPrice !== null ? Number(quote.openPrice) : null,
      highPrice: quote.highPrice !== null ? Number(quote.highPrice) : null,
      lowPrice: quote.lowPrice !== null ? Number(quote.lowPrice) : null,
      bidPrice: quote.bidPrice !== null ? Number(quote.bidPrice) : null,
      askPrice: quote.askPrice !== null ? Number(quote.askPrice) : null,
      updatedAt: quote.updatedAt,
    };
  }
}
