import { Prisma } from '../generated/prisma/client';
import {
  suggestVipTier,
  assertStrictlyIncreasingActiveThresholds,
} from './vip-recommendation';

function config(
  tierCode: string,
  displayOrder: number,
  minimum: string | null,
  isActive = true,
) {
  return {
    tierCode,
    displayOrder,
    isActive,
    minimumCumulativeDeposit: minimum,
    updatedAt: new Date('2026-09-19T00:00:00.000Z'),
  };
}

describe('VIP recommendation', () => {
  it('stays unconfigured when every active threshold is empty', () => {
    const result = suggestVipTier(
      [
        config('STANDARD', 1, null),
        config('SILVER', 2, null),
        config('GOLD', 3, null),
        config('PLATINUM', 4, null),
      ],
      new Prisma.Decimal('1000000.00'),
      'STANDARD',
    );
    expect(result).toMatchObject({
      suggestedTier: null,
      suggestionStatus: 'NOT_CONFIGURED',
    });
  });

  it('treats zero as a real threshold rather than unconfigured', () => {
    const result = suggestVipTier(
      [
        config('STANDARD', 1, null),
        config('SILVER', 2, '0.00'),
        config('GOLD', 3, '100.00'),
      ],
      new Prisma.Decimal('0.00'),
      'STANDARD',
    );
    expect(result.suggestedTier).toBe('SILVER');
    expect(result.suggestionStatus).toBe('UPGRADE');
  });

  it('selects the highest active threshold that the deposit meets', () => {
    const configs = [
      config('STANDARD', 1, null),
      config('SILVER', 2, '10000.00'),
      config('GOLD', 3, '50000.00'),
      config('PLATINUM', 4, '100000.00'),
    ];
    expect(
      suggestVipTier(configs, new Prisma.Decimal('9999.99'), 'STANDARD')
        .suggestedTier,
    ).toBe('STANDARD');
    expect(
      suggestVipTier(configs, new Prisma.Decimal('10000.00'), 'STANDARD')
        .suggestedTier,
    ).toBe('SILVER');
    expect(
      suggestVipTier(configs, new Prisma.Decimal('50000.00'), 'SILVER')
        .suggestedTier,
    ).toBe('GOLD');
    expect(
      suggestVipTier(configs, new Prisma.Decimal('100000.01'), 'GOLD')
        .suggestedTier,
    ).toBe('PLATINUM');
  });

  it('ignores disabled tiers even when the amount would qualify', () => {
    const result = suggestVipTier(
      [
        config('STANDARD', 1, null),
        config('SILVER', 2, '10000.00'),
        config('GOLD', 3, '50000.00', false),
        config('PLATINUM', 4, '100000.00'),
      ],
      new Prisma.Decimal('80000.00'),
      'STANDARD',
    );
    expect(result.suggestedTier).toBe('SILVER');
  });

  it('reports a downgrade without writing a new current tier', () => {
    const result = suggestVipTier(
      [
        config('STANDARD', 1, null),
        config('SILVER', 2, '10000.00'),
        config('GOLD', 3, '50000.00'),
      ],
      new Prisma.Decimal('10000.00'),
      'GOLD',
    );
    expect(result).toMatchObject({
      suggestedTier: 'SILVER',
      suggestionStatus: 'DOWNGRADE',
    });
  });

  it('keeps the current tier when it already matches the suggestion', () => {
    const result = suggestVipTier(
      [
        config('STANDARD', 1, null),
        config('SILVER', 2, '10000.00'),
      ],
      new Prisma.Decimal('15000.00'),
      'SILVER',
    );
    expect(result.suggestionStatus).toBe('KEEP');
  });

  it('rejects duplicate or non-increasing active thresholds', () => {
    expect(() =>
      assertStrictlyIncreasingActiveThresholds([
        config('SILVER', 2, '10000.00'),
        config('GOLD', 3, '10000.00'),
      ]),
    ).toThrow(/strictly/);
    expect(() =>
      assertStrictlyIncreasingActiveThresholds([
        config('SILVER', 2, '20000.00'),
        config('GOLD', 3, '10000.00'),
      ]),
    ).toThrow(/strictly/);
    expect(() =>
      assertStrictlyIncreasingActiveThresholds([
        config('SILVER', 2, '10000.00'),
        config('GOLD', 3, '20000.00'),
      ]),
    ).not.toThrow();
  });
});
