/** Visual status maps for operations tables. Labels only; not authorization. */

export type OpsTone = "success" | "warning" | "error" | "processing" | "default" | "info";

export type OpsStatusSpec = {
  code: string;
  label: string;
  tone: OpsTone;
};

const STATUS_MAP: Record<string, Omit<OpsStatusSpec, "code">> = {
  PENDING: { label: "待处理", tone: "warning" },
  APPROVED: { label: "已通过", tone: "success" },
  REJECTED: { label: "已拒绝", tone: "error" },
  CANCELLED: { label: "已取消", tone: "default" },
  CANCELED: { label: "已取消", tone: "default" },
  OPEN: { label: "挂单中", tone: "processing" },
  PARTIALLY_FILLED: { label: "部分成交", tone: "warning" },
  FILLED: { label: "已成交", tone: "success" },
  REJECTED_ORDER: { label: "已拒绝", tone: "error" },
  ACTIVE: { label: "有效", tone: "success" },
  SUSPENDED: { label: "已暂停", tone: "warning" },
  DISABLED: { label: "已停用", tone: "error" },
  INACTIVE: { label: "已停用", tone: "error" },
  NOT_SUBMITTED: { label: "未提交", tone: "default" },
  STANDARD: { label: "标准 Standard", tone: "default" },
  SILVER: { label: "白银 Silver", tone: "info" },
  GOLD: { label: "黄金 Gold", tone: "warning" },
  PLATINUM: { label: "铂金 Platinum", tone: "processing" },
  DRAFT: { label: "草稿", tone: "default" },
  PUBLISHED: { label: "已发布", tone: "success" },
  PAUSED: { label: "已暂停", tone: "warning" },
  ARCHIVED: { label: "已归档", tone: "default" },
  COMPLETED: { label: "已完成", tone: "success" },
  FAILED: { label: "失败", tone: "error" },
  PROCESSING: { label: "处理中", tone: "processing" },
  CONFIRMED: { label: "已确认", tone: "success" },
  SETTLED: { label: "已结算", tone: "success" },
  BUY: { label: "买入", tone: "info" },
  SELL: { label: "卖出", tone: "warning" },
};

export function opsStatusOf(code?: string | null): OpsStatusSpec {
  const value = (code ?? "").trim();
  if (!value) return { code: "", label: "—", tone: "default" };
  const mapped = STATUS_MAP[value.toUpperCase()];
  if (mapped) return { code: value.toUpperCase(), ...mapped };
  return { code: value, label: value, tone: "default" };
}

export function opsToneColor(tone: OpsTone) {
  if (tone === "success") return "success";
  if (tone === "warning") return "warning";
  if (tone === "error") return "error";
  if (tone === "processing") return "processing";
  if (tone === "info") return "blue";
  return "default";
}
