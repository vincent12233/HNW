import { BadRequestException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { OtcService } from './otc.service';

describe('OtcService.saveOffer settlement price', () => {
  function buildService(prisma: Record<string, unknown>) {
    return new OtcService(prisma as never);
  }

  it('publishes the admin discount price instead of freezing lastPrice', async () => {
    const upsert = jest.fn().mockResolvedValue({
      id: 'offer-1',
      instrumentId: 'inst-1',
      price: new Prisma.Decimal('90.0000'),
      isActive: true,
      keyHashTier1: 'hash',
      keyHashTier2: null,
      keyHashTier3: null,
      transactionKeyEncrypted: 'enc',
      instrument: { id: 'inst-1', symbol: 'RELIANCE' },
    });
    const prisma = {
      instrument: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'inst-1',
          isActive: true,
          quote: {
            lastPrice: new Prisma.Decimal('100.0000'),
            asOf: new Date(),
          },
        }),
        update: jest.fn().mockResolvedValue({}),
      },
      otcOffer: { upsert },
    };
    const service = buildService(prisma);
    jest.spyOn(service as any, 'encryptKey').mockReturnValue('enc');

    const result = await service.saveOffer({
      instrumentId: 'inst-1',
      price: '90.0000',
      validFrom: new Date().toISOString(),
      validUntil: new Date(Date.now() + 86_400_000).toISOString(),
    });

    expect(upsert).toHaveBeenCalledWith(
      expect.objectContaining({
        create: expect.objectContaining({
          price: new Prisma.Decimal('90.0000'),
        }),
        update: expect.objectContaining({
          price: new Prisma.Decimal('90.0000'),
        }),
      }),
    );
    expect(result.price.toString()).toBe('90');
    expect(String(result.marketPrice)).toBe('100');
    expect(result.transactionKey).toMatch(/^\d{4}$/);
  });

  it('rejects settlement prices above the live market quote', async () => {
    const prisma = {
      instrument: {
        findUnique: jest.fn().mockResolvedValue({
          id: 'inst-1',
          isActive: true,
          quote: {
            lastPrice: new Prisma.Decimal('100.0000'),
            asOf: new Date(),
          },
        }),
      },
      otcOffer: { upsert: jest.fn() },
    };
    const service = buildService(prisma);

    await expect(
      service.saveOffer({
        instrumentId: 'inst-1',
        price: '100.0001',
        validFrom: new Date().toISOString(),
        validUntil: new Date(Date.now() + 86_400_000).toISOString(),
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.otcOffer.upsert).not.toHaveBeenCalled();
  });
});
