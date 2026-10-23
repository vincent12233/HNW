export type OpsDashboardTone =
  | "brand"
  | "success"
  | "info"
  | "warning"
  | "danger"
  | "violet";

export function formatOpsCount(value?: number | null, empty = "—"): string {
  if (value == null || !Number.isFinite(value)) return empty;
  return new Intl.NumberFormat("en-IN", { maximumFractionDigits: 0 }).format(value);
}
