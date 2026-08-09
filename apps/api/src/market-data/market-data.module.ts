import { Module } from '@nestjs/common';

import { MarketDataController } from './market-data.controller';

import { MarketDataService } from './market-data.service';

import { YahooProvider } from './providers/yahoo.provider';

import { NseSyncService } from './nse-sync.service';

import { PrismaModule } from '../prisma/prisma.module';
import { MarketDataGateway } from './websocket/market-data/market-data.gateway';

@Module({
  imports: [PrismaModule],

  controllers: [MarketDataController],

  providers: [MarketDataService, YahooProvider, NseSyncService, MarketDataGateway],

  exports: [MarketDataService],
})
export class MarketDataModule {}
