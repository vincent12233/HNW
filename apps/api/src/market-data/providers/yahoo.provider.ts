import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';
import { Prisma } from '../../generated/prisma/client';
import {
  MarketDataProvider,
  MarketQuoteResult,
} from './market-data-provider.interface';
import {
  firstYahooChartResult,
  type YahooChartResponse,
} from './yahoo-chart.types';

@Injectable()
export class YahooProvider implements MarketDataProvider {
  readonly name = 'YAHOO';

  private readonly logger = new Logger(YahooProvider.name);

  private readonly symbols: Record<string, string> = {
    NIFTY50: '^NSEI',
    SENSEX: '^BSESN',
    BANKNIFTY: '^NSEBANK',
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
      if (!result) throw new Error('Yahoo quote empty');

      const meta = result.meta;
      if (!meta) throw new Error('Yahoo meta missing');
      const price = meta.regularMarketPrice;
      if (price === undefined || price === null) {
        throw new Error('Yahoo price missing');
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
      this.logger.error(`Yahoo quote failed: ${normalizedSymbol}`);
      const status =
        error && typeof error === 'object' && 'response' in error
          ? (error as { response?: { status?: number } }).response?.status
          : undefined;
      const message = error instanceof Error ? error.message : String(error);
      this.logger.error(JSON.stringify({ status, message }, null, 2));
      throw error;
    }
  }

  private quoteDecimal(value: unknown): Prisma.Decimal {
    try {
      const decimal = new Prisma.Decimal(value as string | number);
      if (!decimal.isFinite() || decimal.lte(0)) {
        throw new Error('invalid');
      }
      return decimal.toDecimalPlaces(4, Prisma.Decimal.ROUND_HALF_UP);
    } catch {
      throw new Error('Yahoo price invalid');
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
