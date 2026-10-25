import { MarketTimeseriesService } from './market-timeseries.service';

const tick = {
  instrumentId: 'instrument-1',
  exchange: 'NSE',
  symbol: 'RELIANCE',
  sequence: 1,
  price: 2500,
  volume: 100,
  sourceTimestamp: new Date('2026-10-25T04:00:00Z'),
  receivedAt: new Date('2026-10-25T04:00:01Z'),
  quality: 'LIVE' as const,
};

describe('MarketTimeseriesService', () => {
  it('is an optional boundary when no timeseries database is configured', () => {
    const service = new MarketTimeseriesService({ get: jest.fn() } as never);
    service.onModuleInit();
    expect(() => service.appendTick(tick)).not.toThrow();
  });

  it('buffers failed writes instead of failing the quote path', async () => {
    const service = new MarketTimeseriesService({ get: jest.fn() } as never);
    const query = jest
      .fn()
      .mockRejectedValue(new Error('timeseries unavailable'));
    (service as any).pool = { query };
    service.appendTick(tick);

    await (service as any).flush();

    expect(query).toHaveBeenCalledTimes(1);
    expect((service as any).queue).toHaveLength(1);
  });

  it('uses Asia/Kolkata boundaries for candles', async () => {
    const service = new MarketTimeseriesService({ get: jest.fn() } as never);
    const query = jest.fn().mockResolvedValue({ rows: [] });
    (service as any).pool = { query };

    await service.getCandles(
      'instrument-1',
      '5m',
      new Date('2026-10-25T03:45:00Z'),
      new Date('2026-10-25T10:00:00Z'),
    );

    expect(query.mock.calls[0][0]).toContain("'Asia/Kolkata'");
    expect(query.mock.calls[0][1][0]).toBe('5 minutes');
  });
});
