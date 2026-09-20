export const VIP_TIER_CODES = [
  'STANDARD',
  'SILVER',
  'GOLD',
  'PLATINUM',
] as const;

export type VipTierCode = (typeof VIP_TIER_CODES)[number];

export const VIP_CONFIG_LOCK_KEY = 'hnw.vip_tier_configurations';

export type VipSuggestionStatus =
  | 'NOT_CONFIGURED'
  | 'UPGRADE'
  | 'DOWNGRADE'
  | 'KEEP'
  | 'NO_MATCH';

export type VipTierConfigSnapshot = {
  tierCode: string;
  displayName: string;
  description: string;
  minimumCumulativeDeposit: string | null;
  displayOrder: number;
  isActive: boolean;
  updatedAt: Date;
  updatedById: string | null;
};

export function isVipTierCode(value: unknown): value is VipTierCode {
  return (
    typeof value === 'string' &&
    (VIP_TIER_CODES as readonly string[]).includes(value)
  );
}

export function vipTierRank(tier: string): number {
  const index = (VIP_TIER_CODES as readonly string[]).indexOf(tier);
  return index < 0 ? 0 : index;
}
