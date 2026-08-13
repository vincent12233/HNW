import { Injectable } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { StreamingMarketDataProvider } from './streaming-market-data-provider.interface';
import { TrueDataProvider } from './truedata.provider';

@Injectable()
export class StreamingProviderRegistryService {
  constructor(
    private readonly config: ConfigService,
    private readonly trueData: TrueDataProvider,
  ) {}

  get provider(): StreamingMarketDataProvider | null {
    const name = (
      this.config.get<string>('MARKET_DATA_STREAMING_PROVIDER') ?? 'NONE'
    )
      .trim()
      .toUpperCase();

    if (name === '' || name === 'NONE') return null;
    if (name === 'TRUEDATA') return this.trueData;

    throw new Error(`Unsupported streaming market data provider: ${name}`);
  }

  get providerName() {
    return this.provider?.name ?? 'NONE';
  }
}
