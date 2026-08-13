import { Module } from '@nestjs/common';
import { MarketSessionService } from './market-session.service';

@Module({
  providers: [MarketSessionService],
  exports: [MarketSessionService],
})
export class MarketSessionModule {}
