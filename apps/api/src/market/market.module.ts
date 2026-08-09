import { Module } from '@nestjs/common';
import { AuthModule } from '../auth/auth.module';
import { RolesGuard } from '../auth/roles.guard';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminMarketController } from './admin-market.controller';
import { MarketController } from './market.controller';
import { MarketService } from './market.service';

@Module({
  imports: [AuthModule, PrismaModule],
  controllers: [MarketController, AdminMarketController],
  providers: [MarketService, RolesGuard],
  exports: [MarketService],
})
export class MarketModule {}
