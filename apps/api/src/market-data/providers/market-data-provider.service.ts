import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import {
  MarketDataProvider,
  MarketHistoryResult,
} from './market-data-provider.interface';
import { YahooProvider } from './yahoo.provider';

@Injectable()
export class MarketDataProviderService {
  constructor(
    private readonly config: ConfigService,
    private readonly yahoo: YahooProvider,
  ) {}

  get provider(): MarketDataProvider {
    const name = (this.config.get<string>('MARKET_DATA_PROVIDER') ?? 'YAHOO')
      .trim()
      .toUpperCase();

    // Temporary free development provider only. Future commercial providers
    // should be registered here without changing Flutter or trading APIs.
    if (name === '' || name === 'YAHOO') {
      return this.yahoo;
    }

    throw new Error(
      `Unsupported market data provider: ${name}. Only YAHOO is configured as the temporary development provider.`,
    );
  }

  getQuote(symbol: string, exchange?: string) {
    return this.provider.getQuote(symbol, exchange);
  }

  getHistory(
    symbol: string,
    exchange: string,
    range: MarketHistoryResult['range'],
  ) {
    return this.provider.getHistory(symbol, exchange, range);
  }

  get providerName() {
    return this.provider.name;
  }
}
