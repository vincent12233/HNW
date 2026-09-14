-- Remove residual self-serve deposit receiving accounts (support-led funding only).
DROP INDEX IF EXISTS "deposit_receiving_accounts_isActive_sortOrder_idx";
DROP TABLE IF EXISTS "deposit_receiving_accounts";
