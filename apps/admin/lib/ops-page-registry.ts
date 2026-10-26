import type { BackendRole } from "./backend-role";
import type { AdminPermission } from "./role-permissions";

export type OpsPageRegistration = {
  route: string;
  title: string;
  owner: string;
  roles: readonly BackendRole[];
  permission: AdminPermission;
  apiDependencies: readonly string[];
  readOnly: boolean;
};

export const opsPageRegistry: readonly OpsPageRegistration[] = [
  {
    route: "/reconciliation",
    title: "财务对账",
    owner: "Financial Operations",
    roles: ["ADMIN"],
    permission: "audit.read",
    apiDependencies: ["/admin/reconciliation"],
    readOnly: true,
  },
  {
    route: "/system-health",
    title: "系统健康",
    owner: "Platform Operations",
    roles: ["ADMIN"],
    permission: "audit.read",
    apiDependencies: [
      "/health",
      "/health/ready",
      "/market-data/health",
      "/market-data/session",
    ],
    readOnly: true,
  },
  {
    route: "/system-governance",
    title: "系统治理",
    owner: "Security & Governance",
    roles: ["ADMIN"],
    permission: "audit.read",
    apiDependencies: ["/admin/audit-logs"],
    readOnly: true,
  },
  {
    route: "/system-deployments",
    title: "部署状态",
    owner: "Release Engineering",
    roles: ["ADMIN"],
    permission: "audit.read",
    apiDependencies: ["/health/version"],
    readOnly: true,
  },
] as const;

export function opsPageForRoute(route: string) {
  return opsPageRegistry.find(
    (page) => route === page.route || route.startsWith(`${page.route}/`),
  );
}

export function opsPagesForRole(role: BackendRole) {
  return opsPageRegistry.filter((page) => page.roles.includes(role));
}
