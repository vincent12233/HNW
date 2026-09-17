import { MarketDataHealthService } from './market-data-health.service';

describe('MarketDataHealthService', () => {
  const config = {
    get: jest.fn((key: string) => {
      if (key === 'MARKET_DATA_STALE_AFTER_MS') return '60000';
      if (key === 'MARKET_DATA_STREAMING_ENABLED') return 'false';
      if (key === 'MARKET_DATA_PROVIDER') return 'APIFY';
      return undefined;
    }),
  } as any;

  it('starts stale before any quote is received', () => {
    const service = new MarketDataHealthService(config);

    expect(service.getStatus()).toEqual(
      expect.objectContaining({
        healthy: false,
        stale: true,
        lastQuoteAt: null,
        providerConfigured: false,
        configuredProvider: 'APIFY',
      }),
    );
  });

  it('becomes healthy after a recent quote', () => {
    const service = new MarketDataHealthService(config);
    const at = new Date();

    service.recordQuote('TRUEDATA', at);

    expect(service.getStatus()).toEqual(
      expect.objectContaining({
        healthy: true,
        stale: false,
        lastQuoteAt: at,
        lastSource: 'TRUEDATA',
        lastSuccessfulIngestionAt: expect.any(Date),
        configuredProvider: 'APIFY',
        streamingEnabled: false,
      }),
    );
  });
});
