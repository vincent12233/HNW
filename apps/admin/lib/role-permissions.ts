import type { BackendRole } from './backend-role';

export type AdminPermission =
  | 'customers.read'
  | 'customers.write'
  | 'kyc.review'
  | 'funds.read'
  | 'funds.write'
  | 'withdrawals.review'
  | 'orders.read'
  | 'products.write'
  | 'cms.write'
  | 'audit.read'
  | 'team.manage';

export const rolePermissions: Record<BackendRole, readonly AdminPermission[]> = {
  ADMIN: [
    'customers.read', 'customers.write', 'kyc.review', 'funds.read', 'funds.write',
    'withdrawals.review', 'orders.read', 'products.write', 'cms.write', 'audit.read', 'team.manage',
  ],
  MANAGER: ['customers.read', 'kyc.review', 'funds.read', 'orders.read'],
  BUSINESS: ['customers.read', 'kyc.review', 'funds.read', 'orders.read'],
  FINANCE: ['customers.read', 'funds.read', 'funds.write', 'withdrawals.review', 'orders.read'],
  SUPPORT: ['customers.read', 'funds.read', 'orders.read'],
};

const routePermissions: Array<[string, AdminPermission]> = [
  ['/app-content', 'cms.write'],
  ['/audit-logs', 'audit.read'],
  ['/team', 'customers.read'],
  ['/team-assignments', 'team.manage'],
  ['/business-kyc', 'kyc.review'],
  ['/deposits', 'funds.write'],
  ['/withdrawals', 'withdrawals.review'],
  ['/orders', 'orders.read'],
  ['/trades', 'orders.read'],
  ['/instruments', 'products.write'],
  ['/ipo-management', 'products.write'],
  ['/block-trades', 'products.write'],
];

export function hasAdminPermission(role: BackendRole, permission: AdminPermission) {
  return rolePermissions[role].includes(permission);
}

export function permissionForAdminRoute(pathname: string): AdminPermission | undefined {
  return routePermissions.find(([route]) => pathname === route || pathname.startsWith(`${route}/`))?.[1];
}