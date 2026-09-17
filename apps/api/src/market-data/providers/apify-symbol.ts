export type ApifyExchange = 'NSE' | 'BSE';

export function normalizeApifyExchange(
  value: string | undefined,
): ApifyExchange {
  const exchange = (value ?? '').trim().toUpperCase();
  if (exchange === 'NSE' || exchange === 'BSE') return exchange;
  throw new Error('Apify quotes require an explicit NSE or BSE exchange');
}

export function normalizeApifySymbol(symbol: string): string {
  const normalized = symbol.trim().toUpperCase();
  if (!normalized) {
    throw new Error('Apify quotes require a non-empty symbol');
  }
  return normalized;
}

export function instrumentKey(exchange: string, symbol: string): string {
  return `${normalizeApifyExchange(exchange)}:${normalizeApifySymbol(symbol)}`;
}
