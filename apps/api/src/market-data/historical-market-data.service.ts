import {
  BadRequestException,
  Injectable,
  Logger,
  NotFoundException,
  ServiceUnavailableException,
} from '@nestjs/common';
import axios from 'axios';
import { PrismaService } from '../prisma/prisma.service';
import { IndiaStockMcpProvider } from './providers/india-stock-mcp.provider';
import {
  MarketHistoryPoint,
  MarketHistoryEvent,
  MarketHistoryResult,
} from './providers/market-data-provider.interface';
import {
  firstYahooChartResult,
  type YahooChartResponse,
} from './providers/yahoo-chart.types';

type HistoryRange = '1D' | '1W' | '1M' | '3M' | '6M' | '1Y';
type HistoryWindow = {
  range: '1d' | '5d' | '1mo' | '3mo' | '6mo' | '1y';
  interval: '5m' | '1h' | '1d';
};

@Injectable()
export class HistoricalMarketDataService {
  private readonly logger = new Logger(HistoricalMarketDataService.name);
  private readonly cache = new Map<
    string,
    { result: MarketHistoryResult; expiresAt: number; staleUntil: number }
  >();
  private readonly inFlight = new Map<string, Promise<MarketHistoryResult>>();

  constructor(
    private readonly prisma: PrismaService,
    private readonly indiaStockMcp: IndiaStockMcpProvider,
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

    const request = this.loadHistory(
      instrument.symbol,
      instrument.exchange,
      normalizedRange,
    )
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

  private async loadHistory(
    symbol: string,
    exchange: string,
    range: HistoryRange,
  ): Promise<MarketHistoryResult> {
    if (exchange === 'NSE' && range === '1M') {
      const mcpHistory = await this.tryMcpHistory(symbol, range);
      if (mcpHistory.length > 1) {
        return this.result(symbol, exchange, range, '1d', mcpHistory);
      }
    }
    return this.getYahooHistory(symbol, exchange, range, this.window(range));
  }

  private async tryMcpHistory(symbol: string, range: '1M') {
    try {
      if (!(await this.indiaStockMcp.supportsHistorical())) return [];
      const { from, to } = this.dateWindow(range);
      return await this.indiaStockMcp.getHistorical(symbol, from, to, '1d');
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`MCP history fallback for NSE:${symbol}: ${message}`);
      return [];
    }
  }

