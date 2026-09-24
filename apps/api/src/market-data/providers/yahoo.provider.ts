import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';
import { Prisma } from '../../generated/prisma/client';
import {
  MarketDataProvider,
  MarketHistoryEvent,
  MarketHistoryPoint,
  MarketHistoryResult,
  MarketQuoteResult,
} from './market-data-provider.interface';
import {
  firstYahooChartResult,
  type YahooChartResponse,
} from './yahoo-chart.types';

type HistoryWindow = {
  range: '1d' | '5d' | '1mo' | '3mo' | '6mo' | '1y';
  interval: '5m' | '1h' | '1d';
};

/**
 * TEMPORARY FREE DEVELOPMENT PROVIDER.
 * Yahoo-specific URL, symbol formatting, and response parsing stay here so a
 * future commercial provider can replace this class without touching Flutter,
 * trading, or the MarketQuote REST/Socket contracts.
 */
@Injectable()
export class YahooProvider implements MarketDataProvider {
  readonly name = 'YAHOO';

  private readonly logger = new Logger(YahooProvider.name);

  private readonly symbols: Record<string, string> = {
    NIFTY50: '^NSEI',
    SENSEX: '^BSESN',
    BANKNIFTY: '^NSEBANK',
    INDIAVIX: '^INDIAVIX',
  };

  async getQuote(symbol: string, exchange = 'NSE'): Promise<MarketQuoteResult> {
    const normalizedSymbol = symbol.toUpperCase();
    const yahooSymbol =
      this.symbols[normalizedSymbol] ??
      `${normalizedSymbol}.${exchange.toUpperCase() === 'BSE' ? 'BO' : 'NS'}`;

    try {
      const url = `https://query1.finance.yahoo.com/v8/finance/chart/${yahooSymbol}`;
      const response = await axios.get<YahooChartResponse>(url, {
        params: { interval: '1m', range: '1d' },
        headers: { 'User-Agent': 'Mozilla/5.0' },
        timeout: 10000,
      });

      const result = firstYahooChartResult(response.data);
      if (!result) throw new Error('Quote empty');

      const meta = result.meta;
      if (!meta) throw new Error('Quote meta missing');
      const price = meta.regularMarketPrice;
      if (price === undefined || price === null) {
        throw new Error('Quote price missing');
      }

      const currentPrice = this.quoteDecimal(price);
      const previousClose = this.quoteDecimal(
        meta.chartPreviousClose ?? meta.previousClose ?? price,
      );
      const change = previousClose.gt(0)
        ? currentPrice.sub(previousClose).div(previousClose).mul(100)
        : new Prisma.Decimal(0);

      return {
        symbol: normalizedSymbol,
        price: this.quoteText(currentPrice),
        previousClose: this.quoteText(previousClose),
        openPrice: this.optionalQuoteText(meta.regularMarketOpen),
        highPrice: this.optionalQuoteText(meta.regularMarketDayHigh),
        lowPrice: this.optionalQuoteText(meta.regularMarketDayLow),
        bidPrice: this.optionalQuoteText(meta.bid),
        askPrice: this.optionalQuoteText(meta.ask),
        volume: String(meta.regularMarketVolume ?? 0),
        change: Number(change.toDecimalPlaces(2).toFixed()),
        source: this.name,
        updatedAt: new Date(),
      };
    } catch (error: unknown) {
      this.logger.error(`Quote failed: ${normalizedSymbol}`);
      const status =
        error && typeof error === 'object' && 'response' in error
          ? (error as { response?: { status?: number } }).response?.status
          : undefined;
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(JSON.stringify({ status, message }, null, 2));
      throw error;
    }
  }

  async getHistory(
    symbol: string,
    exchange: string,
    range: MarketHistoryResult['range'],
  ): Promise<MarketHistoryResult> {
    const window = this.window(range);
    const normalizedSymbol = symbol.trim().toUpperCase();
    const normalizedExchange = exchange.trim().toUpperCase();
    const yahooSymbol =
      this.symbols[normalizedSymbol] ??
      `${normalizedSymbol}.${normalizedExchange === 'BSE' ? 'BO' : 'NS'}`;
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
    range: MarketHistoryResult['range'],
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

  private window(range: MarketHistoryResult['range']): HistoryWindow {
    if (range === '1D') return { range: '1d', interval: '5m' };
    if (range === '1W') return { range: '5d', interval: '1h' };
    if (range === '1M') return { range: '1mo', interval: '1d' };
    if (range === '3M') return { range: '3mo', interval: '1d' };
    if (range === '6M') return { range: '6mo', interval: '1d' };
    return { range: '1y', interval: '1d' };
  }

  private quoteDecimal(value: unknown): Prisma.Decimal {
    try {
      const decimal = new Prisma.Decimal(value as string | number);
      if (!decimal.isFinite() || decimal.lte(0)) {
        throw new Error('invalid');
      }
      return decimal.toDecimalPlaces(4, Prisma.Decimal.ROUND_HALF_UP);
    } catch {
      throw new Error('Quote price invalid');
    }
  }

  private quoteText(value: Prisma.Decimal): string {
    return value.toFixed();
  }

  private optionalQuoteText(value: unknown): string | null {
    if (value === undefined || value === null || value === '') return null;
    try {
      return this.quoteText(this.quoteDecimal(value));
    } catch {
      return null;
    }
  }
}
