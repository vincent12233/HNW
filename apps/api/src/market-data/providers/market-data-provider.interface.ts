export interface MarketQuoteResult {
  symbol: string;
  price: string;
  previousClose: string;
  openPrice: string | null;
  highPrice: string | null;
  lowPrice: string | null;
  bidPrice: string | null;
  askPrice: string | null;
  volume: string;
  change: number;
  source: string;
  updatedAt: Date;
}

export interface MarketDataProvider {
  readonly name: string;
  getQuote(symbol: string, exchange?: string): Promise<MarketQuoteResult>;
}
