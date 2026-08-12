import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { IndiaStockMcpProvider } from './india-stock-mcp.provider';
import { MarketDataProvider } from './market-data-provider.interface';
import { YahooProvider } from './yahoo.provider';

@Injectable()
export class MarketDataProviderService {
  constructor(
    private readonly config: ConfigService,
    private readonly indiaStockMcp: IndiaStockMcpProvider,
    private readonly yahoo: YahooProvider,
  ) {}

  get provider(): MarketDataProvider {
    const name = (
      this.config.get<string>('MARKET_DATA_PROVIDER') ?? 'INDIA_STOCK_MCP'
    )
      .trim()
      .toUpperCase();

    switch (name) {
      case 'INDIA_STOCK_MCP':
      case 'MCP':
        return this.indiaStockMcp;
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
