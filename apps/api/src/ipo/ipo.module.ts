import { Module } from '@nestjs/common';
import { ClientIpoController } from './client-ipo.controller';
import { PrismaModule } from '../prisma/prisma.module';
import { AuthModule } from '../auth/auth.module';
import { RolesGuard } from '../auth/roles.guard';
import { MarketDataModule } from '../market-data/market-data.module';

import { IpoService } from './ipo.service';
import { AdminIpoController } from './admin-ipo.controller';
import { IpoListingService } from './ipo-listing.service';

@Module({
  imports: [PrismaModule, AuthModule, MarketDataModule],
  providers: [IpoService, IpoListingService, RolesGuard],
  controllers: [AdminIpoController, ClientIpoController],
  exports: [IpoService],
})
export class IpoModule {}
