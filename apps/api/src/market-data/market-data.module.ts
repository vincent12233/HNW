import { Module } from '@nestjs/common';
import { PrismaModule } from '../prisma/prisma.module';
import { MarketDataController } from './market-data.controller';
import { MarketDataHealthService } from './market-data-health.service';
import { MarketDataService } from './market-data.service';
import { NseSyncService } from './nse-sync.service';
import { MarketDataProviderService } from './providers/market-data-provider.service';
import { StreamingProviderRegistryService } from './providers/streaming-provider-registry.service';
import { TrueDataNodeTransportService } from './providers/truedata-node-transport.service';
import { TrueDataProvider } from './providers/truedata.provider';
import { TrueDataSubscriptionPolicyService } from './providers/truedata-subscription-policy.service';
import { TrueDataSymbolMapperService } from './providers/truedata-symbol-mapper.service';
import { TrueDataTickNormalizerService } from './providers/truedata-tick-normalizer.service';
import { YahooProvider } from './providers/yahoo.provider';
import { QuoteIngestionService } from './quote-ingestion.service';
import { StreamingMarketDataService } from './streaming-market-data.service';
import { MarketDataGateway } from './websocket/market-data/market-data.gateway';

@Module({
  imports: [PrismaModule],
  controllers: [MarketDataController],
  providers: [
    MarketDataService,
    MarketDataHealthService,
    MarketDataProviderService,
    StreamingProviderRegistryService,
    TrueDataSymbolMapperService,
    TrueDataTickNormalizerService,
    TrueDataSubscriptionPolicyService,
    TrueDataNodeTransportService,
    TrueDataProvider,
    YahooProvider,
    QuoteIngestionService,
    StreamingMarketDataService,
    NseSyncService,
    MarketDataGateway,
  ],
  exports: [
    MarketDataService,
    MarketDataHealthService,
    MarketDataProviderService,
    QuoteIngestionService,
    StreamingMarketDataService,
  ],
})
export class MarketDataModule {}
