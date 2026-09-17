import { Prisma } from '../../generated/prisma/client';
import {
  MarketQuoteResult,
  QuoteTimestampConfidence,
} from './market-data-provider.interface';
import {
  instrumentKey,
  normalizeApifyExchange,
  normalizeApifySymbol,
} from './apify-symbol';

const INGESTION_TIMESTAMP_KEYS = new Set([
  'scrapedat',
  'fetchedat',
  'ingestedat',
  'receivedat',
  'collectedat',
]);

const EXCHANGE_TIMESTAMP_KEYS = [
  'lastUpdateTime',
  'lastUpdatedTime',
  'lastTradedTime',
  'lastTradeTime',
  'lastTradedAt',
  'tradeTime',
  'exchangeTimestamp',
  'marketTimestamp',
  'quoteTimestamp',
  'asOf',
  'timestamp',
  'updTime',
  'lastUpdate',
];

export type ApifyDatasetItem = Record<string, unknown>;

function asText(value: unknown): string {
  return typeof value === 'string' ? value : '';
}

export function parseApifyActorId(actorId: string): string {
  const trimmed = actorId.trim();
  if (!trimmed) throw new Error('APIFY_ACTOR_ID is required');
  if (trimmed.includes('~')) return trimmed;
  if (trimmed.includes('/')) return trimmed.replace('/', '~');
  return trimmed;
}

export function isPlaceholderApifyToken(token: string): boolean {
  const value = token.trim();
  if (!value) return true;
  return /replace|change-me|your-token|example|placeholder/i.test(value);
}

export function quoteDecimal(value: unknown, label: string): Prisma.Decimal {
  try {
    const decimal = new Prisma.Decimal(value as string | number);
    if (!decimal.isFinite() || decimal.lte(0)) {
      throw new Error('invalid');
    }
    return decimal.toDecimalPlaces(4, Prisma.Decimal.ROUND_HALF_UP);
  } catch {
    throw new Error(`Apify ${label} is invalid`);
  }
}

export function optionalQuoteDecimal(value: unknown): string | null {
  if (value === undefined || value === null || value === '') return null;
  try {
    return quoteDecimal(value, 'optional price').toFixed();
  } catch {
    return null;
  }
}

function firstDefined(item: ApifyDatasetItem, keys: string[]): unknown {
  for (const key of keys) {
    if (item[key] !== undefined && item[key] !== null && item[key] !== '') {
      return item[key];
    }
  }
  return undefined;
}

export function parseExchangeTimestamp(
  item: ApifyDatasetItem,
): { at: Date; confidence: QuoteTimestampConfidence } | null {
  for (const key of EXCHANGE_TIMESTAMP_KEYS) {
    if (!(key in item)) continue;
    const parsed = coerceDate(item[key]);
    if (parsed) return { at: parsed, confidence: 'EXCHANGE' };
  }

  const nested =
    (item.quote as ApifyDatasetItem | undefined) ||
    (item.market as ApifyDatasetItem | undefined);
  if (nested && typeof nested === 'object') {
    const nestedTimestamp = parseExchangeTimestamp(nested);
    if (nestedTimestamp) return nestedTimestamp;
  }

  return null;
}

export function parseReceivedAt(item: ApifyDatasetItem, fallback: Date): Date {
  for (const [key, value] of Object.entries(item)) {
    if (!INGESTION_TIMESTAMP_KEYS.has(key.toLowerCase())) continue;
    const parsed = coerceDate(value);
    if (parsed) return parsed;
  }
  return fallback;
}

function coerceDate(value: unknown): Date | null {
  if (value instanceof Date && !Number.isNaN(value.getTime())) return value;
  if (typeof value === 'number' && Number.isFinite(value)) {
    const milliseconds = value > 1_000_000_000_000 ? value : value * 1000;
    const parsed = new Date(milliseconds);
    return Number.isNaN(parsed.getTime()) ? null : parsed;
  }
  if (typeof value !== 'string' || !value.trim()) return null;
  const text = value.trim();
  const iso = new Date(text);
  if (!Number.isNaN(iso.getTime())) return iso;
  const nse = Date.parse(`${text} GMT+0530`);
  if (!Number.isNaN(nse)) return new Date(nse);
  return null;
}

export function normalizeApifyQuote(
  item: ApifyDatasetItem,
  requested: { symbol: string; exchange: string },
  receivedAt: Date,
): MarketQuoteResult {
  if (item.error) {
    throw new Error(
      `Apify quote failed for ${requested.exchange}:${requested.symbol}`,
    );
  }

  const symbol = normalizeApifySymbol(
    asText(item.symbol ?? item.ticker) || requested.symbol,
  );
  const exchange = normalizeApifyExchange(
    asText(item.exchange) || requested.exchange,
  );
  if (
    instrumentKey(exchange, symbol) !==
    instrumentKey(requested.exchange, requested.symbol)
  ) {
    throw new Error(
      `Apify quote identity mismatch for ${requested.exchange}:${requested.symbol}`,
    );
  }

  const priceValue = firstDefined(item, [
    'currentPrice',
    'lastPrice',
    'last',
    'ltp',
    'price',
  ]);
  const price = quoteDecimal(priceValue, 'lastPrice');
  const previousCloseValue = firstDefined(item, [
    'previousClose',
    'prevClose',
    'close',
  ]);
  const previousClose = previousCloseValue
    ? quoteDecimal(previousCloseValue, 'previousClose')
    : price;
  const change = previousClose.gt(0)
    ? Number(
        price
          .sub(previousClose)
          .div(previousClose)
          .mul(100)
          .toDecimalPlaces(2)
          .toFixed(),
      )
    : 0;

  const timestamp = parseExchangeTimestamp(item);
  if (!timestamp) {
    throw new Error(
      `Apify quote missing exchange timestamp for ${exchange}:${symbol}`,
    );
  }

  const volumeValue = firstDefined(item, ['volume', 'totalTradedVolume']);
  const volume =
    volumeValue === undefined || volumeValue === null
      ? '0'
      : typeof volumeValue === 'string' || typeof volumeValue === 'number'
        ? String(volumeValue)
        : '0';

  return {
    symbol,
    exchange,
    price: price.toFixed(),
    previousClose: previousClose.toFixed(),
    openPrice: optionalQuoteDecimal(firstDefined(item, ['open', 'openPrice'])),
    highPrice: optionalQuoteDecimal(
      firstDefined(item, ['high', 'highPrice', 'dayHigh']),
    ),
    lowPrice: optionalQuoteDecimal(
      firstDefined(item, ['low', 'lowPrice', 'dayLow']),
    ),
    bidPrice: optionalQuoteDecimal(firstDefined(item, ['bid', 'bidPrice'])),
    askPrice: optionalQuoteDecimal(firstDefined(item, ['ask', 'askPrice'])),
    volume,
    change,
    source: 'APIFY',
    updatedAt: timestamp.at,
    receivedAt: parseReceivedAt(item, receivedAt),
    timestampConfidence: timestamp.confidence,
  };
}

export function selectMatchingItem(
  items: ApifyDatasetItem[],
  requested: { symbol: string; exchange: string },
): ApifyDatasetItem | undefined {
  const expected = instrumentKey(requested.exchange, requested.symbol);
  return items.find((item) => {
    try {
      const symbol = asText(item.symbol ?? item.ticker);
      const exchange = asText(item.exchange) || requested.exchange;
      return instrumentKey(exchange, symbol) === expected;
    } catch {
      return false;
    }
  });
}
