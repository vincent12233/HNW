import { StreamingMarketDataService } from './streaming-market-data.service';

describe('StreamingMarketDataService', () => {
  const health = () => ({ setStreamingStatus: jest.fn() }) as any;

  it('does not connect when streaming is disabled', async () => {
    const config = { get: jest.fn().mockReturnValue('false') } as any;
    const healthService = health();
    const service = new StreamingMarketDataService(
      config,
      {} as any,
      {} as any,
      { provider: null } as any,
      healthService,
    );

    await service.onModuleInit();
    expect(healthService.setStreamingStatus).toHaveBeenCalledWith(
      'NONE',
      false,
      expect.objectContaining({
        subscriptionCount: 0,
        providerSymbolCount: 0,
        lastConnectionError: null,
      }),
    );
  });

  it('publishes subscription diagnostics when enabled', async () => {
    const provider = {
      name: 'TEST_STREAM',
      providerSymbolCount: 2,
      connect: jest.fn().mockResolvedValue(undefined),
      disconnect: jest.fn(),
      subscribe: jest.fn().mockResolvedValue(undefined),
      onQuote: jest.fn(),
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
    const healthService = health();
    const service = new StreamingMarketDataService(
      config,
      prisma,
      { ingest: jest.fn() } as any,
      { provider } as any,
      healthService,
    );

    await service.onModuleInit();

    expect(healthService.setStreamingStatus).toHaveBeenLastCalledWith(
      'TEST_STREAM',
      true,
      expect.objectContaining({
        subscriptionCount: 2,
        providerSymbolCount: 2,
        lastConnectionError: null,
      }),
    );
  });

  it('stores the last connection error when initial streaming connection fails', async () => {
    const provider = {
      name: 'TRUEDATA',
      providerSymbolCount: 1,
      connect: jest
        .fn()
        .mockRejectedValue(new Error('TRUEDATA_USER is required')),
      disconnect: jest.fn(),
      subscribe: jest.fn().mockResolvedValue(undefined),
      onQuote: jest.fn(),
    } as any;
    const config = {
      get: jest.fn((key: string) =>
        key === 'MARKET_DATA_STREAMING_ENABLED' ? 'true' : undefined,
      ),
    } as any;
    const prisma = {
      instrument: {
        findMany: jest
          .fn()
          .mockResolvedValue([{ symbol: 'RELIANCE', exchange: 'NSE' }]),
      },
    } as any;
    const healthService = health();
    const service = new StreamingMarketDataService(
      config,
      prisma,
      { ingest: jest.fn() } as any,
      { provider } as any,
      healthService,
    );

    await expect(service.onModuleInit()).rejects.toThrow(
      'TRUEDATA_USER is required',
    );
    expect(healthService.setStreamingStatus).toHaveBeenLastCalledWith(
      'TRUEDATA',
      false,
      expect.objectContaining({
        providerSymbolCount: 1,
        lastConnectionError: 'TRUEDATA_USER is required',
      }),
    );
  });

  it('fails module startup when streaming is enabled without a provider', async () => {
    const config = {
      get: jest.fn((key: string) =>
        key === 'MARKET_DATA_STREAMING_ENABLED' ? 'true' : undefined,
      ),
    } as any;
    const service = new StreamingMarketDataService(
      config,
      {} as any,
      {} as any,
      { provider: null } as any,
      health(),
    );

    await expect(service.onModuleInit()).rejects.toThrow(
      'Streaming market data is enabled but no streaming provider is configured',
    );
  });
});
