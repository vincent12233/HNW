import { ConfigService } from '@nestjs/config';
import { Prisma } from '../generated/prisma/client';
import { MarketDataService } from './market-data.service';

describe('MarketDataService institutional offers', () => {
  function buildService(prisma: {
    adminWatchlistItem: { findMany: jest.Mock };
    instrument: { findMany: jest.Mock };
  }) {
    const config = {
      get: jest.fn(() => 120000),
    } as unknown as ConfigService;
    return new MarketDataService(
      prisma as never,
      { getIndexSnapshot: jest.fn(), ingest: jest.fn() } as never,
      config,
    );
  }

  it('always settles institutional offers at the live lastPrice', async () => {
    const prisma = {
      adminWatchlistItem: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'w1',
            symbol: 'RELIANCE',
            market: 'NSE',
            status: 'ACTIVE',
            referencePrice: new Prisma.Decimal('100.00'),
            expectedReturn: new Prisma.Decimal('5.00'),
          },
        ]),
      },
      instrument: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'i1',
            symbol: 'RELIANCE',
            exchange: 'NSE',
            name: 'Reliance Industries',
            quote: {
              lastPrice: new Prisma.Decimal('250.50'),
              asOf: new Date(),
            },
          },
        ]),
      },
    };
    const service = buildService(prisma);

    const offers = await service.getInstitutionalOffers();
    expect(offers).toHaveLength(1);
    expect(offers[0].price).toBe('250.5000');
    expect(offers[0].marketPrice).toBe('250.5000');
    expect(offers[0].referencePrice).toBe('100.0000');
    expect(offers[0].expectedReturn).toBe('5.00');
    expect(offers[0].instrumentId).toBe('i1');
  });

  it('does not fall back to referencePrice when the live quote is missing', async () => {
    const prisma = {
      adminWatchlistItem: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'w2',
            symbol: 'INFY',
            market: 'NSE',
            status: 'ACTIVE',
            referencePrice: new Prisma.Decimal('99.00'),
            expectedReturn: null,
          },
        ]),
      },
      instrument: {
        findMany: jest.fn().mockResolvedValue([
          {
            id: 'i2',
            symbol: 'INFY',
            exchange: 'NSE',
            name: 'Infosys',
            quote: null,
          },
        ]),
      },
    };
    const service = buildService(prisma);

    const offers = await service.getInstitutionalOffers();
    expect(offers).toHaveLength(1);
    expect(offers[0].price).toBe('0');
    expect(offers[0].marketPrice).toBe('0');
    expect(offers[0].referencePrice).toBe('99.0000');
    expect(offers[0].quoteFresh).toBe(false);
  });
});
