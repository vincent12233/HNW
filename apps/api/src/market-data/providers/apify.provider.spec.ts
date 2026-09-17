import axios from 'axios';
import { ApifyProvider } from './apify.provider';
import { normalizeApifyQuote } from './apify-quote.normalizer';
import { instrumentKey, normalizeApifyExchange } from './apify-symbol';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('Apify symbol identity', () => {
  it('normalizes NSE and BSE without guessing exchange from the ticker', () => {
    expect(normalizeApifyExchange('nse')).toBe('NSE');
    expect(normalizeApifyExchange('BSE')).toBe('BSE');
    expect(instrumentKey('NSE', 'xyz')).toBe('NSE:XYZ');
    expect(instrumentKey('BSE', 'xyz')).toBe('BSE:XYZ');
    expect(instrumentKey('NSE', 'XYZ')).not.toBe(instrumentKey('BSE', 'XYZ'));
  });

  it('rejects a missing exchange instead of inferring it', () => {
    expect(() => normalizeApifyExchange('')).toThrow(/explicit NSE or BSE/);
  });
});

describe('Apify quote normalization', () => {
  const receivedAt = new Date('2026-09-17T10:00:00Z');

  it('maps actor fields onto the shared quote contract with source APIFY', () => {
    const quote = normalizeApifyQuote(
      {
        symbol: 'RELIANCE',
        exchange: 'NSE',
        currentPrice: 2450.5,
        previousClose: 2425.2,
        open: 2430,
        high: 2460.75,
        low: 2425.1,
        bid: 2449.9,
        ask: 2450.6,
        volume: 8523410,
        lastTradedTime: '2026-09-17T09:59:40+05:30',
        scrapedAt: '2026-09-17T10:00:00.000Z',
      },
      { symbol: 'RELIANCE', exchange: 'NSE' },
      receivedAt,
    );

    expect(Number(quote.price)).toBe(2450.5);
    expect(Number(quote.previousClose)).toBe(2425.2);
    expect(Number(quote.bidPrice)).toBeCloseTo(2449.9);
    expect(Number(quote.askPrice)).toBeCloseTo(2450.6);
    expect(quote).toEqual(
      expect.objectContaining({
        symbol: 'RELIANCE',
        exchange: 'NSE',
        source: 'APIFY',
        timestampConfidence: 'EXCHANGE',
      }),
    );
    expect(quote.updatedAt.toISOString()).toBe('2026-09-17T04:29:40.000Z');
    expect(quote.receivedAt?.toISOString()).toBe('2026-09-17T10:00:00.000Z');
  });

  it('does not forge bid/ask from last price', () => {
    const quote = normalizeApifyQuote(
      {
        symbol: 'TCS',
        exchange: 'BSE',
        lastPrice: 3500,
        previousClose: 3490,
        lastUpdateTime: '2026-09-17T10:00:00Z',
      },
      { symbol: 'TCS', exchange: 'BSE' },
      receivedAt,
    );
    expect(quote.bidPrice).toBeNull();
    expect(quote.askPrice).toBeNull();
    expect(quote.exchange).toBe('BSE');
  });

  it('fails closed when the actor only returns scrape time', () => {
    expect(() =>
      normalizeApifyQuote(
        {
          symbol: 'INFY',
          exchange: 'NSE',
          currentPrice: 1500,
          scrapedAt: '2026-09-17T10:00:00.000Z',
        },
        { symbol: 'INFY', exchange: 'NSE' },
        receivedAt,
      ),
    ).toThrow(/missing exchange timestamp/);
  });

  it('rejects zero and negative prices', () => {
    expect(() =>
      normalizeApifyQuote(
        {
          symbol: 'WIPRO',
          exchange: 'NSE',
          currentPrice: 0,
          lastTradedTime: '2026-09-17T10:00:00Z',
        },
        { symbol: 'WIPRO', exchange: 'NSE' },
        receivedAt,
      ),
    ).toThrow(/lastPrice is invalid/);
    expect(() =>
      normalizeApifyQuote(
        {
          symbol: 'WIPRO',
          exchange: 'NSE',
          currentPrice: -12,
          lastTradedTime: '2026-09-17T10:00:00Z',
        },
        { symbol: 'WIPRO', exchange: 'NSE' },
        receivedAt,
      ),
    ).toThrow(/lastPrice is invalid/);
  });

  it('does not synthesize a quote from an actor error row', () => {
    expect(() =>
      normalizeApifyQuote(
        {
          symbol: 'INVALID',
          exchange: 'NSE',
          error: 'Response code 404',
          scrapedAt: '2026-09-17T10:00:00.000Z',
        },
        { symbol: 'INVALID', exchange: 'NSE' },
        receivedAt,
      ),
    ).toThrow(/quote failed/);
  });
});

