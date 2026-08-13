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

export interface MarketHistoryPoint {
  date: string;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
}

export interface MarketHistoryResult {
  symbol: string;
  exchange: string;
  range: '1D' | '1W' | '1M' | '3M' | '6M' | '1Y';
  timezone: 'Asia/Kolkata';
  interval: '5m' | '1h' | '1d';
  data: MarketHistoryPoint[];
  events?: MarketHistoryEvent[];
}

export interface MarketHistoryEvent {
  date: string;
  type: 'DIVIDEND' | 'SPLIT';
  value: number;
  label: string;
}

export interface MarketDataProvider {
  readonly name: string;
  getQuote(symbol: string, exchange?: string): Promise<MarketQuoteResult>;
}
