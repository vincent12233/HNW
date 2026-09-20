export const VIP_TIERS = [
  { value: "STANDARD", label: "标准 Standard" },
  { value: "SILVER", label: "白银 Silver" },
  { value: "GOLD", label: "黄金 Gold" },
  { value: "PLATINUM", label: "铂金 Platinum" },
] as const;

export type VipSuggestionStatus =
  | "NOT_CONFIGURED"
  | "UPGRADE"
  | "DOWNGRADE"
  | "KEEP"
  | "NO_MATCH";

export type VipClientRow = {
  userId: string;
  clientId?: string | null;
  displayName: string;
  maskedPhone?: string | null;
  assignedBusiness?: { id: string; fullName: string; employeeNo?: string | null } | null;
  currentTier: string;
  cumulativeConfirmedDeposit: string;
  suggestedTier?: string | null;
  suggestionStatus: VipSuggestionStatus;
  suggestionReason?: string;
  configurationAsOf?: string | null;
  lastTierChangedAt?: string | null;
};

export type VipHistoryRow = {
  id: string;
  previousTier: string;
  newTier: string;
  reason: string;
  source: string;
  suggestedTierAtChange?: string | null;
  cumulativeDepositAtChange: string;
  createdAt?: string;
  changedAt?: string;
  changedBy?: { id: string; fullName?: string | null; role?: string | null } | null;
  userId?: string;
  clientId?: string | null;
  displayName?: string;
  maskedPhone?: string | null;
};

export function vipTierLabel(code?: string | null) {
  if (!code) return "未配置";
  return VIP_TIERS.find((item) => item.value === code)?.label ?? code;
}

export function suggestionLabel(status?: VipSuggestionStatus) {
  if (status === "UPGRADE") return "建议升级";
  if (status === "DOWNGRADE") return "建议降级";
  if (status === "NOT_CONFIGURED") return "未配置";
  return "保持当前";
}

export function suggestionColor(status?: VipSuggestionStatus) {
  if (status === "UPGRADE") return "gold";
  if (status === "DOWNGRADE") return "orange";
  if (status === "NOT_CONFIGURED") return "default";
  return "blue";
}
