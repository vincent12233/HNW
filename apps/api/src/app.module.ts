import { AuditModule } from './audit/audit.module';
import { IpoModule } from './ipo/ipo.module';
import { AdminDashboardModule } from './admin-dashboard/admin-dashboard.module';
import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { join } from 'path';
import { AccountModule } from './account/account.module';
import { AppController } from './app.controller';
import { AppService } from './app.service';
import { ApprovalModule } from './approval/approval.module';
import { AuthModule } from './auth/auth.module';
import { HealthController } from './health/health.controller';
import { MarketModule } from './market/market.module';
import { MatchingModule } from './matching/matching.module';
import { OrdersModule } from './orders/orders.module';
import { PrismaModule } from './prisma/prisma.module';
import { UsersModule } from './users/users.module';
import { SupportModule } from './support/support.module';
import { DepositModule } from './deposit/deposit.module';
import { WithdrawalModule } from './withdrawal/withdrawal.module';
import { AdminModule } from './admin/admin.module';
import { BusinessModule } from './business/business.module';
import { StocksModule } from './stocks/stocks.module';
import { MarketDataModule } from './market-data/market-data.module';
import { KycModule } from './kyc/kyc.module';
import { AdminProductsModule } from './admin-products/admin-products.module';
import { LoansModule } from './loans/loans.module';
import { InstrumentMasterModule } from './instrument-master/instrument-master.module';
import { WatchlistModule } from './watchlist/watchlist.module';
import { ScheduleModule } from '@nestjs/schedule';
import { OtcModule } from './otc/otc.module';
import { ClientExperienceModule } from './client-experience/client-experience.module';
import { StorageModule } from './storage/storage.module';

@Module({
  imports: [
    ApprovalModule,
    ConfigModule.forRoot({
      isGlobal: true,
      envFilePath: join(process.cwd(), '.env'),
    }),

    ScheduleModule.forRoot(),

    PrismaModule,
    AuthModule,
    UsersModule,
    AccountModule,
    MarketModule,
    MarketDataModule,
    MatchingModule,
    OrdersModule,
    AdminDashboardModule,
    AuditModule,
    IpoModule,
    SupportModule,
    DepositModule,
    WithdrawalModule,
    AdminModule,
    BusinessModule,
    StocksModule,
    KycModule,
    AdminProductsModule,
    LoansModule,
    InstrumentMasterModule,
    WatchlistModule,
    OtcModule,
    ClientExperienceModule,
    StorageModule,
  ],
  controllers: [AppController, HealthController],
  providers: [AppService],
})
export class AppModule {}
