import { Prisma } from '../generated/prisma/client';

/** Normalize a finite money amount to 2 decimal places without binary float drift. */
export function moneyDecimal(value: Prisma.Decimal | number | string): Prisma.Decimal {
  return new Prisma.Decimal(value).toDecimalPlaces(2, Prisma.Decimal.ROUND_HALF_UP);
}

export function assertPositiveMoney(value: Prisma.Decimal, label = 'Amount') {
  if (!value.isFinite() || value.lte(0)) {
    throw new Error(`${label} must be greater than zero`);
  }
}
