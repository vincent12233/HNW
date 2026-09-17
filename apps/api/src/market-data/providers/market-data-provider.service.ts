import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { ApifyProvider } from './apify.provider';
import { IndiaStockMcpProvider } from './india-stock-mcp.provider';
import {
  MarketDataProvider,
  MarketQuoteRequest,
} from './market-data-provider.interface';
import { YahooProvider } from './yahoo.provider';

@Injectable()
export class MarketDataProviderService {
  constructor(
    private readonly config: ConfigService,
    private readonly indiaStockMcp: IndiaStockMcpProvider,
    private readonly yahoo: YahooProvider,
    private readonly apify: ApifyProvider,
  ) {}

  get provider(): MarketDataProvider {
    return this.activeProvider();
  }

  getQuote(symbol: string, exchange?: string) {
    return this.activeProvider().getQuote(symbol, exchange);
  }

  getQuotes(requests: MarketQuoteRequest[]) {
    const provider = this.activeProvider();
    if (provider.getQuotes) return provider.getQuotes(requests);
    return Promise.all(
      requests.map((request) =>
        provider.getQuote(request.symbol, request.exchange),
      ),
    );
  }

  get providerName() {
    return this.activeProvider().name;
  }

  get configuredProviderName() {
    return this.configuredName();
  }

  get providerConfigured() {
    const name = this.configuredName();
    if (name === 'APIFY') return this.apify.isConfigured();
    return true;
  }

  get fallbackEnabled() {
    return (
      (this.config.get<string>('MARKET_DATA_FALLBACK_ENABLED') ?? 'false')
        .trim()
        .toLowerCase() === 'true'
    );
  }

  private configuredName() {
    return (this.config.get<string>('MARKET_DATA_PROVIDER') ?? 'APIFY')
      .trim()
      .toUpperCase();
  }

  private activeProvider(): MarketDataProvider {
    const name = this.configuredName();
    const primary = this.resolve(name);
    if (name !== 'APIFY' || this.apify.isConfigured()) return primary;
    if (!this.fallbackEnabled) {
      return primary;
    }
    const fallback = (
      this.config.get<string>('MARKET_DATA_FALLBACK_PROVIDER') ?? ''
    )
      .trim()
      .toUpperCase();
    if (!fallback || fallback === 'APIFY') {
      return primary;
    }
    return this.resolve(fallback);
  }

  private resolve(name: string): MarketDataProvider {
    switch (name) {
      case 'APIFY':
        return this.apify;
      case 'INDIA_STOCK_MCP':
      case 'MCP':
        return this.indiaStockMcp;
      case 'YAHOO':
        return this.yahoo;
      default:
        throw new Error(`Unsupported market data provider: ${name}`);
    }
  }
}
