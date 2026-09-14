import { BadRequestException, Injectable } from '@nestjs/common';
import { availableCash } from '../common/money';
import { OrderSide, Prisma } from '../generated/prisma/client';
import { CalculatorService } from './calculator.service';

@Injectable()
export class SettlementService {
  constructor(private readonly calculator: CalculatorService) {}

  async settleImmediateTrade(
    tx: Prisma.TransactionClient,
    params: {
      account: Prisma.AccountGetPayload<object>;
      instrument: Prisma.InstrumentGetPayload<object>;
      existingPosition: Prisma.PositionGetPayload<object> | null;
      orderId: string;
      side: OrderSide;
      quantity: number;
      fillPrice: Prisma.Decimal;
      netAmount: Prisma.Decimal;
    },
  ) {
    const {
      account,
      instrument,
      existingPosition,
      orderId,
      side,
      quantity,
      fillPrice,
      netAmount,
    } = params;

    if (
      side === OrderSide.BUY &&
      (account.buyingPower.lessThan(netAmount) ||
        availableCash(account).lessThan(netAmount))
    ) {
      throw new BadRequestException('Insufficient buying power or cash balance');
    }

    const balanceBefore = account.cashBalance;
    const updatedAccount = await tx.account.update({
      where: { id: account.id },
      data:
        side === OrderSide.BUY
          ? {
              cashBalance: { decrement: netAmount },
              buyingPower: { decrement: netAmount },
            }
          : {
              cashBalance: { increment: netAmount },
              buyingPower: { increment: netAmount },
            },
    });

    await tx.accountTransaction.create({
      data: {
        accountId: account.id,
        type: 'TRADE_SETTLEMENT',
        status: 'COMPLETED',
        amount: side === OrderSide.BUY ? netAmount.negated() : netAmount,
        balanceBefore,
        balanceAfter: updatedAccount.cashBalance,
        referenceId: `ORDER:${orderId}:SETTLEMENT`,
        note: `${side} ${quantity} ${instrument.exchange}:${instrument.symbol} at ${fillPrice.toFixed(4)}`,
      },
    });

    if (side === OrderSide.BUY) {
      const oldQuantity = existingPosition?.quantity ?? 0;
      const oldAveragePrice =
        existingPosition?.averagePrice ?? new Prisma.Decimal(0);
      const newAveragePrice = this.calculator.calculateAveragePrice(
        oldAveragePrice,
        oldQuantity,
        fillPrice,
        quantity,
      );

      await tx.position.upsert({
        where: {
          accountId_instrumentId: {
            accountId: account.id,
            instrumentId: instrument.id,
          },
        },
        create: {
          accountId: account.id,
          instrumentId: instrument.id,
          quantity,
          frozenQuantity: 0,
          averagePrice: fillPrice,
          realizedPnl: new Prisma.Decimal(0),
        },
        update: {
          quantity: { increment: quantity },
          averagePrice: newAveragePrice,
        },
      });
      return;
    }

    const position = existingPosition!;
    const newQuantity = position.quantity - quantity;
    const realizedPnl = this.calculator.calculateRealizedPnl(
      fillPrice,
      position.averagePrice,
      quantity,
    );

    await tx.position.update({
      where: { id: position.id },
      data: {
        quantity: { decrement: quantity },
        averagePrice:
          newQuantity === 0 ? new Prisma.Decimal(0) : position.averagePrice,
        realizedPnl: { increment: realizedPnl },
      },
    });
  }
}
