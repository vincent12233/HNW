import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class MarketDataHealthService {
  private lastQuoteAt: Date | null = null;
  private lastSource: string | null = null;

  constructor(private readonly config: ConfigService) {}

  recordQuote(source: string, at: Date) {
    if (!this.lastQuoteAt || at > this.lastQuoteAt) {
      this.lastQuoteAt = at;
      this.lastSource = source;
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

    return {
      healthy: !stale,
      stale,
      lastQuoteAt: this.lastQuoteAt,
      lastSource: this.lastSource,
      ageMs,
      staleAfterMs,
    };
  }

  private positiveInteger(value: string | undefined, fallback: number) {
    const parsed = Number(value);
    return Number.isInteger(parsed) && parsed > 0 ? parsed : fallback;
  }
}
