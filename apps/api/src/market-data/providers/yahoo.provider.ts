import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';
import {
  MarketDataProvider,
  MarketQuoteResult,
} from './market-data-provider.interface';

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
      const response = await axios.get(url, {
        params: { interval: '1m', range: '1d' },
        headers: { 'User-Agent': 'Mozilla/5.0' },
        timeout: 10000,
      });

      const result = response.data?.chart?.result?.[0];
      if (!result) throw new Error('Yahoo quote empty');

      const meta = result.meta;
      const price = meta.regularMarketPrice;
      if (price === undefined || price === null) {
        throw new Error('Yahoo price missing');
      }

      const currentPrice = Number(price);
      const previousClose =
        meta.chartPreviousClose ?? meta.previousClose ?? currentPrice;
      const previousCloseNumber = Number(previousClose);
      const change =
        previousCloseNumber > 0
          ? ((currentPrice - previousCloseNumber) / previousCloseNumber) * 100
          : 0;

      return {
        symbol: normalizedSymbol,
        price: String(currentPrice),
        previousClose: String(previousCloseNumber),
        openPrice:
          meta.regularMarketOpen !== undefined
            ? String(meta.regularMarketOpen)
            : null,
        highPrice:
          meta.regularMarketDayHigh !== undefined
            ? String(meta.regularMarketDayHigh)
            : null,
        lowPrice:
          meta.regularMarketDayLow !== undefined
            ? String(meta.regularMarketDayLow)
            : null,
        bidPrice:
          meta.bid !== undefined && meta.bid !== null ? String(meta.bid) : null,
        askPrice:
          meta.ask !== undefined && meta.ask !== null ? String(meta.ask) : null,
        volume: String(meta.regularMarketVolume ?? 0),
        change: Number(change.toFixed(2)),
        source: this.name,
        updatedAt: new Date(),
      };
    } catch (error: any) {
      this.logger.error(`Yahoo quote failed: ${normalizedSymbol}`);
      this.logger.error(
        JSON.stringify(
          { status: error?.response?.status, message: error?.message },
          null,
          2,
        ),
      );
      throw error;
    }
  }
}
