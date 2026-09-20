import { Prisma } from '../generated/prisma/client';
import { moneyDecimal } from '../common/money';
import {
  type VipSuggestionStatus,
  type VipTierCode,
  vipTierRank,
} from './vip.constants';

export type VipConfigRow = {
  tierCode: string;
  isActive: boolean;
  displayOrder: number;
  minimumCumulativeDeposit: Prisma.Decimal | string | number | null;
  updatedAt: Date;
};

export type VipSuggestion = {
  suggestedTier: VipTierCode | null;
  suggestionStatus: VipSuggestionStatus;
  suggestionReason: string;
  configurationAsOf: string | null;
};

function asMoney(
  value: Prisma.Decimal | string | number | null | undefined,
): Prisma.Decimal | null {
  if (value == null) return null;
  return moneyDecimal(value);
}

export function hasConfiguredThresholds(configs: VipConfigRow[]): boolean {
  return configs.some(
    (row) => row.isActive && asMoney(row.minimumCumulativeDeposit) != null,
  );
}

/**
 * Highest active tier whose non-null threshold is <= cumulative deposit.
 * STANDARD with a null threshold is the floor only after at least one
 * other active threshold exists. Disabled tiers never win.
 */
export function suggestVipTier(
  configs: VipConfigRow[],
  cumulativeDeposit: Prisma.Decimal,
  currentTier: string,
): VipSuggestion {
  const asOf = configs.reduce<Date | null>((latest, row) => {
    if (!latest || row.updatedAt > latest) return row.updatedAt;
    return latest;
  }, null);
  const configurationAsOf = asOf ? asOf.toISOString() : null;

  if (!hasConfiguredThresholds(configs)) {
    return {
      suggestedTier: null,
      suggestionStatus: 'NOT_CONFIGURED',
      suggestionReason: 'VIP deposit thresholds are not configured',
      configurationAsOf,
    };
  }

  const amount = moneyDecimal(cumulativeDeposit);
  const eligible = configs.filter((row) => {
    if (!row.isActive) return false;
    const minimum = asMoney(row.minimumCumulativeDeposit);
    if (minimum == null) return row.tierCode === 'STANDARD';
    return minimum.lte(amount);
  });

  if (!eligible.length) {
    return {
      suggestedTier: null,
      suggestionStatus: 'NO_MATCH',
      suggestionReason:
        'Confirmed deposits are below every configured active threshold',
      configurationAsOf,
    };
  }

  eligible.sort((left, right) => right.displayOrder - left.displayOrder);
  const suggestedTier = eligible[0].tierCode as VipTierCode;
  const currentRank = vipTierRank(currentTier);
  const suggestedRank = vipTierRank(suggestedTier);
  let suggestionStatus: VipSuggestionStatus = 'KEEP';
  let suggestionReason = 'Suggested tier matches the current membership';
  if (suggestedRank > currentRank) {
    suggestionStatus = 'UPGRADE';
    suggestionReason =
      'Confirmed deposits reach a higher configured membership threshold';
  } else if (suggestedRank < currentRank) {
    suggestionStatus = 'DOWNGRADE';
    suggestionReason =
      'Confirmed deposits are below the current membership threshold';
  }

  return {
    suggestedTier,
    suggestionStatus,
    suggestionReason,
    configurationAsOf,
  };
}

export function assertStrictlyIncreasingActiveThresholds(
  configs: VipConfigRow[],
) {
  const active = configs
    .filter(
      (row) => row.isActive && asMoney(row.minimumCumulativeDeposit) != null,
    )
    .sort((left, right) => left.displayOrder - right.displayOrder);
  for (let index = 1; index < active.length; index += 1) {
    const previous = asMoney(active[index - 1].minimumCumulativeDeposit)!;
    const current = asMoney(active[index].minimumCumulativeDeposit)!;
    if (current.lte(previous)) {
      throw new Error(
        'Active VIP thresholds must increase strictly with display order',
      );
    }
  }
}
