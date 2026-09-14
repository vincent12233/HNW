/** Shared dedicated-operator invite code used across finance/support scoping. */
export function fixedInviteCode(): string {
  const value = process.env.ADMIN_FIXED_INVITE_CODE?.trim().toUpperCase() ?? '';
  if (process.env.NODE_ENV === 'production') {
    if (value.length < 12 || /replace|change-me|adminfixed2026/i.test(value)) {
      throw new Error(
        'ADMIN_FIXED_INVITE_CODE must be set to a strong unique value in production',
      );
    }
    return value;
  }
  return value || 'ADMINFIXED2026';
}
