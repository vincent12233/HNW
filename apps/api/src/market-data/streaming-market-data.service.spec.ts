import { StreamingMarketDataService } from './streaming-market-data.service';

describe('StreamingMarketDataService', () => {
  it('does not connect when streaming is disabled', async () => {
    const config = { get: jest.fn().mockReturnValue('false') } as any;
    const prisma = {} as any;
    const ingestion = {} as any;
    const registry = { provider: null } as any;
    const service = new StreamingMarketDataService(
      config,
      prisma,
      ingestion,
      registry,
    );

    await service.onModuleInit();
    expect(config.get).toHaveBeenCalledWith('MARKET_DATA_STREAMING_ENABLED');
  });

  it('stages active instruments before connecting when enabled', async () => {
    const quoteHandlers: Array<(quote: any) => void> = [];
    const callOrder: string[] = [];
    const provider = {
      name: 'TEST_STREAM',
      connect: jest.fn(async () => callOrder.push('connect')),
      disconnect: jest.fn(),
      subscribe: jest.fn(async () => callOrder.push('subscribe')),
      onQuote: jest.fn((handler: (quote: any) => void) => quoteHandlers.push(handler)),
    } as any;
    const config = {
      get: jest.fn((key: string) =>
        key === 'MARKET_DATA_STREAMING_ENABLED' ? 'true' : undefined,
      ),
    } as any;
    const prisma = {
      instrument: {
        findMany: jest.fn().mockResolvedValue([
          { symbol: 'RELIANCE', exchange: 'NSE' },
          { symbol: 'TCS', exchange: 'NSE' },
        ]),
      },
    } as any;
    const ingestion = { ingest: jest.fn().mockResolvedValue(undefined) } as any;
    const registry = { provider } as any;
    const service = new StreamingMarketDataService(
      config,
      prisma,
      ingestion,
      registry,
    );

    await service.onModuleInit();

    expect(callOrder).toEqual(['subscribe', 'connect']);
    expect(provider.subscribe).toHaveBeenCalledWith([
      { symbol: 'RELIANCE', exchange: 'NSE' },
      { symbol: 'TCS', exchange: 'NSE' },
    ]);

    quoteHandlers[0]({ symbol: 'RELIANCE', exchange: 'NSE' });
    await Promise.resolve();
    expect(ingestion.ingest).toHaveBeenCalledWith(
      'NSE',
      expect.objectContaining({ symbol: 'RELIANCE' }),
      'STOCK',
    );
  });
});
