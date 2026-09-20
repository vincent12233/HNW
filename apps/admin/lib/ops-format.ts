/** Display helpers for operations consoles. No API or ledger semantics. */

const INR = new Intl.NumberFormat("en-IN", {
  style: "currency",
  currency: "INR",
  minimumFractionDigits: 2,
  maximumFractionDigits: 2,
});

const OPS_DATE = new Intl.DateTimeFormat("zh-CN", {
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
  hour: "2-digit",
  minute: "2-digit",
  second: "2-digit",
  hour12: false,
});

export function formatInr(value?: string | number | null, empty = "—") {
  if (value == null || value === "") return empty;
  const amount = Number(value);
  if (!Number.isFinite(amount)) return empty;
  return INR.format(amount);
}

export function formatOpsDateTime(value?: string | Date | null, empty = "—") {
  if (value == null || value === "") return empty;
  const date = value instanceof Date ? value : new Date(value);
  if (Number.isNaN(date.getTime())) return empty;
  return OPS_DATE.format(date);
}

export function formatOpsId(value?: string | null, empty = "—") {
  const text = value?.trim();
  return text ? text : empty;
}

export const OPS_TABLE_PAGINATION = {
  showSizeChanger: true,
  showQuickJumper: true,
  defaultPageSize: 20,
  pageSizeOptions: ["10", "15", "20", "50"],
  showTotal: (total: number) => `共 ${total} 条`,
};

export function homePathForRole(role?: string | null) {
  return role === "MANAGER" ? "/team" : "/dashboard";
}
