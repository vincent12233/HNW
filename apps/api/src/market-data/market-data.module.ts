import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { PrismaModule } from '../prisma/prisma.module';
import { MarketSessionModule } from '../market-session/market-session.module';
import { HistoricalMarketDataService } from './historical-market-data.service';
import { MarketDataController } from './market-data.controller';
import { MarketDataHealthService } from './market-data-health.service';
import { MarketDataService } from './market-data.service';
import { NseSyncService } from './nse-sync.service';
import { IndiaStockMcpProvider } from './providers/india-stock-mcp.provider';
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
  imports: [PrismaModule, MarketSessionModule, AuthModule],
  controllers: [MarketDataController],
  providers: [
    MarketDataService,
    HistoricalMarketDataService,
    MarketDataHealthService,
    MarketDataProviderService,
    IndiaStockMcpProvider,
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
    HistoricalMarketDataService,
    MarketDataHealthService,
    MarketDataProviderService,
    QuoteIngestionService,
    StreamingMarketDataService,
  ],
})
export class MarketDataModule {}
