import { ConfigService } from '@nestjs/config';
import { MarketDataService } from './market-data.service';

describe('MarketDataService', () => {
  const quote = (price: number, asOf: Date) => ({
    lastPrice: price,
    previousClose: 100,
    bidPrice: price,
    askPrice: price,
    volume: BigInt(1000),
    source: 'TEST',
    asOf,
  });

  const instrument = (id: string, symbol: string, displayOrder: number) => ({
    id,
    symbol,
    exchange: 'NSE',
    name: `${symbol} Ltd`,
    logoUrl: null,
    category: 'EQUITY',
    displayOrder,
    quote: quote(100 + displayOrder, new Date()),
  });

  function createService(rows: any[]) {
    const prisma = {
      instrument: {
        findMany: jest.fn().mockResolvedValue(rows),
        findFirst: jest.fn(),
      },
    };
    const ingestion = {
      getIndexSnapshot: jest.fn().mockReturnValue([]),
      ingest: jest.fn(),
    };
    const config = {
      get: jest.fn((key: string) =>
        key === 'MARKET_DATA_STALE_AFTER_MS' ? '60000' : undefined,
      ),
    } as unknown as ConfigService;

    return new MarketDataService(
      prisma as never,
      ingestion as never,
      config,
    );
  }

  it('omits enabled instruments that do not have a valid positive quote', async () => {
    const service = createService([
      {
        symbol: 'NOQUOTE',
        exchange: 'NSE',
        name: 'No Quote Ltd',
        logoUrl: null,
        category: 'EQUITY',
        displayOrder: 0,
        quote: null,
      },
      {
        symbol: 'ZERO',
        exchange: 'NSE',
        name: 'Zero Ltd',
        logoUrl: null,
        category: 'EQUITY',
        displayOrder: 1,
        quote: quote(0, new Date()),
      },
      {
        symbol: 'VALID',
        exchange: 'NSE',
        name: 'Valid Ltd',
        logoUrl: null,
        category: 'EQUITY',
        displayOrder: 2,
        quote: quote(101, new Date()),
      },
    ]);

    const snapshot = await service.getMarketSnapshot();

    expect(snapshot.map((item) => item.symbol)).toEqual(['VALID']);
  });

  it('marks fresh quotes and ranks them ahead of older quotes', async () => {
    const now = Date.now();
    const service = createService([
      {
        symbol: 'OLD',
        exchange: 'NSE',
        name: 'Old Quote Ltd',
        logoUrl: null,
        category: 'EQUITY',
        displayOrder: 0,
        quote: quote(100, new Date(now - 5 * 60_000)),
      },
      {
        symbol: 'FRESH',
        exchange: 'NSE',
        name: 'Fresh Quote Ltd',
        logoUrl: null,
        category: 'EQUITY',
        displayOrder: 99,
        quote: quote(101, new Date(now - 5_000)),
      },
    ]);

    const snapshot = await service.getMarketSnapshot();

    expect(snapshot.map((item) => item.symbol)).toEqual(['FRESH', 'OLD']);
    expect(snapshot[0].quoteFresh).toBe(true);
    expect(snapshot[1].quoteFresh).toBe(false);
  });

  it('merges holdings, active orders and watchlist stocks into the compact home list', async () => {
    const featured = instrument('featured', 'RELIANCE', 0);
    const holding = instrument('holding', 'SMALLCAP', 80);
    const activeOrder = instrument('order', 'ORDERSTOCK', 90);
    const watched = instrument('watched', 'WATCHED', 95);

    const prisma = {
      instrument: {
        findMany: jest.fn((args: any) => {
          if (args.where?.positions) return Promise.resolve([holding]);
          if (args.where?.orders) return Promise.resolve([activeOrder]);
          if (args.where?.symbol) return Promise.resolve([]);
          if (args.where?.id?.in) return Promise.resolve([watched]);
          return Promise.resolve([featured]);
        }),
        findFirst: jest.fn(),
      },
      $queryRaw: jest.fn().mockResolvedValue([{ instrumentId: 'watched' }]),
      $transaction: jest.fn((operations: Promise<unknown>[]) =>
        Promise.all(operations),
      ),
    };
    const ingestion = {
      getIndexSnapshot: jest.fn().mockReturnValue([]),
      ingest: jest.fn(),
    };
    const config = {
      get: jest.fn((key: string) =>
        key === 'MARKET_DATA_STALE_AFTER_MS' ? '60000' : undefined,
      ),
    } as unknown as ConfigService;
    const service = new MarketDataService(
      prisma as never,
      ingestion as never,
      config,
    );

    const snapshot = await service.getHomeBootstrap('user-1', '', 40);

    expect(snapshot.map((item) => item.symbol)).toEqual([
      'RELIANCE',
      'SMALLCAP',
      'ORDERSTOCK',
      'WATCHED',
    ]);

    expect(prisma.instrument.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          positions: {
            some: {
              quantity: { not: 0 },
              account: { userId: 'user-1' },
            },
          },
        }),
      }),
    );
    expect(prisma.instrument.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          id: { in: ['watched'] },
        }),
      }),
    );
  });
});