  private async getYahooHistory(
    symbol: string,
    exchange: string,
    range: HistoryRange,
    window: HistoryWindow,
  ): Promise<MarketHistoryResult> {
    const yahooSymbol = `${symbol}.${exchange === 'BSE' ? 'BO' : 'NS'}`;
    try {
      const response = await axios.get<YahooChartResponse>(
        `https://query1.finance.yahoo.com/v8/finance/chart/${encodeURIComponent(yahooSymbol)}`,
        {
          params: {
            range: window.range,
            interval: window.interval,
            includePrePost: false,
            events: 'div,splits',
          },
          headers: { 'User-Agent': 'Mozilla/5.0' },
          timeout: 10000,
        },
      );
      const chart = firstYahooChartResult(response.data);
      const timestamps = Array.isArray(chart?.timestamp) ? chart.timestamp : [];
      const quote = chart?.indicators?.quote?.[0];
      if (!quote || timestamps.length === 0) {
        return this.result(symbol, exchange, range, window.interval, []);
      }
      const data: MarketHistoryPoint[] = [];
      for (let index = 0; index < timestamps.length; index++) {
        const point = this.point(
          timestamps[index],
          quote.open?.[index],
          quote.high?.[index],
          quote.low?.[index],
          quote.close?.[index],
          quote.volume?.[index],
        );
        if (point) data.push(point);
      }
      return this.result(
        symbol,
        exchange,
        range,
        window.interval,
        data,
        this.corporateActions(chart?.events),
      );
    } catch (error: unknown) {
      const status = (error as { response?: { status?: number } })?.response
        ?.status;
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`History failed for ${exchange}:${symbol}: ${message}`);
      if (status === 404) {
        return this.result(symbol, exchange, range, window.interval, []);
      }
      throw error;
    }
  }

  private result(
    symbol: string,
    exchange: string,
    range: HistoryRange,
    interval: '5m' | '1h' | '1d',
    data: MarketHistoryPoint[],
    events: MarketHistoryEvent[] = [],
  ): MarketHistoryResult {
    return {
      symbol,
      exchange,
      range,
      timezone: 'Asia/Kolkata',
      interval,
      data: this.normalizePoints(data),
      events,
    };
  }

  private corporateActions(value: unknown): MarketHistoryEvent[] {
    if (!value || typeof value !== 'object') return [];
    const events = value as Record<string, unknown>;
    const result: MarketHistoryEvent[] = [];
    const dividends = events.dividends;
    if (dividends && typeof dividends === 'object') {
      for (const row of Object.values(dividends as Record<string, unknown>)) {
        if (!row || typeof row !== 'object') continue;
        const item = row as Record<string, unknown>;
        const timestamp = this.number(item.date);
        const amount = this.number(item.amount);
        if (timestamp === null || amount === null || amount <= 0) continue;
        result.push({
          date: new Date(timestamp * 1000).toISOString(),
          type: 'DIVIDEND',
          value: amount,
          label: `Dividend ${amount.toFixed(2)}`,
        });
      }
    }
    const splits = events.splits;
    if (splits && typeof splits === 'object') {
      for (const row of Object.values(splits as Record<string, unknown>)) {
        if (!row || typeof row !== 'object') continue;
        const item = row as Record<string, unknown>;
        const timestamp = this.number(item.date);
        const numerator = this.number(item.numerator);
        const denominator = this.number(item.denominator);
        if (
          timestamp === null ||
          numerator === null ||
          denominator === null ||
          numerator <= 0 ||
          denominator <= 0
        )
          continue;
        result.push({
          date: new Date(timestamp * 1000).toISOString(),
          type: 'SPLIT',
          value: numerator / denominator,
          label: `Split ${numerator}:${denominator}`,
        });
      }
    }
    return result.sort(
      (left, right) => Date.parse(left.date) - Date.parse(right.date),
    );
  }

  private normalizePoints(points: MarketHistoryPoint[]) {
    const byDate = new Map<string, MarketHistoryPoint>();
    for (const point of points) {
      const values = [point.open, point.high, point.low, point.close];
      if (
        !values.every((value) => Number.isFinite(value) && value > 0) ||
        point.high < Math.max(point.open, point.close) ||
        point.low > Math.min(point.open, point.close) ||
        Number.isNaN(Date.parse(point.date))
      )
        continue;
      byDate.set(point.date, point);
    }
    return [...byDate.values()].sort(
      (left, right) => Date.parse(left.date) - Date.parse(right.date),
    );
  }

  private point(
    timestamp: unknown,
    openValue: unknown,
    highValue: unknown,
    lowValue: unknown,
    closeValue: unknown,
    volumeValue: unknown,
  ): MarketHistoryPoint | null {
    const time = this.number(timestamp);
    const open = this.number(openValue);
    const high = this.number(highValue);
    const low = this.number(lowValue);
    const close = this.number(closeValue);
    const volume = this.number(volumeValue) ?? 0;
    if ([time, open, high, low, close].some((value) => value === null))
      return null;
    if (close! <= 0) return null;
    return {
      date: new Date(time! * 1000).toISOString(),
      open: open!,
      high: high!,
      low: low!,
      close: close!,
      volume,
    };
  }

  private number(value: unknown): number | null {
    if (typeof value === 'number') return Number.isFinite(value) ? value : null;
    if (typeof value !== 'string') return null;
    const parsed = Number(value.replace(/,/g, '').trim());
    return Number.isFinite(parsed) ? parsed : null;
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

  private window(range: HistoryRange): HistoryWindow {
    if (range === '1D') return { range: '1d', interval: '5m' };
    if (range === '1W') return { range: '5d', interval: '1h' };
    if (range === '1M') return { range: '1mo', interval: '1d' };
    if (range === '3M') return { range: '3mo', interval: '1d' };
    if (range === '6M') return { range: '6mo', interval: '1d' };
    return { range: '1y', interval: '1d' };
  }

  private cacheTtl(range: HistoryRange, hasData: boolean) {
    if (!hasData || range === '1D') return 30 * 1000;
    if (range === '1W') return 5 * 60 * 1000;
    if (range === '1M') return 15 * 60 * 1000;
    return 60 * 60 * 1000;
  }

  private dateWindow(_range: '1M') {
    const nowIst = new Date(Date.now() + 330 * 60 * 1000);
    const fromDate = new Date(nowIst);
    fromDate.setUTCDate(fromDate.getUTCDate() - 31);
    return { from: this.dateOnly(fromDate), to: this.dateOnly(nowIst) };
  }

  private dateOnly(value: Date) {
    return [
      value.getUTCFullYear(),
      `${value.getUTCMonth() + 1}`.padStart(2, '0'),
      `${value.getUTCDate()}`.padStart(2, '0'),
    ].join('-');
  }
}
