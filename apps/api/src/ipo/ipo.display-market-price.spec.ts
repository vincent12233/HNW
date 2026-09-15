import { IpoService } from './ipo.service';
import { Prisma } from '../generated/prisma/client';

describe('IpoService display market price', () => {
  const service = Object.create(IpoService.prototype) as IpoService;

  it('mirrors issuePrice before listing (display only)', () => {
    const price = (service as any).resolveDisplayMarketPrice({
      status: 'PUBLISHED',
      issuePrice: new Prisma.Decimal('100.50'),
      instrument: { quote: { lastPrice: new Prisma.Decimal('150.00') } },
    });
    expect(price).toBe('100.50');
  });

  it('uses live quote after LISTED for display difference only', () => {
    const price = (service as any).resolveDisplayMarketPrice({
      status: 'LISTED',
      issuePrice: new Prisma.Decimal('100.50'),
      instrument: { quote: { lastPrice: new Prisma.Decimal('150.00') } },
    });
    expect(price).toBe('150.00');
  });

  it('falls back to issuePrice when listed but quote is missing', () => {
    const price = (service as any).resolveDisplayMarketPrice({
      status: 'LISTED',
      issuePrice: new Prisma.Decimal('100.50'),
      instrument: { quote: null },
    });
    expect(price).toBe('100.50');
  });
});
