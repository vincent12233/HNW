import { Module } from '@nestjs/common';
import { MatchingModule } from '../matching/matching.module';
import { PrismaModule } from '../prisma/prisma.module';
import { AdminOrdersController } from './admin-orders.controller';
import { AdminOrdersService } from './admin-orders.service';
import { AdminTradesController } from './admin-trades.controller';
import { AdminTradesService } from './admin-trades.service';
import { OrdersController } from './orders.controller';
import { OrdersService } from './orders.service';

@Module({
  imports: [PrismaModule, MatchingModule],
  controllers: [OrdersController, AdminOrdersController, AdminTradesController],
  providers: [OrdersService, AdminOrdersService, AdminTradesService],
  exports: [OrdersService],
})
export class OrdersModule {}
