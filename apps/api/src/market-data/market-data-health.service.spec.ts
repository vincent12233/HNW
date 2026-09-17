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

  const prisma = {
    marketQuote: { findFirst: jest.fn().mockResolvedValue(null) },
    instrument: { count: jest.fn().mockResolvedValue(0) },
  };

  it('starts stale before any quote is received', () => {
    const service = new MarketDataHealthService(config, prisma as never);

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
    const service = new MarketDataHealthService(config, prisma as never);
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

  it('adds persisted quote diagnostics from MarketQuote.asOf without replacing process fields', async () => {
    const asOf = new Date('2026-08-12T05:00:00.000Z');
    prisma.marketQuote.findFirst.mockResolvedValue({ asOf });
    prisma.instrument.count.mockResolvedValueOnce(40).mockResolvedValueOnce(18);
    const service = new MarketDataHealthService(config, prisma as never);
    service.recordQuote('APIFY', new Date('2026-08-12T04:59:00.000Z'));

    const persisted = await service.getPersistedDiagnostics(
      new Date('2026-08-12T05:00:05.000Z'),
    );
    const status = service.getStatus();

    expect(status.lastQuoteAt).toEqual(new Date('2026-08-12T04:59:00.000Z'));
    expect(persisted.persistedLatestQuoteAt).toEqual(asOf);
    expect(persisted.persistedQuoteAgeMs).toBe(5000);
    expect(prisma.marketQuote.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        select: { asOf: true },
        orderBy: { asOf: 'desc' },
      }),
    );
  });
});
