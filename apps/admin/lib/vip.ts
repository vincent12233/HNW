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

export type VipClientFilters = {
  tier?: string;
  businessId?: string;
  suggestionStatus?: VipSuggestionStatus | "KEEP";
};

export type VipSummary = {
  total: number;
  byTier: Record<string, number>;
  notConfigured: number;
  upgrade: number;
  downgrade: number;
  keepCurrent: number;
};

export function isKeepSuggestion(status?: VipSuggestionStatus) {
  return status === "KEEP" || status === "NO_MATCH" || !status;
}

export function summarizeVipClients(rows: VipClientRow[]): VipSummary {
  const byTier: Record<string, number> = {
    STANDARD: 0,
    SILVER: 0,
    GOLD: 0,
    PLATINUM: 0,
  };
  let notConfigured = 0;
  let upgrade = 0;
  let downgrade = 0;
  let keepCurrent = 0;
  for (const row of rows) {
    const tier = String(row.currentTier || "STANDARD").toUpperCase();
    byTier[tier] = (byTier[tier] ?? 0) + 1;
    if (row.suggestionStatus === "NOT_CONFIGURED") notConfigured += 1;
    else if (row.suggestionStatus === "UPGRADE") upgrade += 1;
    else if (row.suggestionStatus === "DOWNGRADE") downgrade += 1;
    else keepCurrent += 1;
  }
  return { total: rows.length, byTier, notConfigured, upgrade, downgrade, keepCurrent };
}

export function filterVipClients(rows: VipClientRow[], filters: VipClientFilters) {
  return rows.filter((row) => {
    if (filters.tier && String(row.currentTier || "").toUpperCase() !== filters.tier) return false;
    if (filters.businessId && row.assignedBusiness?.id !== filters.businessId) return false;
    if (filters.suggestionStatus === "KEEP" && !isKeepSuggestion(row.suggestionStatus)) return false;
    if (
      filters.suggestionStatus &&
      filters.suggestionStatus !== "KEEP" &&
      row.suggestionStatus !== filters.suggestionStatus
    ) {
      return false;
    }
    return true;
  });
}

export function vipBusinessOptions(rows: VipClientRow[]) {
  const seen = new Map<string, string>();
  for (const row of rows) {
    if (!row.assignedBusiness?.id) continue;
    const employeeNo = row.assignedBusiness.employeeNo ? `（${row.assignedBusiness.employeeNo}）` : "";
    seen.set(row.assignedBusiness.id, `${row.assignedBusiness.fullName}${employeeNo}`);
  }
  return [...seen.entries()].map(([value, label]) => ({ value, label }));
}

export function vipBusinessBreakdown(rows: VipClientRow[]) {
  const groups = new Map<
    string,
    { id: string; name: string; clientCount: number; byTier: Record<string, number> }
  >();
  for (const row of rows) {
    const id = row.assignedBusiness?.id ?? "unassigned";
    const name = row.assignedBusiness
      ? `${row.assignedBusiness.fullName}${row.assignedBusiness.employeeNo ? ` · ${row.assignedBusiness.employeeNo}` : ""}`
      : "未分配业务员";
    const current = groups.get(id) ?? {
      id,
      name,
      clientCount: 0,
      byTier: { STANDARD: 0, SILVER: 0, GOLD: 0, PLATINUM: 0 },
    };
    const tier = String(row.currentTier || "STANDARD").toUpperCase();
    current.clientCount += 1;
    current.byTier[tier] = (current.byTier[tier] ?? 0) + 1;
    groups.set(id, current);
  }
  return [...groups.values()];
}

export function formatVipTimestamp(value?: string | null) {
  if (!value) return "—";
  const normalized = value.replace("T", " ");
  return normalized.slice(0, 19);
}
