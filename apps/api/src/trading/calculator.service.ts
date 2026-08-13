import { Injectable } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';

@Injectable()
export class CalculatorService {
  calculateGrossAmount(price: Prisma.Decimal, quantity: number) {
    return price.mul(quantity).toDecimalPlaces(2);
  }

  calculateNetAmount(grossAmount: Prisma.Decimal, fees: Prisma.Decimal) {
    return grossAmount.add(fees).toDecimalPlaces(2);
  }

  calculateAveragePrice(
    oldAveragePrice: Prisma.Decimal,
    oldQuantity: number,
    fillPrice: Prisma.Decimal,
    fillQuantity: number,
  ) {
    const newQuantity = oldQuantity + fillQuantity;
    if (newQuantity <= 0) return new Prisma.Decimal(0);

    return oldAveragePrice
      .mul(oldQuantity)
      .add(fillPrice.mul(fillQuantity))
      .div(newQuantity)
      .toDecimalPlaces(4);
  }

  calculateRealizedPnl(
    fillPrice: Prisma.Decimal,
    averagePrice: Prisma.Decimal,
    quantity: number,
  ) {
    return fillPrice.sub(averagePrice).mul(quantity).toDecimalPlaces(2);
  }
}
