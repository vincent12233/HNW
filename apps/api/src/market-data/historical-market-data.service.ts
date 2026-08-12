import { BadRequestException, Injectable, Logger, NotFoundException } from '@nestjs/common';
import axios from 'axios';
import { PrismaService } from '../prisma/prisma.service';
import { IndiaStockMcpProvider } from './providers/india-stock-mcp.provider';
import {
  MarketHistoryPoint,
  MarketHistoryResult,
} from './providers/market-data-provider.interface';

type HistoryRange = '1D' | '1W' | '1M';

type HistoryWindow = {
  range: '1d' | '5d' | '1mo';
  interval: '5m' | '1h' | '1d';
};

@Injectable()
export class HistoricalMarketDataService {
  private readonly logger = new Logger(HistoricalMarketDataService.name);

  constructor(
    private readonly prisma: PrismaService,
    private readonly indiaStockMcp: IndiaStockMcpProvider,
  ) {}

  async getHistory(symbol: string, range: string): Promise<MarketHistoryResult> {
    const normalizedSymbol = symbol.trim().toUpperCase().replace(/\.(NS|BO)$/i, '');
    if (!normalizedSymbol) {
      throw new BadRequestException('Symbol is required');
    }

    const instrument = await this.prisma.instrument.findFirst({
      where: {
        symbol: normalizedSymbol,
        isActive: true,
        exchange: { in: ['NSE', 'BSE'] },
        type: 'EQUITY',
      },
      select: { symbol: true, exchange: true },
      orderBy: { exchange: 'desc' },
    });
    if (!instrument) {
      throw new NotFoundException('Stock not found');
    }

    const normalizedRange = this.normalizeRange(range);
    const window = this.window(normalizedRange);

    if (instrument.exchange === 'NSE' && normalizedRange !== '1D') {
      const mcpHistory = await this.tryMcpHistory(
        instrument.symbol,
        normalizedRange,
      );
      if (mcpHistory.length > 1) {
        return {
          symbol: instrument.symbol,
          interval: '1d',
          data: mcpHistory,
        };
      }
    }

    return this.getYahooHistory(
      instrument.symbol,
      instrument.exchange,
      window,
    );
  }

  private async tryMcpHistory(symbol: string, range: '1W' | '1M') {
    try {
      if (!(await this.indiaStockMcp.supportsHistorical())) return [];
      const { from, to } = this.dateWindow(range);
      return await this.indiaStockMcp.getHistorical(
        symbol,
        from,
        to,
        '1d',
      );
    } catch (error: unknown) {
      const message = error instanceof Error ? error.message : String(error);
      this.logger.warn(`MCP history fallback for NSE:${symbol}: ${message}`);
      return [];
    }
  }

  private async getYahooHistory(
    symbol: string,
    exchange: string,
    window: HistoryWindow,
  ): Promise<MarketHistoryResult> {
    const yahooSymbol = `${symbol}.${exchange === 'BSE' ? 'BO' : 'NS'}`;

    try {
      const response = await axios.get(
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

      const result = response.data?.chart?.result?.[0];
      const timestamps = Array.isArray(result?.timestamp) ? result.timestamp : [];
      const quote = result?.indicators?.quote?.[0];
      if (!quote || timestamps.length === 0) {
        return { symbol, interval: window.interval, data: [] };
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

      return { symbol, interval: window.interval, data };
    } catch (error: unknown) {
      const status = (error as { response?: { status?: number } })?.response?.status;
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(`History failed for ${exchange}:${symbol}: ${message}`);
      if (status === 404) return { symbol, interval: window.interval, data: [] };
      throw error;
    }
  }

  private dateWindow(range: '1W' | '1M') {
    const nowIst = new Date(Date.now() + 5.5 * 60 * 60 * 1000);
    const to = this.dateOnly(nowIst);
    const fromDate = new Date(nowIst);
    fromDate.setUTCDate(fromDate.getUTCDate() - (range === '1W' ? 7 : 31));
    return { from: this.dateOnly(fromDate), to };
  }

  private dateOnly(value: Date) {
    const year = value.getUTCFullYear();
    const month = `${value.getUTCMonth() + 1}`.padStart(2, '0');
    const day = `${value.getUTCDate()}`.padStart(2, '0');
    return `${year}-${month}-${day}`;
  }

  private normalizeRange(value: string): HistoryRange {
    const normalized = value.trim().toUpperCase();
    if (normalized === '1D' || normalized === '1W' || normalized === '1M') {
      return normalized;
    }
    throw new BadRequestException('Range must be 1D, 1W or 1M');
  }

  private window(range: HistoryRange): HistoryWindow {
    if (range === '1D') return { range: '1d', interval: '5m' };
    if (range === '1W') return { range: '5d', interval: '1h' };
    return { range: '1mo', interval: '1d' };
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
    if (
      time === null ||
      open === null ||
      high === null ||
      low === null ||
      close === null ||
      close <= 0
    ) {
      return null;
    }

    return {
      date: new Date(time * 1000).toISOString(),
      open,
      high,
      low,
      close,
      volume,
    };
  }

  private number(value: unknown): number | null {
    if (typeof value === 'number') return Number.isFinite(value) ? value : null;
    if (typeof value !== 'string') return null;
    const parsed = Number(value.replace(/,/g, '').trim());
    return Number.isFinite(parsed) ? parsed : null;
  }
}
