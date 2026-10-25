export type MarketTick = {
  instrumentId: string;
  exchange: string;
  symbol: string;
  sequence: number;
  price: number;
  volume: number;
  sourceTimestamp: Date;
  receivedAt: Date;
  quality: 'LIVE' | 'DELAYED' | 'STALE' | 'UNAVAILABLE';
};

export type CandleInterval = '1m' | '5m' | '15m' | '1h' | '1d';

export type MarketCandle = {
  bucket: Date;
  open: number;
  high: number;
  low: number;
  close: number;
  volume: number;
};
