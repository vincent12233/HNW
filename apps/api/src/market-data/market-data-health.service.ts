import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class MarketDataHealthService {
  private lastQuoteAt: Date | null = null;
  private lastSource: string | null = null;
  private streamingProvider = 'NONE';
  private streamingConnected = false;
  private subscriptionCount = 0;
  private providerSymbolCount = 0;
  private lastConnectionError: string | null = null;

  constructor(private readonly config: ConfigService) {}

  recordQuote(source: string, at: Date) {
    if (!this.lastQuoteAt || at > this.lastQuoteAt) {
      this.lastQuoteAt = at;
      this.lastSource = source;
    }
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

    return {
      healthy: !stale,
      stale,
      lastQuoteAt: this.lastQuoteAt,
      lastTickAt: this.lastQuoteAt,
      lastSource: this.lastSource,
      ageMs,
      staleAfterMs,
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

  private positiveInteger(value: string | undefined, fallback: number) {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
  }
}
