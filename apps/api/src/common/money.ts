import { BadRequestException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';

/** Normalize a finite money amount to 2 decimal places without binary float drift. */
export function moneyDecimal(
  value: Prisma.Decimal | number | string,
): Prisma.Decimal {
  return new Prisma.Decimal(value).toDecimalPlaces(
    2,
    Prisma.Decimal.ROUND_HALF_UP,
  );
}

export function assertPositiveMoney(value: Prisma.Decimal, label = 'Amount') {
  if (!value.isFinite() || value.lte(0)) {
    throw new BadRequestException(`${label} must be greater than zero`);
  }
}

/** Cash that is not reserved by withdrawals/orders. */
export function availableCash(account: {
  cashBalance: Prisma.Decimal | number | string;
  frozenBalance?: Prisma.Decimal | number | string | null;
}): Prisma.Decimal {
  const cash = moneyDecimal(account.cashBalance);
  const frozen = moneyDecimal(account.frozenBalance ?? 0);
  const available = cash.sub(frozen);
  return available.gt(0) ? available : new Prisma.Decimal(0);
}

export function assertAtMostTwoDecimals(
  value: Prisma.Decimal | number | string,
  label = 'Amount',
) {
  try {
    const decimal = new Prisma.Decimal(value);
    if (!decimal.isFinite() || !decimal.equals(decimal.toDecimalPlaces(2))) {
      throw new BadRequestException(
        `${label} cannot have more than two decimal places`,
      );
    }
  } catch (error) {
    if (error instanceof BadRequestException) throw error;
    throw new BadRequestException(`${label} is invalid`);
  }
}
