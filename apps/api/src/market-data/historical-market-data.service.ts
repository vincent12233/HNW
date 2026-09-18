import {
  BadRequestException,
  Injectable,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import { PrismaService } from '../prisma/prisma.service';
import { MarketHistoryResult } from './providers/market-data-provider.interface';
import { MarketDataProviderService } from './providers/market-data-provider.service';

type HistoryRange = MarketHistoryResult['range'];

@Injectable()
export class HistoricalMarketDataService {
  private readonly cache = new Map<
    string,
    { result: MarketHistoryResult; expiresAt: number; staleUntil: number }
  >();
  private readonly inFlight = new Map<string, Promise<MarketHistoryResult>>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly provider: MarketDataProviderService,
  ) {}

  async getHistory(
    symbol: string,
    range: string,
    exchange = '',
  ): Promise<MarketHistoryResult> {
    const normalizedSymbol = symbol
      .trim()
      .toUpperCase()
      .replace(/\.(NS|BO)$/i, '');
    if (!normalizedSymbol) throw new BadRequestException('Symbol is required');

    const normalizedRange = this.normalizeRange(range);
    const normalizedExchange = this.normalizeExchange(exchange);
    const instrument = await this.prisma.instrument.findFirst({
      where: {
        symbol: normalizedSymbol,
        isActive: true,
        exchange: normalizedExchange ?? { in: ['NSE', 'BSE'] },
        type: 'EQUITY',
      },
      select: { symbol: true, exchange: true },
      orderBy: { exchange: 'desc' },
    });
    if (!instrument) throw new NotFoundException('Stock not found');

    const cacheKey = `${instrument.exchange}:${instrument.symbol}:${normalizedRange}`;
    const cached = this.cache.get(cacheKey);
    if (cached && cached.expiresAt > Date.now()) return cached.result;
    const pending = this.inFlight.get(cacheKey);
    if (pending) return pending;

    const request = this.provider
      .getHistory(instrument.symbol, instrument.exchange, normalizedRange)
      .then((result) => {
        const now = Date.now();
        const hasData = result.data.length > 1;
        const expiresAt = now + this.cacheTtl(normalizedRange, hasData);
        this.cache.set(cacheKey, {
          result,
          expiresAt,
          staleUntil: hasData ? now + 6 * 60 * 60 * 1000 : expiresAt,
        });
        return result;
      })
      .catch((error: unknown) => {
        if (cached && cached.staleUntil > Date.now()) return cached.result;
        if (error instanceof ServiceUnavailableException) throw error;
        throw new ServiceUnavailableException(
          'Price history is temporarily unavailable',
        );
      })
      .finally(() => this.inFlight.delete(cacheKey));
    this.inFlight.set(cacheKey, request);
    return request;
  }

  private normalizeRange(value: string): HistoryRange {
    const normalized = value.trim().toUpperCase();
    if (
      normalized === '1D' ||
      normalized === '1W' ||
      normalized === '1M' ||
      normalized === '3M' ||
      normalized === '6M' ||
      normalized === '1Y'
    ) {
      return normalized;
    }
    throw new BadRequestException('Range must be 1D, 1W, 1M, 3M, 6M or 1Y');
  }

  private normalizeExchange(value: string): 'NSE' | 'BSE' | null {
    const normalized = value.trim().toUpperCase();
    if (!normalized) return null;
    if (normalized === 'NSE' || normalized === 'BSE') return normalized;
    throw new BadRequestException('Exchange must be NSE or BSE');
  }

  private cacheTtl(range: HistoryRange, hasData: boolean) {
    if (!hasData || range === '1D') return 30 * 1000;
    if (range === '1W') return 5 * 60 * 1000;
    if (range === '1M') return 15 * 60 * 1000;
    return 60 * 60 * 1000;
  }
}
