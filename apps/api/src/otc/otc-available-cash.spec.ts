import { BadRequestException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';

describe('OTC available cash guard', () => {
  it('rejects when frozen funds leave insufficient available cash', () => {
    const cashBalance = new Prisma.Decimal('100.00');
    const frozenBalance = new Prisma.Decimal('80.00');
    const amount = new Prisma.Decimal('50.00');
    const availableCash = cashBalance.sub(frozenBalance);
    expect(availableCash.lessThan(amount)).toBe(true);
    expect(() => {
      if (availableCash.lessThan(amount)) {
        throw new BadRequestException('Insufficient available cash balance');
      }
    }).toThrow(BadRequestException);
  });
});
