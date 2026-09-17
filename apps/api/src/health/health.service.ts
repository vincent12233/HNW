import { Injectable } from '@nestjs/common';
import { MarketDataHealthService } from '../market-data/market-data-health.service';
import { MarketSessionService } from '../market-session/market-session.service';
import { PrismaService } from '../prisma/prisma.service';
import { loadStandardQuoteEvidence } from './standard-quote-evidence';

export type TradingReadyReason =
  | 'DATABASE_UNAVAILABLE'
  | 'MARKET_CLOSED'
  | 'PROVIDER_NOT_CONFIGURED'
  | 'NO_MARKET_DATA'
  | 'MARKET_DATA_STALE';

export type TradingReadyBody = {
  status: 'ready' | 'unavailable' | 'market_closed';
  tradingReady: boolean;
  marketOpen: boolean;
  database: 'connected' | 'unavailable';
  reason?: TradingReadyReason;
  configuredProvider: string;
  providerConfigured: boolean;
  latestQuoteAt: string | null;
  quoteAgeMs: number | null;
  staleAfterMs: number;
  streamingEnabled: boolean;
  streamingProvider: string;
  streamingConnected: boolean;
  streamingWarning?: 'STREAMING_DISCONNECTED';
  activeStandardInstrumentCount?: number;
  quotedStandardInstrumentCount?: number;
  timezone: 'Asia/Kolkata';
  timestamp: string;
};

@Injectable()
export class HealthService {
  constructor(
    private readonly prisma: PrismaService,
    private readonly marketSession: MarketSessionService,
    private readonly marketDataHealth: MarketDataHealthService,
  ) {}

  async probeDatabase() {
    await this.prisma.$queryRaw`SELECT 1`;
  }

  async evaluateTradingReady(now = new Date()): Promise<{
    statusCode: number;
    body: TradingReadyBody;
  }> {
    const processHealth = this.marketDataHealth.getStatus();
    const diagnostics = {
      configuredProvider: processHealth.configuredProvider,
      providerConfigured: processHealth.providerConfigured,
      staleAfterMs: processHealth.staleAfterMs,
      streamingEnabled: processHealth.streamingEnabled,
      streamingProvider: processHealth.streamingProvider,
      streamingConnected: processHealth.streaming.connected,
      timezone: 'Asia/Kolkata' as const,
      timestamp: now.toISOString(),
      ...(processHealth.streamingEnabled && !processHealth.streaming.connected
        ? { streamingWarning: 'STREAMING_DISCONNECTED' as const }
        : {}),
    };

    try {
      await this.probeDatabase();
    } catch {
      return {
        statusCode: 503,
        body: {
          status: 'unavailable',
          tradingReady: false,
          marketOpen: this.marketSession.isNormalMarketOpen(now),
          database: 'unavailable',
          reason: 'DATABASE_UNAVAILABLE',
          latestQuoteAt: null,
          quoteAgeMs: null,
          ...diagnostics,
        },
      };
    }

    const marketOpen = this.marketSession.isNormalMarketOpen(now);
    const evidence = await loadStandardQuoteEvidence(this.prisma);
    const latestQuoteAt = evidence.latestAsOf;
    const quoteAgeMs = latestQuoteAt
      ? now.getTime() - latestQuoteAt.getTime()
      : null;
    const connected = {
      marketOpen,
      database: 'connected' as const,
      latestQuoteAt: latestQuoteAt ? latestQuoteAt.toISOString() : null,
      quoteAgeMs,
      activeStandardInstrumentCount: evidence.activeCount,
      quotedStandardInstrumentCount: evidence.quotedCount,
      ...diagnostics,
    };

    if (!marketOpen) {
      return {
        statusCode: 200,
        body: {
          status: 'market_closed',
          tradingReady: false,
          reason: 'MARKET_CLOSED',
          ...connected,
        },
      };
    }

    if (!processHealth.providerConfigured) {
      return {
        statusCode: 503,
        body: {
          status: 'unavailable',
          tradingReady: false,
          reason: 'PROVIDER_NOT_CONFIGURED',
          ...connected,
        },
      };
    }

    if (!latestQuoteAt) {
      return {
        statusCode: 503,
        body: {
          status: 'unavailable',
          tradingReady: false,
          reason: 'NO_MARKET_DATA',
          ...connected,
        },
      };
    }

    if (quoteAgeMs === null || quoteAgeMs > processHealth.staleAfterMs) {
      return {
        statusCode: 503,
        body: {
          status: 'unavailable',
          tradingReady: false,
          reason: 'MARKET_DATA_STALE',
          ...connected,
        },
      };
    }

    return {
      statusCode: 200,
      body: {
        status: 'ready',
        tradingReady: true,
        ...connected,
      },
    };
  }
}
