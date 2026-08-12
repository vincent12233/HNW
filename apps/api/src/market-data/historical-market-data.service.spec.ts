import { HistoricalMarketDataService } from './historical-market-data.service';

describe('HistoricalMarketDataService', () => {
  const service = new HistoricalMarketDataService({
    instrument: { findFirst: jest.fn() },
  } as never);

  it('maps chart ranges to intraday and daily chart intervals', () => {
    const internal = service as unknown as {
      window(range: '1D' | '1W' | '1M'): { range: string; interval: string };
    };

    expect(internal.window('1D')).toEqual({ range: '1d', interval: '5m' });
    expect(internal.window('1W')).toEqual({ range: '5d', interval: '1h' });
    expect(internal.window('1M')).toEqual({ range: '1mo', interval: '1d' });
  });
});
