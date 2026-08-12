import axios from 'axios';
import { HistoricalMarketDataService } from './historical-market-data.service';

jest.mock('axios');

const mockedAxios = axios as jest.Mocked<typeof axios>;

describe('HistoricalMarketDataService', () => {
  function createService(options?: {
    instrument?: { symbol: string; exchange: string };
    supportsHistorical?: boolean;
    history?: Array<{
      date: string;
      open: number;
      high: number;
      low: number;
      close: number;
      volume: number;
    }>;
  }) {
    const prisma = {
      instrument: {
        findFirst: jest.fn().mockResolvedValue(
          options?.instrument ?? { symbol: 'RELIANCE', exchange: 'NSE' },
        ),
      },
    };
    const indiaStockMcp = {
      supportsHistorical: jest
        .fn()
        .mockResolvedValue(options?.supportsHistorical ?? true),
      getHistorical: jest.fn().mockResolvedValue(options?.history ?? []),
    };

    return {
      service: new HistoricalMarketDataService(
        prisma as never,
        indiaStockMcp as never,
      ),
      prisma,
      indiaStockMcp,
    };
  }

  afterEach(() => {
    jest.clearAllMocks();
  });

  it('maps chart ranges to intraday and daily chart intervals', () => {
    const { service } = createService();
    const internal = service as unknown as {
      window(range: '1D' | '1W' | '1M'): { range: string; interval: string };
    };

    expect(internal.window('1D')).toEqual({ range: '1d', interval: '5m' });
    expect(internal.window('1W')).toEqual({ range: '5d', interval: '1h' });
    expect(internal.window('1M')).toEqual({ range: '1mo', interval: '1d' });
  });

  it('prefers India Stock MCP daily history for NSE multi-day ranges', async () => {
    const history = [
      {
        date: '2026-08-10T00:00:00.000Z',
        open: 100,
        high: 105,
        low: 99,
        close: 104,
        volume: 1000,
      },
      {
        date: '2026-08-11T00:00:00.000Z',
        open: 104,
        high: 106,
        low: 102,
        close: 105,
        volume: 1200,
      },
    ];
    const { service, indiaStockMcp } = createService({ history });

    const result = await service.getHistory('RELIANCE', '1W');

    expect(result.interval).toBe('1d');
    expect(result.data).toEqual(history);
    expect(indiaStockMcp.supportsHistorical).toHaveBeenCalledTimes(1);
    expect(indiaStockMcp.getHistorical).toHaveBeenCalledWith(
      'RELIANCE',
      expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/),
      expect.stringMatching(/^\d{4}-\d{2}-\d{2}$/),
      '1d',
    );
    expect(mockedAxios.get).not.toHaveBeenCalled();
  });

  it('keeps 1D on the intraday provider instead of reducing it to one daily candle', async () => {
    const { service, indiaStockMcp } = createService();
    mockedAxios.get.mockResolvedValue({
      data: {
        chart: {
          result: [
            {
              timestamp: [1723453200, 1723453500],
              indicators: {
                quote: [
                  {
                    open: [100, 101],
                    high: [102, 103],
                    low: [99, 100],
                    close: [101, 102],
                    volume: [1000, 1100],
                  },
                ],
              },
            },
          ],
        },
      },
    } as never);

    const result = await service.getHistory('RELIANCE', '1D');

    expect(result.interval).toBe('5m');
    expect(result.data).toHaveLength(2);
    expect(indiaStockMcp.supportsHistorical).not.toHaveBeenCalled();
    expect(indiaStockMcp.getHistorical).not.toHaveBeenCalled();
    expect(mockedAxios.get).toHaveBeenCalledTimes(1);
  });

  it('falls back when MCP history is unavailable or too short', async () => {
    const { service } = createService({ history: [] });
    mockedAxios.get.mockResolvedValue({
      data: {
        chart: {
          result: [
            {
              timestamp: [1723453200, 1723539600],
              indicators: {
                quote: [
                  {
                    open: [100, 102],
                    high: [103, 104],
                    low: [99, 101],
                    close: [102, 103],
                    volume: [1000, 1200],
                  },
                ],
              },
            },
          ],
        },
      },
    } as never);

    const result = await service.getHistory('RELIANCE', '1M');

    expect(result.interval).toBe('1d');
    expect(result.data).toHaveLength(2);
    expect(mockedAxios.get).toHaveBeenCalledTimes(1);
  });
});
