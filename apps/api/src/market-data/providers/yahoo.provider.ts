import { Injectable, Logger } from '@nestjs/common';
import axios from 'axios';

@Injectable()
export class YahooProvider {
  private readonly logger = new Logger(YahooProvider.name);

  private readonly symbols: Record<string, string> = {
    RELIANCE: 'RELIANCE.NS',
    TCS: 'TCS.NS',
    HDFCBANK: 'HDFCBANK.NS',

    NIFTY50: '^NSEI',
    SENSEX: '^BSESN',
    BANKNIFTY: '^NSEBANK',
  };

  async getQuote(symbol: string) {
    const yahooSymbol =
      this.symbols[symbol.toUpperCase()] ?? `${symbol.toUpperCase()}.NS`;

    try {
      const url = `https://query1.finance.yahoo.com/v8/finance/chart/${yahooSymbol}`;

      const response = await axios.get(url, {
        params: {
          interval: '1m',
          range: '1d',
        },

        headers: {
          'User-Agent': 'Mozilla/5.0',
        },

        timeout: 10000,
      });

      const result = response.data?.chart?.result?.[0];

      if (!result) {
        throw new Error('Yahoo quote empty');
      }

      const meta = result.meta;

      const price = meta.regularMarketPrice;

      const previousClose =
        meta.chartPreviousClose ?? meta.previousClose ?? null;

      const openPrice = meta.regularMarketOpen ?? null;

      const highPrice = meta.regularMarketDayHigh ?? null;

      const lowPrice = meta.regularMarketDayLow ?? null;

      const volume = meta.regularMarketVolume ?? 0;

      if (price === undefined || price === null) {
        throw new Error('Yahoo price missing');
      }

      const currentPrice = Number(price);

      const previousCloseNumber =
        previousClose !== null ? Number(previousClose) : currentPrice;

      const change =
        previousCloseNumber > 0
          ? ((currentPrice - previousCloseNumber) / previousCloseNumber) * 100
          : 0;

      return {
        symbol: symbol.toUpperCase(),

        price: String(currentPrice),

        previousClose: String(previousCloseNumber),

        openPrice: openPrice !== null ? String(openPrice) : null,

        highPrice: highPrice !== null ? String(highPrice) : null,

        lowPrice: lowPrice !== null ? String(lowPrice) : null,

        volume: String(volume),

        change: Number(change.toFixed(2)),

        updatedAt: new Date(),
      };
    } catch (error: any) {
      this.logger.error(`Yahoo quote failed: ${symbol}`);

      this.logger.error(
        JSON.stringify(
          {
            status: error?.response?.status,

            message: error?.message,
          },
          null,
          2,
        ),
      );

      throw error;
    }
  }
}
