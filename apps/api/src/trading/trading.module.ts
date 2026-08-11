import { Module } from '@nestjs/common';
import { MatchingModule } from '../matching/matching.module';
import { PrismaModule } from '../prisma/prisma.module';
import { CalculatorService } from './calculator.service';
import { CommissionService } from './commission.service';
import { FreezeService } from './freeze.service';
import { LimitOrderService } from './limit-order.service';
import { OrderCancellationService } from './order-cancellation.service';
import { OrderPreparationService } from './order-preparation.service';
import { OrderSubmissionService } from './order-submission.service';
import { SettlementService } from './settlement.service';
import { TradingService } from './trading.service';
import { ValidatorService } from './validator.service';

@Module({
  imports: [PrismaModule, MatchingModule],
  providers: [
    TradingService,
    ValidatorService,
    FreezeService,
    SettlementService,
    CalculatorService,
    CommissionService,
    OrderPreparationService,
    LimitOrderService,
    OrderCancellationService,
    OrderSubmissionService,
  ],
  exports: [
    TradingService,
    FreezeService,
    OrderPreparationService,
    LimitOrderService,
    OrderCancellationService,
    OrderSubmissionService,
  ],
})
export class TradingModule {}
