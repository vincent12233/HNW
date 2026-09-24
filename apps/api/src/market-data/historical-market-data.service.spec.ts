import { HistoricalMarketDataService } from './historical-market-data.service';

describe('HistoricalMarketDataService', () => {
  function createService() {
    const prisma = {
      instrument: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ symbol: 'RELIANCE', exchange: 'NSE' }),
      },
    };
    const provider = {
      getHistory: jest.fn().mockResolvedValue({
        symbol: 'RELIANCE',
        exchange: 'NSE',
        range: '1D',
        timezone: 'Asia/Kolkata',
        interval: '5m',
        data: [
          {
            date: '2026-08-12T03:40:00.000Z',
            open: 100,
            high: 102,
            low: 99,
            close: 101,
            volume: 1000,
          },
          {
            date: '2026-08-12T04:40:00.000Z',
            open: 101,
            high: 103,
            low: 100,
            close: 102,
            volume: 1100,
          },
        ],
        events: [
          {
            date: '2026-08-12T03:40:00.000Z',
            type: 'DIVIDEND',
            value: 10,
            label: 'Dividend 10.00',
          },
          {
            date: '2026-08-12T04:40:00.000Z',
            type: 'SPLIT',
            value: 2,
            label: 'Split 2:1',
          },
        ],
      }),
    };
    return {
      service: new HistoricalMarketDataService(
        prisma as never,
        provider as never,
      ),
      prisma,
      provider,
    };
  }

  afterEach(() => jest.clearAllMocks());

  it.each(['1D', '1W', '3M', '6M', '1Y', '1M'] as const)(
    'loads history for %s through the market data provider abstraction',
    async (range) => {
      const { service, provider } = createService();
      provider.getHistory.mockResolvedValue({
        symbol: 'RELIANCE',
        exchange: 'NSE',
        range,
        timezone: 'Asia/Kolkata',
        interval: range === '1D' ? '5m' : range === '1W' ? '1h' : '1d',
        data: [
          {
            date: '2026-08-12T03:40:00.000Z',
            open: 100,
            high: 102,
            low: 99,
            close: 101,
            volume: 1000,
          },
          {
            date: '2026-08-12T04:40:00.000Z',
            open: 101,
            high: 103,
            low: 100,
            close: 102,
            volume: 1100,
          },
        ],
        events: [],
      });

      const result = await service.getHistory('RELIANCE', range, 'NSE');

      expect(result.exchange).toBe('NSE');
      expect(result.timezone).toBe('Asia/Kolkata');
      expect(result.data).toHaveLength(2);
      expect(provider.getHistory).toHaveBeenCalledWith(
        'RELIANCE',
        'NSE',
        range,
      );
    },
  );

  it('keeps exchange-specific symbols separate', async () => {
    const { service, prisma } = createService();

    await service.getHistory('RELIANCE', '1D', 'BSE');

    expect(prisma.instrument.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({ exchange: 'BSE' }),
      }),
    );
  });

  it.each([
    ['NIFTY50', 'NSE'],
    ['SENSEX', 'BSE'],
    ['BANKNIFTY', 'NSE'],
    ['INDIAVIX', 'NSE'],
  ] as const)(
    'loads %s history without requiring an equity row',
    async (symbol, exchange) => {
      const { service, prisma, provider } = createService();

      await service.getHistory(symbol, '1D', exchange);

      expect(prisma.instrument.findFirst).not.toHaveBeenCalled();
      expect(provider.getHistory).toHaveBeenCalledWith(symbol, exchange, '1D');
    },
  );

  it('rejects an index on the wrong exchange', async () => {
    const { service, prisma, provider } = createService();

    await expect(service.getHistory('SENSEX', '1D', 'NSE')).rejects.toThrow(
      'Index not found on this exchange',
    );
    expect(prisma.instrument.findFirst).not.toHaveBeenCalled();
    expect(provider.getHistory).not.toHaveBeenCalled();
  });

  it('rejects unsupported history ranges before requesting market data', async () => {
    const { service, provider } = createService();

    await expect(service.getHistory('RELIANCE', '2Y', 'NSE')).rejects.toThrow(
      'Range must be 1D, 1W, 1M, 3M, 6M or 1Y',
    );
    expect(provider.getHistory).not.toHaveBeenCalled();
  });

  it('coalesces concurrent upstream requests and caches the result', async () => {
    const { service, provider } = createService();

    const [first, second] = await Promise.all([
      service.getHistory('RELIANCE', '1D', 'NSE'),
      service.getHistory('RELIANCE', '1D', 'NSE'),
    ]);
    const third = await service.getHistory('RELIANCE', '1D', 'NSE');

    expect(second).toEqual(first);
    expect(third).toEqual(first);
    expect(provider.getHistory).toHaveBeenCalledTimes(1);
  });
});
