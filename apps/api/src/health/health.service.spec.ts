import { ordinaryMarketCategoryWhere } from '../common/instrument-category';
import { MarketDataHealthService } from '../market-data/market-data-health.service';
import { MarketSessionService } from '../market-session/market-session.service';
import { HealthService } from './health.service';
import { standardMarketInstrumentWhere } from './standard-quote-evidence';

describe('HealthService trading readiness', () => {
  const openNow = new Date('2026-08-12T05:00:00.000Z');
  const closedNow = new Date('2026-08-12T10:30:00.000Z');
  const holidayNow = new Date('2026-01-26T05:00:00.000Z');

  function createService(options?: {
    dbOk?: boolean;
    latestAsOf?: Date | null;
    providerConfigured?: boolean;
    streamingEnabled?: boolean;
    streamingConnected?: boolean;
    lastQuoteAt?: Date | null;
  }) {
    const dbOk = options?.dbOk ?? true;
    const prisma = {
      $queryRaw: jest
        .fn()
        .mockImplementation(() =>
          dbOk
            ? Promise.resolve([{ '?column?': 1 }])
            : Promise.reject(
                new Error(
                  'cannot connect: postgresql://secret-user:secret-pass@db',
                ),
              ),
        ),
      marketQuote: {
        findFirst: jest
          .fn()
          .mockResolvedValue(
            options?.latestAsOf ? { asOf: options.latestAsOf } : null,
          ),
      },
      instrument: {
        count: jest.fn().mockResolvedValue(12),
      },
    };
    const marketSession = {
      isNormalMarketOpen: jest.fn((at: Date) => {
        if (at.getTime() === holidayNow.getTime()) return false;
        if (at.getTime() === closedNow.getTime()) return false;
        if (at.getTime() === openNow.getTime()) return true;
        return false;
      }),
    };
    const marketDataHealth = {
      getStatus: jest.fn().mockReturnValue({
        configuredProvider: 'YAHOO',
        providerConfigured: options?.providerConfigured ?? true,
        staleAfterMs: 60000,
        lastQuoteAt: options?.lastQuoteAt ?? null,
        lastSuccessfulIngestionAt: null,
        streamingEnabled: options?.streamingEnabled ?? false,
        streamingProvider: 'NONE',
        streaming: {
          enabled: options?.streamingEnabled ?? false,
          provider: 'NONE',
          connected: options?.streamingConnected ?? false,
        },
      }),
    };

    const service = new HealthService(
      prisma as never,
      marketSession as never,
      marketDataHealth as never,
    );
    return { service, prisma, marketSession, marketDataHealth };
  }

  it('does not treat process-memory lastQuoteAt as the trading-ready source of truth', async () => {
    const fresh = new Date(openNow.getTime() - 5_000);
    const { service, prisma } = createService({
      lastQuoteAt: null,
      latestAsOf: fresh,
      providerConfigured: true,
    });

    const result = await service.evaluateTradingReady(openNow);

    expect(result.statusCode).toBe(200);
    expect(result.body.tradingReady).toBe(true);
    expect(result.body.latestQuoteAt).toBe(fresh.toISOString());
    expect(prisma.marketQuote.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        orderBy: { asOf: 'desc' },
        select: { asOf: true },
      }),
    );
    expect(prisma.marketQuote.findFirst.mock.calls[0][0].select).toEqual({
      asOf: true,
    });
    expect(
      prisma.marketQuote.findFirst.mock.calls[0][0].select,
    ).not.toHaveProperty('updatedAt');
  });

  it('returns 503 DATABASE_UNAVAILABLE without leaking credentials', async () => {
    const { service } = createService({ dbOk: false });

    const result = await service.evaluateTradingReady(openNow);

    expect(result.statusCode).toBe(503);
    expect(result.body.reason).toBe('DATABASE_UNAVAILABLE');
    expect(result.body.tradingReady).toBe(false);
    expect(JSON.stringify(result.body)).not.toContain('secret-pass');
    expect(JSON.stringify(result.body)).not.toContain('postgresql://');
  });

  it('returns HTTP 200 MARKET_CLOSED when the IST session is shut, even if quotes are stale', async () => {
    const { service } = createService({
      latestAsOf: new Date(closedNow.getTime() - 4 * 60 * 60 * 1000),
      providerConfigured: true,
    });

    const result = await service.evaluateTradingReady(closedNow);

    expect(result.statusCode).toBe(200);
    expect(result.body.status).toBe('market_closed');
    expect(result.body.reason).toBe('MARKET_CLOSED');
    expect(result.body.tradingReady).toBe(false);
    expect(result.body.marketOpen).toBe(false);
    expect(result.body.timezone).toBe('Asia/Kolkata');
  });

  it('treats an NSE holiday in Asia/Kolkata as MARKET_CLOSED rather than stale', async () => {
    const { service } = createService({
      latestAsOf: holidayNow,
      providerConfigured: true,
    });

    const result = await service.evaluateTradingReady(holidayNow);

    expect(result.statusCode).toBe(200);
    expect(result.body.reason).toBe('MARKET_CLOSED');
  });

  it('returns 503 PROVIDER_NOT_CONFIGURED while the market is open', async () => {
    const { service } = createService({
      providerConfigured: false,
      latestAsOf: new Date(openNow.getTime() - 1000),
    });

    const result = await service.evaluateTradingReady(openNow);

    expect(result.statusCode).toBe(503);
    expect(result.body.reason).toBe('PROVIDER_NOT_CONFIGURED');
    expect(result.body.tradingReady).toBe(false);
  });

  it('returns 503 NO_MARKET_DATA when no ordinary quote exists', async () => {
    const { service } = createService({
      latestAsOf: null,
      providerConfigured: true,
    });

    const result = await service.evaluateTradingReady(openNow);

    expect(result.statusCode).toBe(503);
    expect(result.body.reason).toBe('NO_MARKET_DATA');
  });

  it('returns 503 MARKET_DATA_STALE for an old ordinary quote while the market is open', async () => {
    const { service } = createService({
      latestAsOf: new Date(openNow.getTime() - 120_000),
      providerConfigured: true,
    });

    const result = await service.evaluateTradingReady(openNow);

    expect(result.statusCode).toBe(503);
    expect(result.body.reason).toBe('MARKET_DATA_STALE');
    expect(result.body.quoteAgeMs).toBe(120_000);
    expect(result.body.staleAfterMs).toBe(60000);
  });

  it('returns 200 ready for a fresh ordinary quote during market hours', async () => {
    const { service } = createService({
      latestAsOf: new Date(openNow.getTime() - 5_000),
      providerConfigured: true,
      streamingEnabled: false,
    });

    const result = await service.evaluateTradingReady(openNow);

    expect(result.statusCode).toBe(200);
    expect(result.body.status).toBe('ready');
    expect(result.body.tradingReady).toBe(true);
    expect(result.body.marketOpen).toBe(true);
    expect(result.body.streamingEnabled).toBe(false);
  });

  it('does not fail snapshot trading readiness solely because streaming is disabled', async () => {
    const { service } = createService({
      latestAsOf: new Date(openNow.getTime() - 1_000),
      providerConfigured: true,
      streamingEnabled: false,
      streamingConnected: false,
    });

    const result = await service.evaluateTradingReady(openNow);

    expect(result.body.tradingReady).toBe(true);
    expect(result.body.streamingWarning).toBeUndefined();
  });

  it('reports a streaming warning without failing snapshot readiness', async () => {
    const { service } = createService({
      latestAsOf: new Date(openNow.getTime() - 1_000),
      providerConfigured: true,
      streamingEnabled: true,
      streamingConnected: false,
    });

    const result = await service.evaluateTradingReady(openNow);

    expect(result.statusCode).toBe(200);
    expect(result.body.tradingReady).toBe(true);
    expect(result.body.streamingWarning).toBe('STREAMING_DISCONNECTED');
  });

  it('queries ordinary-market instruments so IPO/OTC/Institutional quotes cannot prove readiness', async () => {
    const { service, prisma } = createService({
      latestAsOf: null,
      providerConfigured: true,
    });

    await service.evaluateTradingReady(openNow);

    expect(prisma.marketQuote.findFirst).toHaveBeenCalledWith(
      expect.objectContaining({
        where: expect.objectContaining({
          instrument: expect.objectContaining({
            AND: [ordinaryMarketCategoryWhere()],
          }),
        }),
      }),
    );
    expect(standardMarketInstrumentWhere().AND).toEqual([
      ordinaryMarketCategoryWhere(),
    ]);
  });
});

