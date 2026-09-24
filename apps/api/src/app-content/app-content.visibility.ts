import { AppContentModule } from '../generated/prisma/enums';

/**
 * SUPPORT desk-only keys used by the admin support console.
 * Must never appear on the public client content bundle.
 */
export const ADMIN_ONLY_SUPPORT_KEYS = new Set([
  'tags',
  'quick_reply.deposit',
  'quick_reply.withdrawal',
  'quick_reply.kyc',
  'quick_reply.general',
]);

/** Stale / unused by current Flutter — keep in DB & admin list API, hide from primary Admin forms. */
export const DEPRECATED_CONTENT_KEYS: ReadonlyArray<{
  module: AppContentModule;
  key: string;
  reason: string;
}> = [
  {
    module: AppContentModule.HOME,
    key: 'funds.available_label',
    reason: 'Flutter Home no longer reads this key (Phase 10 STALE_CANDIDATE)',
  },
];

export function isAdminOnlySupportKey(key: string): boolean {
  return ADMIN_ONLY_SUPPORT_KEYS.has(key);
}

export function isDeprecatedContentKey(
  module: AppContentModule | string,
  key: string,
): boolean {
  return DEPRECATED_CONTENT_KEYS.some(
    (row) => row.module === module && row.key === key,
  );
}
