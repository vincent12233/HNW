import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import { loadStandardQuoteEvidence } from '../health/standard-quote-evidence';

@Injectable()
export class MarketDataHealthService {
  private lastQuoteAt: Date | null = null;
  private lastSource: string | null = null;
  private lastSuccessfulIngestionAt: Date | null = null;
  private streamingProvider = 'NONE';
  private streamingConnected = false;
  private subscriptionCount = 0;
  private providerSymbolCount = 0;
  private lastConnectionError: string | null = null;

  constructor(
    private readonly config: ConfigService,
    private readonly prisma: PrismaService,
  ) {}

  recordQuote(source: string, at: Date) {
    if (!this.lastQuoteAt || at > this.lastQuoteAt) {
      this.lastQuoteAt = at;
      this.lastSource = source;
    }
    this.lastSuccessfulIngestionAt = new Date();
  }

  setStreamingStatus(
    provider: string,
    connected?: boolean,
    diagnostics?: {
      subscriptionCount?: number;
      providerSymbolCount?: number;
      lastConnectionError?: string | null;
    },
  ) {
    this.streamingProvider = provider.trim().toUpperCase() || 'NONE';
    if (connected !== undefined) {
      this.streamingConnected = connected;
    }
    if (diagnostics?.subscriptionCount !== undefined) {
      this.subscriptionCount = diagnostics.subscriptionCount;
    }
    if (diagnostics?.providerSymbolCount !== undefined) {
      this.providerSymbolCount = diagnostics.providerSymbolCount;
    }
    if (diagnostics?.lastConnectionError !== undefined) {
      this.lastConnectionError = diagnostics.lastConnectionError;
    }
  }

  getStatus() {
    const staleAfterMs = this.positiveInteger(
      this.config.get<string>('MARKET_DATA_STALE_AFTER_MS'),
      60000,
    );
    const now = Date.now();
    const ageMs = this.lastQuoteAt ? now - this.lastQuoteAt.getTime() : null;
    const stale = ageMs === null || ageMs > staleAfterMs;
    const streamingEnabled =
      (this.config.get<string>('MARKET_DATA_STREAMING_ENABLED') ?? 'false')
        .trim()
        .toLowerCase() === 'true';
    const configuredProvider = (
      this.config.get<string>('MARKET_DATA_PROVIDER') ?? 'APIFY'
    )
      .trim()
      .toUpperCase();
    const providerConfigured =
      configuredProvider !== 'APIFY' ||
      (this.hasConfiguredSecret(this.config.get<string>('APIFY_TOKEN')) &&
        this.hasConfiguredSecret(this.config.get<string>('APIFY_ACTOR_ID')));

    return {
      healthy: !stale,
      stale,
      lastQuoteAt: this.lastQuoteAt,
      lastTickAt: this.lastQuoteAt,
      lastSuccessfulIngestionAt: this.lastSuccessfulIngestionAt,
      lastSource: this.lastSource,
      ageMs,
      quoteAge: ageMs,
      staleAfterMs,
      configuredProvider,
      providerConfigured,
      streamingEnabled,
      streamingProvider: this.streamingProvider,
      streaming: {
        enabled: streamingEnabled,
        provider: this.streamingProvider,
        connected: this.streamingConnected,
        subscriptionCount: this.subscriptionCount,
        providerSymbolCount: this.providerSymbolCount,
        lastConnectionError: this.lastConnectionError,
      },
    };
  }

  async getPersistedDiagnostics(now = new Date()) {
    const staleAfterMs = this.positiveInteger(
      this.config.get<string>('MARKET_DATA_STALE_AFTER_MS'),
      60000,
    );
    try {
      const evidence = await loadStandardQuoteEvidence(this.prisma);
      const persistedQuoteAgeMs = evidence.latestAsOf
        ? now.getTime() - evidence.latestAsOf.getTime()
        : null;
      return {
        persistedLatestQuoteAt: evidence.latestAsOf,
        persistedQuoteAgeMs,
        persistedStaleAfterMs: staleAfterMs,
        activeStandardInstrumentCount: evidence.activeCount,
        quotedStandardInstrumentCount: evidence.quotedCount,
      };
    } catch {
      return {
        persistedLatestQuoteAt: null,
        persistedQuoteAgeMs: null,
        persistedStaleAfterMs: staleAfterMs,
        activeStandardInstrumentCount: null,
        quotedStandardInstrumentCount: null,
      };
    }
  }

  private hasConfiguredSecret(value: string | undefined) {
    const trimmed = value?.trim() ?? '';
    return (
      trimmed.length > 0 &&
      !/replace|change-me|your-token|example|placeholder/i.test(trimmed)
    );
  }

  private positiveInteger(value: string | undefined, fallback: number) {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
  }
}
