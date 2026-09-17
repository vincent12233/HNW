import { ConfigService } from '@nestjs/config';
import { ordinaryMarketCategoryWhere } from '../common/instrument-category';
import { MarketDataService } from './market-data.service';

describe('ordinary market-data snapshot isolation', () => {
  const quote = (price: number) => ({
    lastPrice: price,
    previousClose: 100,
    bidPrice: price,
    askPrice: price,
    volume: BigInt(1000),
    source: 'TEST',
    asOf: new Date(),
  });

  function instrument(
    symbol: string,
    category: string | null,
    extras: Record<string, unknown> = {},
  ) {
    return {
      id: symbol,
      symbol,
      exchange: 'NSE',
      name: `${symbol} Ltd`,
      logoUrl: null,
      isin: null,
      category,
      displayOrder: 0,
      quote: quote(101),
      ...extras,
    };
  }

  function createService() {
    const prisma = {
      instrument: {
        findMany: jest.fn(),
        findFirst: jest.fn(),
        count: jest.fn(),
      },
      $queryRaw: jest.fn().mockResolvedValue([]),
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
    return {
      service: new MarketDataService(
        prisma as never,
        ingestion as never,
        config,
      ),
      prisma,
    };
  }

  it('asks ordinary snapshot queries to exclude special product categories', async () => {
    const { service, prisma } = createService();
    prisma.instrument.findMany.mockResolvedValue([
      instrument('RELIANCE', 'EQUITY'),
    ]);

    await service.getMarketSnapshot();

    expect(prisma.instrument.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          AND: [ordinaryMarketCategoryWhere()],
        }),
      }),
    );
  });

  it('fails closed if a featured IPO/OTC/Institutional row is returned by the database', async () => {
    const { service, prisma } = createService();
    prisma.instrument.findMany.mockResolvedValue([
      instrument('RELIANCE', 'EQUITY', { featuredHome: true }),
      instrument('NIFTYBEES', 'ETF'),
      instrument('IPOCO', 'IPO', { featuredHome: true }),
      instrument('OTCCO', 'otc', { featuredMarkets: true }),
      instrument('INSTCO', 'INSTITUTIONAL', { displayOrder: -1 }),
      instrument('SECTOR', 'IPO INDUSTRIES'),
    ]);

    const snapshot = await service.getMarketSnapshot();
    expect(snapshot.map((item) => item.symbol).sort()).toEqual([
      'NIFTYBEES',
      'RELIANCE',
      'SECTOR',
    ]);
  });

  it('excludes special products from ordinary search while keeping equity and ETF', async () => {
    const { service, prisma } = createService();
    prisma.instrument.count.mockResolvedValue(2);
    prisma.instrument.findMany.mockResolvedValue([
      instrument('RELIANCE', 'EQUITY'),
      instrument('NIFTYBEES', 'ETF'),
      instrument('IPOCO', 'IpO'),
    ]);

    const result = await service.searchMarketSnapshot('CO', 1, 50);

    expect(prisma.instrument.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          AND: [ordinaryMarketCategoryWhere()],
        }),
      }),
    );
    expect(result.data.map((item) => item.symbol).sort()).toEqual([
      'NIFTYBEES',
      'RELIANCE',
    ]);
  });

  it('does not apply ordinary isolation to dedicated institutional offers', async () => {
    const { service, prisma } = createService();
    prisma.adminWatchlistItem = {
      findMany: jest.fn().mockResolvedValue([
        {
          id: 'offer-1',
          symbol: 'INSTCO',
          market: 'NSE',
          expectedReturn: null,
          status: 'ACTIVE',
        },
      ]),
    };
    prisma.instrument.findMany.mockResolvedValue([
      instrument('INSTCO', 'INSTITUTIONAL'),
    ]);

    const offers = await service.getInstitutionalOffers();

    expect(offers).toHaveLength(1);
    expect(offers[0].symbol).toBe('INSTCO');
    expect(prisma.instrument.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.not.objectContaining({
          AND: [ordinaryMarketCategoryWhere()],
        }),
      }),
    );
  });
});