describe('ApifyProvider HTTP client', () => {
  const token = 'apify_api_test_token_not_for_production';

  function provider() {
    const config = {
      get: jest.fn((key: string) => {
        if (key === 'APIFY_TOKEN') return token;
        if (key === 'APIFY_ACTOR_ID') return 'krawlify/nse-bse-stock-scraper';
        if (key === 'APIFY_API_BASE_URL') return 'https://api.apify.test';
        if (key === 'APIFY_MARKET_DATA_TIMEOUT_MS') return '50';
        return undefined;
      }),
    } as any;
    return new ApifyProvider(config);
  }

  beforeEach(() => {
    mockedAxios.isAxiosError.mockImplementation(
      (error: unknown) =>
        typeof error === 'object' &&
        error !== null &&
        'isAxiosError' in error,
    );
    mockedAxios.post.mockReset();
  });

  it('batches one actor call per exchange and preserves exchange+symbol', async () => {
    mockedAxios.post.mockResolvedValue({
      data: [
        {
          symbol: 'RELIANCE',
          exchange: 'NSE',
          currentPrice: 100,
          previousClose: 99,
          lastTradedTime: '2026-09-17T09:15:00+05:30',
        },
        {
          symbol: 'RELIANCE',
          exchange: 'BSE',
          currentPrice: 101,
          previousClose: 100,
          lastTradedTime: '2026-09-17T09:15:01+05:30',
        },
      ],
    });

    const quotes = await provider().getQuotes([
      { symbol: 'RELIANCE', exchange: 'NSE' },
      { symbol: 'RELIANCE', exchange: 'BSE' },
    ]);

    expect(mockedAxios.post).toHaveBeenCalledTimes(2);
    const bodies = mockedAxios.post.mock.calls.map((call) => call[1] as any);
    expect(bodies).toEqual(
      expect.arrayContaining([
        expect.objectContaining({ symbols: ['RELIANCE'], exchange: 'NSE' }),
        expect.objectContaining({ symbols: ['RELIANCE'], exchange: 'BSE' }),
      ]),
    );
    expect(quotes.map((quote) => `${quote.exchange}:${quote.symbol}`).sort()).toEqual(
      ['BSE:RELIANCE', 'NSE:RELIANCE'],
    );
    const payload = JSON.stringify(quotes);
    expect(payload).not.toContain(token);
    expect(payload).not.toContain('Bearer');
  });

  it('times out without synthesizing a quote', async () => {
    const timeout = {
      isAxiosError: true,
      code: 'ECONNABORTED',
      message: `timeout of 50ms exceeded token=${token}`,
    };
    mockedAxios.post.mockRejectedValue(timeout);

    await expect(
      provider().getQuotes([{ symbol: 'INFY', exchange: 'NSE' }]),
    ).rejects.toThrow(/timeout/);
  });

  it('rejects a malformed dataset payload', async () => {
    mockedAxios.post.mockResolvedValue({ data: { oops: true } });
    await expect(
      provider().getQuotes([{ symbol: 'INFY', exchange: 'NSE' }]),
    ).rejects.toThrow(/not a dataset array/);
  });

  it('skips failed symbols instead of writing a fake price', async () => {
    mockedAxios.post.mockResolvedValue({
      data: [
        {
          symbol: 'BAD',
          exchange: 'NSE',
          error: 'not found',
        },
        {
          symbol: 'GOOD',
          exchange: 'NSE',
          currentPrice: 12.5,
          previousClose: 12,
          lastUpdateTime: '2026-09-17T03:45:00Z',
        },
      ],
    });

    const quotes = await provider().getQuotes([
      { symbol: 'BAD', exchange: 'NSE' },
      { symbol: 'GOOD', exchange: 'NSE' },
    ]);
    expect(quotes).toHaveLength(1);
    expect(quotes[0].symbol).toBe('GOOD');
    expect(Number(quotes[0].price)).toBe(12.5);
  });

  it('sends the token only in the Authorization header', async () => {
    mockedAxios.post.mockResolvedValue({ data: [] });
    await provider().getQuotes([{ symbol: 'INFY', exchange: 'NSE' }]);
    const [url, body, options] = mockedAxios.post.mock.calls[0];
    expect(String(url)).not.toContain(token);
    expect(JSON.stringify(body)).not.toContain(token);
    expect((options as any).headers.Authorization).toBe(`Bearer ${token}`);
    expect(String(url)).toContain('krawlify~nse-bse-stock-scraper');
  });
});
