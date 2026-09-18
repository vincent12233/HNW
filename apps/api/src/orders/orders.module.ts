import { Module } from '@nestjs/common';
import { RolesGuard } from '../auth/roles.guard';
import { PrismaModule } from '../prisma/prisma.module';
import { TradingModule } from '../trading/trading.module';
import { AdminOrdersController } from './admin-orders.controller';
import { AdminOrdersService } from './admin-orders.service';
import { AdminTradesController } from './admin-trades.controller';
import { AdminTradesService } from './admin-trades.service';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';
import { TradingOrdersService } from './trading-orders.service';

@Module({
  imports: [PrismaModule, TradingModule],
  controllers: [OrdersController, AdminOrdersController, AdminTradesController],
  providers: [
    OrdersService,
    TradingOrdersService,
    AdminOrdersService,
    AdminTradesService,
    RolesGuard,
  ],
  exports: [OrdersService, TradingOrdersService],
})
export class OrdersModule {}
