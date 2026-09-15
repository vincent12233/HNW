import {
  BadRequestException,
  ConflictException,
  NotFoundException,
} from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';
import { IpoService } from './ipo.service';

describe('IpoService.updatePricing', () => {
  function buildService(prisma: Record<string, unknown>) {
    return new IpoService(prisma as never);
  }

  const baseIpo = {
    id: 'ipo-1',
    symbol: 'VALIANTLAB',
    status: 'PUBLISHED',
    issuePrice: new Prisma.Decimal('100.00'),
    openDate: new Date('2026-10-01T00:00:00.000Z'),
    closeDate: new Date('2026-10-10T00:00:00.000Z'),
    _count: { applications: 0 },
  };

  it('updates issuePrice when PUBLISHED with zero applications', async () => {
    const update = jest.fn().mockResolvedValue({
      ...baseIpo,
      issuePrice: new Prisma.Decimal('95.50'),
    });
    const prisma = {
      ipo: {
        findUnique: jest.fn().mockResolvedValue(baseIpo),
        update,
      },
    };
    const service = buildService(prisma);

    const result = await service.updatePricing('ipo-1', {
      issuePrice: '95.50',
    });

    expect(update).toHaveBeenCalledWith(
      expect.objectContaining({
        data: expect.objectContaining({
          issuePrice: expect.any(Prisma.Decimal),
        }),
      }),
    );
    expect(result.ipo.issuePrice).toBe('95.50');
  });

  it('allows DRAFT updates even if applicationCount is somehow non-zero gate uses DRAFT', async () => {
    const draft = {
      ...baseIpo,
      status: 'DRAFT',
      _count: { applications: 0 },
    };
    const update = jest.fn().mockResolvedValue({
      ...draft,
      issuePrice: new Prisma.Decimal('88.00'),
    });
    const prisma = {
      ipo: {
        findUnique: jest.fn().mockResolvedValue(draft),
        update,
      },
    };
    const service = buildService(prisma);

    await service.updatePricing('ipo-1', { issuePrice: '88.00' });
    expect(update).toHaveBeenCalled();
  });

  it('rejects pricing edits after applications exist', async () => {
    const prisma = {
      ipo: {
        findUnique: jest.fn().mockResolvedValue({
          ...baseIpo,
          _count: { applications: 2 },
        }),
        update: jest.fn(),
      },
    };
    const service = buildService(prisma);

    await expect(
      service.updatePricing('ipo-1', { issuePrice: '90.00' }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(prisma.ipo.update).not.toHaveBeenCalled();
  });

  it('rejects pricing edits after LISTED', async () => {
    const prisma = {
      ipo: {
        findUnique: jest.fn().mockResolvedValue({
          ...baseIpo,
          status: 'LISTED',
          _count: { applications: 0 },
        }),
        update: jest.fn(),
      },
    };
    const service = buildService(prisma);

    await expect(
      service.updatePricing('ipo-1', { issuePrice: '90.00' }),
    ).rejects.toBeInstanceOf(ConflictException);
    expect(prisma.ipo.update).not.toHaveBeenCalled();
  });

  it('rejects inverted offer window', async () => {
    const prisma = {
      ipo: {
        findUnique: jest.fn().mockResolvedValue(baseIpo),
        update: jest.fn(),
      },
    };
    const service = buildService(prisma);

    await expect(
      service.updatePricing('ipo-1', {
        openDate: '2026-10-10T00:00:00.000Z',
        closeDate: '2026-10-01T00:00:00.000Z',
      }),
    ).rejects.toBeInstanceOf(BadRequestException);
    expect(prisma.ipo.update).not.toHaveBeenCalled();
  });

  it('rejects unknown IPO', async () => {
    const prisma = {
      ipo: {
        findUnique: jest.fn().mockResolvedValue(null),
        update: jest.fn(),
      },
    };
    const service = buildService(prisma);

    await expect(
      service.updatePricing('missing', { issuePrice: '90.00' }),
    ).rejects.toBeInstanceOf(NotFoundException);
  });
});
