import { Injectable } from '@nestjs/common';
import { randomUUID } from 'crypto';
import { Prisma } from '../generated/prisma/client';
import { CreateOrderDto } from '../orders/dto/create-order.dto';
import { CalculatorService } from './calculator.service';
import { CommissionService } from './commission.service';
import { SettlementService } from './settlement.service';
import { ValidatorService } from './validator.service';

type OrderWithDetails = Prisma.OrderGetPayload<{
  include: { instrument: true; trades: true };
}>;

@Injectable()
export class TradingService {
  constructor(
    private readonly validator: ValidatorService,
    private readonly calculator: CalculatorService,
    private readonly commission: CommissionService,
    private readonly settlement: SettlementService,
  ) {}

  async executeImmediately(
    tx: Prisma.TransactionClient,
    account: Prisma.AccountGetPayload<object>,
    instrument: Prisma.InstrumentGetPayload<{ include: { quote: true } }>,
    dto: CreateOrderDto,
    clientOrderId: string,
    fillPrice: Prisma.Decimal,
  ): Promise<OrderWithDetails> {
    const grossAmount = this.calculator.calculateGrossAmount(
      fillPrice,
      dto.quantity,
    );
    const fees = this.commission.calculateFees(grossAmount);
    const netAmount = this.calculator.calculateNetAmount(grossAmount, fees);

    const existingPosition = await tx.position.findUnique({
      where: {
        accountId_instrumentId: {
          accountId: account.id,
          instrumentId: instrument.id,
        },
      },
    });

    this.validator.validateImmediateExecution(
      dto.side,
      dto.quantity,
      account,
      existingPosition,
      netAmount,
    );

    const order = await tx.order.create({
      data: {
        clientOrderId,
        accountId: account.id,
        instrumentId: instrument.id,
        side: dto.side,
        type: dto.type,
        timeInForce: dto.timeInForce,
        status: 'FILLED',
        quantity: dto.quantity,
        filledQuantity: dto.quantity,
        limitPrice:
          dto.type === 'LIMIT' ? new Prisma.Decimal(dto.limitPrice!) : null,
        averageFillPrice: fillPrice,
        frozenAmount: new Prisma.Decimal(0),
        completedAt: new Date(),
      },
    });

    await tx.trade.create({
      data: {
        executionId: `INT-${randomUUID()}`,
        orderId: order.id,
        accountId: account.id,
        instrumentId: instrument.id,
        quantity: dto.quantity,
        price: fillPrice,
        grossAmount,
        fees,
        netAmount,
      },
    });

    await this.settlement.settleImmediateTrade(tx, {
      account,
      instrument,
      existingPosition,
      orderId: order.id,
      side: dto.side,
      quantity: dto.quantity,
      fillPrice,
      netAmount,
    });

    return tx.order.findUniqueOrThrow({
      where: { id: order.id },
      include: { instrument: true, trades: true },
    });
  }
}
