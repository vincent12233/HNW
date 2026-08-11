import { BadRequestException } from '@nestjs/common';
import { OrderSide, Prisma } from '../generated/prisma/client';
import { ValidatorService } from './validator.service';

describe('ValidatorService', () => {
  const service = new ValidatorService();

  const account = {
    buyingPower: new Prisma.Decimal('1000'),
    cashBalance: new Prisma.Decimal('1000'),
  } as any;

  it('accepts a funded buy', () => {
    expect(() =>
      service.validateImmediateExecution(
        OrderSide.BUY,
        1,
        account,
        null,
        new Prisma.Decimal('500'),
      ),
    ).not.toThrow();
  });

  it('rejects an underfunded buy', () => {
    expect(() =>
      service.validateImmediateExecution(
        OrderSide.BUY,
        1,
        account,
        null,
        new Prisma.Decimal('1500'),
      ),
    ).toThrow(BadRequestException);
  });

  it('rejects a sell above available quantity', () => {
    const position = {
      quantity: 10,
      frozenQuantity: 4,
    } as any;

    expect(() =>
      service.validateImmediateExecution(
        OrderSide.SELL,
        7,
        account,
        position,
        new Prisma.Decimal('0'),
      ),
    ).toThrow(BadRequestException);
  });
});
