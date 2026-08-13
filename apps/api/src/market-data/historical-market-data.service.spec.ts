import axios from 'axios';
import { HistoricalMarketDataService } from './historical-market-data.service';

jest.mock('axios');
const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('HistoricalMarketDataService', () => {
  function createService(history: any[] = []) {
    const prisma = {
      instrument: {
        findFirst: jest.fn().mockResolvedValue({ symbol: 'RELIANCE', exchange: 'NSE' }),
      },
    };
    const mcp = {
      supportsHistorical: jest.fn().mockResolvedValue(true),
      getHistorical: jest.fn().mockResolvedValue(history),
    };
    return {
      service: new HistoricalMarketDataService(prisma as never, mcp as never),
      prisma,
      mcp,
    };
  }

  function mockYahoo() {
    mockedAxios.get.mockResolvedValue({
      data: {
        chart: {
          result: [{
            timestamp: [1723453200, 1723456800],
            indicators: { quote: [{
              open: [100, 101],
              high: [102, 103],
              low: [99, 100],
              close: [101, 102],
              volume: [1000, 1100],
            }] },
            events: {
              dividends: {
                '1723453200': { date: 1723453200, amount: 10 },
              },
              splits: {
                '1723456800': {
                  date: 1723456800,
                  numerator: 2,
                  denominator: 1,
                },
              },
            },
          }],
        },
      },
    } as never);
  }

  afterEach(() => jest.clearAllMocks());

  it.each([
    ['1D', '1d', '5m'],
    ['1W', '5d', '1h'],
    ['3M', '3mo', '1d'],
    ['6M', '6mo', '1d'],
    ['1Y', '1y', '1d'],
  ] as const)('loads real %s Yahoo history', async (range, providerRange, interval) => {
    const { service } = createService();
    mockYahoo();

    const result = await service.getHistory('RELIANCE', range, 'NSE');

    expect(result.interval).toBe(interval);
    expect(result.exchange).toBe('NSE');
    expect(result.timezone).toBe('Asia/Kolkata');
    expect(result.data).toHaveLength(2);
    expect(result.events).toEqual([
      expect.objectContaining({ type: 'DIVIDEND', value: 10 }),
      expect.objectContaining({ type: 'SPLIT', value: 2 }),
    ]);
    expect(mockedAxios.get).toHaveBeenCalledWith(
      expect.stringContaining('RELIANCE.NS'),
      expect.objectContaining({
        params: expect.objectContaining({ range: providerRange, interval }),
      }),
    );
  });

  it('prefers real India Stock MCP daily data for one month', async () => {
    const history = [
      { date: '2026-08-10T00:00:00Z', open: 100, high: 105, low: 99, close: 104, volume: 1000 },
      { date: '2026-08-11T00:00:00Z', open: 104, high: 106, low: 102, close: 105, volume: 1200 },
    ];
    const { service, mcp } = createService(history);

    const result = await service.getHistory('RELIANCE', '1M', 'NSE');

    expect(result.data).toEqual(history);
    expect(mcp.getHistorical).toHaveBeenCalled();
    expect(mockedAxios.get).not.toHaveBeenCalled();
  });

  it('keeps exchange-specific symbols separate', async () => {
    const { service, prisma } = createService();
    mockYahoo();

    await service.getHistory('RELIANCE', '1D', 'BSE');

    expect(prisma.instrument.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({ where: expect.objectContaining({ exchange: 'BSE' }) }),
    );
  });

  it('rejects unsupported history ranges before requesting market data', async () => {
    const { service } = createService();

    await expect(service.getHistory('RELIANCE', '2Y', 'NSE')).rejects.toThrow(
      'Range must be 1D, 1W, 1M, 3M, 6M or 1Y',
    );
    expect(mockedAxios.get).not.toHaveBeenCalled();
  });

  it('coalesces concurrent upstream requests and caches the result', async () => {
    const { service } = createService();
    mockYahoo();

    const [first, second] = await Promise.all([
      service.getHistory('RELIANCE', '1D', 'NSE'),
      service.getHistory('RELIANCE', '1D', 'NSE'),
    ]);
    const third = await service.getHistory('RELIANCE', '1D', 'NSE');

    expect(second).toEqual(first);
    expect(third).toEqual(first);
    expect(mockedAxios.get).toHaveBeenCalledTimes(1);
  });
});
