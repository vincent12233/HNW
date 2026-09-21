"use client";

export const UNAVAILABLE = "Unavailable";

function maskPhone(value: string) {
  const digits = value.replace(/\D/g, "");
  if (digits.length < 4) return "****";
  return `******${digits.slice(-4)}`;
}

function maskAccount(value: string) {
  const compact = value.replace(/\s/g, "");
  if (compact.length < 4) return "••••";
  return `••••${compact.slice(-4)}`;
}

const SENSITIVE_KEY =
  /(password|passwd|token|jwt|cookie|secret|authorization|otp|totp|apikey|api_key|accountnumber|account_number|ifsc|upi|phone|pan|aadhaar|idnumber|id_number|stack)/i;

export function governanceWorkflowForRole(role?: string | null) {
  if (role === "ADMIN") {
    return {
      auditPage: "/audit-logs",
      healthPage: "/market",
      announcementsPage: "/announcements",
      settingsPage: "/app-settings",
      canMutateContent: true,
      canDecideApprovals: true,
    };
  }
  return {
    auditPage: null,
    healthPage: role === "ADMIN" ? "/market" : null,
    announcementsPage: null,
    settingsPage: null,
    canMutateContent: false,
    canDecideApprovals: false,
  };
}

export function isSensitiveGovernanceKey(key: string) {
  return SENSITIVE_KEY.test(key.replace(/[^a-z0-9_]/gi, ""));
}

export function sanitizeGovernanceValue(key: string, value: unknown): string {
  if (value == null || value === "") return UNAVAILABLE;
  if (isSensitiveGovernanceKey(key)) {
    const text = String(value);
    if (/phone/i.test(key)) return maskPhone(text);
    if (/account/i.test(key)) return maskAccount(text);
    return "••••";
  }
  if (typeof value === "object") {
    const nested = sanitizeGovernanceMetadata(value);
    if (!nested.length) return UNAVAILABLE;
    return nested.map((item) => `${item.key}: ${item.value}`).join("; ");
  }
  return String(value);
}

export function sanitizeGovernanceMetadata(input: unknown): Array<{ key: string; value: string }> {
  if (input == null) return [];
  if (Array.isArray(input)) {
    return input.map((item, index) => ({
      key: String(index),
      value: sanitizeGovernanceValue(String(index), item),
    }));
  }
  if (typeof input !== "object") {
    return [{ key: "value", value: sanitizeGovernanceValue("value", input) }];
  }
  return Object.entries(input as Record<string, unknown>).map(([key, value]) => ({
    key,
    value: sanitizeGovernanceValue(key, value),
  }));
}

export type HealthCode = "HEALTHY" | "DEGRADED" | "UNAVAILABLE" | "UNKNOWN";

export function healthCodeFromProbe(input: {
  failed?: boolean;
  healthy?: boolean | null;
  stale?: boolean | null;
  status?: string | null;
}): HealthCode {
  if (input.failed) return "UNAVAILABLE";
  if (input.stale) return "DEGRADED";
  if (input.healthy === true || input.status === "ok" || input.status === "ready") return "HEALTHY";
  if (input.healthy === false) return "DEGRADED";
  if (!input.status) return "UNKNOWN";
  return "UNKNOWN";
}

export const GOVERNANCE_COPY = {
  auditReadOnly: "审计记录只读。不能删除、修改或重新执行。",
  loadedFilter: "姓名筛选只作用于当前页已经加载的结果，不是新的服务端权限查询。",
  healthHonest: "状态来自 /health、/health/ready 和 /market-data/health。缺失字段显示 Unavailable，不估算 uptime 或成功率。",
  noVip: "VIP 仅作为普通等级字段，本页不作为权限、资金或交易规则。",
  noReplay: "前端隐藏不替代服务端授权。",
};
