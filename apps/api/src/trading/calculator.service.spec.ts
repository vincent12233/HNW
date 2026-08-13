import { Prisma } from '../generated/prisma/client';
import { CalculatorService } from './calculator.service';

describe('CalculatorService', () => {
  const service = new CalculatorService();

  it('calculates gross and net amounts with decimal precision', () => {
    const gross = service.calculateGrossAmount(
      new Prisma.Decimal('123.4567'),
      10,
    );
    const net = service.calculateNetAmount(gross, new Prisma.Decimal('1.25'));

    expect(gross.toFixed(2)).toBe('1234.57');
    expect(net.toFixed(2)).toBe('1235.82');
  });

  it('calculates weighted average price', () => {
    const average = service.calculateAveragePrice(
      new Prisma.Decimal('100'),
      10,
      new Prisma.Decimal('120'),
      10,
    );

    expect(average.toFixed(4)).toBe('110.0000');
  });

  it('calculates realized pnl', () => {
    const pnl = service.calculateRealizedPnl(
      new Prisma.Decimal('125'),
      new Prisma.Decimal('100'),
      4,
    );

    expect(pnl.toFixed(2)).toBe('100.00');
  });
});
