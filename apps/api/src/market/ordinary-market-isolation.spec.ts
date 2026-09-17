import { NotFoundException } from '@nestjs/common';
import { ordinaryMarketCategoryWhere } from '../common/instrument-category';
import { MarketService } from './market.service';

describe('ordinary public market catalog isolation', () => {
  const quote = {
    lastPrice: '100',
    previousClose: '99',
    openPrice: '99',
    highPrice: '101',
    lowPrice: '98',
    bidPrice: '99.9',
    askPrice: '100.1',
    volume: BigInt(1),
    asOf: new Date(),
    source: 'TEST',
  };

  function row(overrides: Record<string, unknown>) {
    return {
      id: 'id',
      exchange: 'NSE',
      symbol: 'SYM',
      name: 'Name',
      logoUrl: null,
      category: 'EQUITY',
      type: 'EQUITY',
      displayOrder: 0,
      featuredHome: false,
      featuredMarkets: false,
      isActive: true,
      quote,
      ...overrides,
    };
  }

  function createService(rows: any[]) {
    const prisma = {
      instrument: {
        findMany: jest.fn().mockResolvedValue(rows),
        findUnique: jest.fn(),
      },
    };
    return {
      service: new MarketService(
        prisma as never,
        { createLog: jest.fn() } as never,
      ),
      prisma,
    };
  }

  it('excludes featured IPO / OTC / Institutional rows from ordinary Home and Markets lists', async () => {
    const { service, prisma } = createService([
      row({
        id: 'eq',
        symbol: 'RELIANCE',
        category: 'EQUITY',
        featuredHome: true,
        featuredMarkets: true,
      }),
      row({
        id: 'etf',
        symbol: 'NIFTYBEES',
        category: 'ETF',
        type: 'ETF',
        featuredHome: true,
      }),
      row({
        id: 'ipo',
        symbol: 'IPOCO',
        category: 'IPO',
        featuredHome: true,
        displayOrder: 0,
      }),
      row({
        id: 'otc',
        symbol: 'OTCCO',
        category: 'OTC',
        featuredMarkets: true,
      }),
      row({
        id: 'inst',
        symbol: 'INSTCO',
        category: 'INSTITUTIONAL',
        displayOrder: -100,
      }),
    ]);

    const listed = await service.listInstruments({
      featuredHome: true,
      type: 'EQUITY' as never,
      limit: 40,
    });

    expect(prisma.instrument.findMany).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          isActive: true,
          featuredHome: true,
          AND: [ordinaryMarketCategoryWhere()],
        }),
      }),
    );
    expect(listed.data.map((item) => item.symbol)).toEqual([
      'RELIANCE',
      'NIFTYBEES',
    ]);
  });

  it('returns 404 for ordinary stock detail and quote of special products', async () => {
    const { service, prisma } = createService([]);
    prisma.instrument.findUnique.mockResolvedValue(
      row({ symbol: 'IPOCO', category: 'ipo', isActive: true }),
    );

    await expect(
      service.getInstrument('NSE' as never, 'IPOCO'),
    ).rejects.toBeInstanceOf(NotFoundException);
    await expect(
      service.getQuote('NSE' as never, 'IPOCO'),
    ).rejects.toBeInstanceOf(NotFoundException);
  });

  it('still returns ordinary equity detail when category is null', async () => {
    const { service, prisma } = createService([]);
    prisma.instrument.findUnique.mockResolvedValue(
      row({ symbol: 'RELIANCE', category: null, isActive: true }),
    );

    const instrument = await service.getInstrument('NSE' as never, 'RELIANCE');
    expect(instrument.symbol).toBe('RELIANCE');
  });
});