describe('HealthService IST session integration', () => {
  it('reuses MarketSessionService Asia/Kolkata open/close rules', async () => {
    const config = {
      get: jest.fn((key: string) => {
        if (key === 'MARKET_OPEN_TIME_IST') return '09:15';
        if (key === 'MARKET_CLOSE_TIME_IST') return '15:30';
        if (key === 'MARKET_DATA_STALE_AFTER_MS') return '60000';
        if (key === 'MARKET_DATA_PROVIDER') return 'YAHOO';
        if (key === 'MARKET_DATA_PROVIDER_TOKEN') return 'live-token-value-not-for-clients';
        if (key === 'MARKET_DATA_PROVIDER_ID') return 'actor-id';
        if (key === 'MARKET_DATA_STREAMING_ENABLED') return 'false';
        return undefined;
      }),
    } as any;
    const prisma = {
      $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
      marketQuote: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ asOf: new Date('2026-08-12T03:44:30.000Z') }),
      },
      instrument: { count: jest.fn().mockResolvedValue(8) },
    };
    const service = new HealthService(
      prisma as never,
      new MarketSessionService(config),
      new MarketDataHealthService(config, prisma as never),
    );

    const open = await service.evaluateTradingReady(
      new Date('2026-08-12T03:45:00.000Z'),
    );
    const closed = await service.evaluateTradingReady(
      new Date('2026-08-12T10:00:00.000Z'),
    );
    const weekend = await service.evaluateTradingReady(
      new Date('2026-08-16T05:00:00.000Z'),
    );

    expect(open.statusCode).toBe(200);
    expect(open.body.tradingReady).toBe(true);
    expect(open.body.timezone).toBe('Asia/Kolkata');
    expect(JSON.stringify(open.body)).not.toContain(
      'live-token-value-not-for-clients',
    );
    expect(closed.statusCode).toBe(200);
    expect(closed.body.reason).toBe('MARKET_CLOSED');
    expect(weekend.body.reason).toBe('MARKET_CLOSED');
  });

  it('fails open-market readiness when the provider is unsupported', async () => {
    const config = {
      get: jest.fn((key: string) => {
        if (key === 'MARKET_OPEN_TIME_IST') return '09:15';
        if (key === 'MARKET_CLOSE_TIME_IST') return '15:30';
        if (key === 'MARKET_DATA_STALE_AFTER_MS') return '60000';
        if (key === 'MARKET_DATA_PROVIDER') return 'UNSUPPORTED';
        if (key === 'MARKET_DATA_STREAMING_ENABLED') return 'false';
        return undefined;
      }),
    } as any;
    const prisma = {
      $queryRaw: jest.fn().mockResolvedValue([{ '?column?': 1 }]),
      marketQuote: {
        findFirst: jest
          .fn()
          .mockResolvedValue({ asOf: new Date('2026-08-12T03:44:30.000Z') }),
      },
      instrument: { count: jest.fn().mockResolvedValue(8) },
    };
    const service = new HealthService(
      prisma as never,
      new MarketSessionService(config),
      new MarketDataHealthService(config, prisma as never),
    );

    const result = await service.evaluateTradingReady(
      new Date('2026-08-12T03:45:00.000Z'),
    );

    expect(result.statusCode).toBe(503);
    expect(result.body.reason).toBe('PROVIDER_NOT_CONFIGURED');
    expect(result.body.providerConfigured).toBe(false);
  });
});
