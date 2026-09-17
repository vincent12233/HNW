import { Module } from '@nestjs/common';
import { MarketDataModule } from '../market-data/market-data.module';
import { MarketSessionModule } from '../market-session/market-session.module';
import { PrismaModule } from '../prisma/prisma.module';
import { HealthController } from './health.controller';
import { HealthService } from './health.service';

@Module({
  imports: [PrismaModule, MarketSessionModule, MarketDataModule],
  controllers: [HealthController],
  providers: [HealthService],
  exports: [HealthService],
})
export class HealthModule {}
