export type BackendRole = "ADMIN" | "MANAGER" | "BUSINESS" | "FINANCE";

const roleByPort: Record<string, BackendRole> = {
  "3002": "ADMIN",
  "3004": "MANAGER",
  "3005": "FINANCE",
  "3006": "BUSINESS",
};

export function getBackendRole(): BackendRole | undefined {
  const configured = process.env.NEXT_PUBLIC_BACKEND_ROLE?.trim().toUpperCase();
  if (configured && ["ADMIN", "MANAGER", "FINANCE", "BUSINESS"].includes(configured)) return configured as BackendRole;
  if (typeof window === "undefined") return undefined;
  return roleByPort[window.location.port];
}

export const backendRoleLabels: Record<BackendRole, string> = {
  ADMIN: "超级管理员后台",
  MANAGER: "管理员后台",
  FINANCE: "财务后台",
  BUSINESS: "业务员后台",
};
