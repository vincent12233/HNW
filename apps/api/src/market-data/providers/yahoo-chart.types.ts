/** Narrow Yahoo Finance v8 chart JSON used by quote/history providers. */
export type YahooChartQuoteBars = {
  open?: Array<number | null>;
  high?: Array<number | null>;
  low?: Array<number | null>;
  close?: Array<number | null>;
  volume?: Array<number | null>;
};

export type YahooChartMeta = {
  regularMarketPrice?: number | null;
  chartPreviousClose?: number | null;
  previousClose?: number | null;
  regularMarketOpen?: number | null;
  regularMarketDayHigh?: number | null;
  regularMarketDayLow?: number | null;
  bid?: number | null;
  ask?: number | null;
  regularMarketVolume?: number | null;
};

export type YahooChartResult = {
  meta?: YahooChartMeta;
  timestamp?: number[];
  indicators?: { quote?: YahooChartQuoteBars[] };
  events?: unknown;
};

export type YahooChartResponse = {
  chart?: {
    result?: YahooChartResult[] | null;
    error?: unknown;
  };
};

export function firstYahooChartResult(
  data: YahooChartResponse | unknown,
): YahooChartResult | undefined {
  if (!data || typeof data !== 'object') return undefined;
  const chart = (data as YahooChartResponse).chart;
  const result = chart?.result?.[0];
  return result ?? undefined;
}
