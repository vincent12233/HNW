import { BadRequestException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { availableCash, moneyDecimal } from '../common/money';

describe('OTC settlement guards', () => {
  it('rejects when frozen funds leave insufficient available cash', () => {
    const account = {
      cashBalance: new Prisma.Decimal('100.00'),
      frozenBalance: new Prisma.Decimal('80.00'),
      buyingPower: new Prisma.Decimal('100.00'),
    };
    const amount = new Prisma.Decimal('50.00');
    expect(availableCash(account).lessThan(amount)).toBe(true);
    expect(() => {
      if (
        availableCash(account).lessThan(amount) ||
        moneyDecimal(account.buyingPower).lessThan(amount)
      ) {
        throw new BadRequestException(
          'Insufficient buying power or available cash balance',
        );
      }
    }).toThrow(BadRequestException);
  });

  it('rejects when buying power is below the OTC amount', () => {
    const account = {
      cashBalance: new Prisma.Decimal('100.00'),
      frozenBalance: new Prisma.Decimal('0'),
      buyingPower: new Prisma.Decimal('20.00'),
    };
    const amount = new Prisma.Decimal('50.00');
    expect(availableCash(account).greaterThanOrEqualTo(amount)).toBe(true);
    expect(moneyDecimal(account.buyingPower).lessThan(amount)).toBe(true);
  });
});
