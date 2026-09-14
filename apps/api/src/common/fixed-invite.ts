/** Shared dedicated-operator invite code used across finance/support scoping. */
export function fixedInviteCode(): string {
  return process.env.ADMIN_FIXED_INVITE_CODE?.trim().toUpperCase() || 'ADMINFIXED2026';
}
