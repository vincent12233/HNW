import { BadRequestException, Injectable } from '@nestjs/common';
import { OrderSide, Prisma } from '../generated/prisma/client';

@Injectable()
export class ValidatorService {
  validateImmediateExecution(
    side: OrderSide,
    quantity: number,
    account: Prisma.AccountGetPayload<object>,
    existingPosition: Prisma.PositionGetPayload<object> | null,
    netAmount: Prisma.Decimal,
  ) {
    if (side === OrderSide.BUY) {
      if (
        account.buyingPower.lessThan(netAmount) ||
        account.cashBalance.lessThan(netAmount)
      ) {
        throw new BadRequestException('Insufficient buying power');
      }
      return;
    }

    const availableQuantity = existingPosition
      ? existingPosition.quantity - existingPosition.frozenQuantity
      : 0;

    if (availableQuantity < quantity) {
      throw new BadRequestException('Insufficient available position');
    }
  }
}
