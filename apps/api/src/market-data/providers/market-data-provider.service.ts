import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { MarketDataProvider } from './market-data-provider.interface';
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

    switch (name) {
      case 'YAHOO':
        return this.yahoo;
      default:
        throw new Error(`Unsupported market data provider: ${name}`);
    }
  }

  getQuote(symbol: string, exchange?: string) {
    return this.provider.getQuote(symbol, exchange);
  }

  get providerName() {
    return this.provider.name;
  }
}
