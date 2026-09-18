import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { StreamingMarketDataProvider } from './streaming-market-data-provider.interface';

/**
 * Registry for optional future commercial streaming providers.
 * TrueData has been removed; no streaming provider is registered in Phase 1.
 */
@Injectable()
export class StreamingProviderRegistryService {
  constructor(private readonly config: ConfigService) {}

  get provider(): StreamingMarketDataProvider | null {
    const name = (
      this.config.get<string>('MARKET_DATA_STREAMING_PROVIDER') ?? 'NONE'
    )
      .trim()
      .toUpperCase();

    if (name === '' || name === 'NONE') return null;

    throw new Error(
      `Unsupported streaming market data provider: ${name}. No streaming provider is configured; polling via MARKET_DATA_PROVIDER remains active.`,
    );
  }

  get providerName() {
    return this.provider?.name ?? 'NONE';
  }
}
