import { Module } from '@nestjs/common';

import { MarketSessionModule } from '../market-session/market-session.module';
import { PrismaModule } from '../prisma/prisma.module';
import { MatchingScanService } from './matching-scan.service';
import { MatchingScheduler } from './matching.scheduler';
import { MatchingService } from './matching.service';

@Module({
  imports: [PrismaModule, MarketSessionModule],
  providers: [MatchingService, MatchingScanService, MatchingScheduler],
  exports: [MatchingService],
})
export class MatchingModule {}
