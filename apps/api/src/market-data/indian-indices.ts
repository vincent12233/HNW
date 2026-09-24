export const INDIAN_INDICES = [
  { symbol: 'NIFTY50', exchange: 'NSE', providerSymbol: '^NSEI' },
  { symbol: 'SENSEX', exchange: 'BSE', providerSymbol: '^BSESN' },
  { symbol: 'BANKNIFTY', exchange: 'NSE', providerSymbol: '^NSEBANK' },
  { symbol: 'INDIAVIX', exchange: 'NSE', providerSymbol: '^INDIAVIX' },
] as const;

export type IndianIndex = (typeof INDIAN_INDICES)[number];

export function indianIndexBySymbol(symbol: string): IndianIndex | undefined {
  const normalized = symbol.trim().toUpperCase();
  return INDIAN_INDICES.find((index) => index.symbol === normalized);
}
