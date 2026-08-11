import { MarketQuoteResult } from './market-data-provider.interface';

export interface MarketSubscription {
  symbol: string;
  exchange: string;
}

export interface StreamingMarketDataProvider {
  readonly name: string;
  connect(): Promise<void>;
  disconnect(): Promise<void>;
  subscribe(subscriptions: MarketSubscription[]): Promise<void>;
  onQuote(handler: (quote: MarketQuoteResult & { exchange: string }) => void): void;
}
