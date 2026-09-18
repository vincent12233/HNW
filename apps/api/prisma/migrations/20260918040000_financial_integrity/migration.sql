-- Ledger idempotency key (nullable unique; multiple NULLs allowed).
ALTER TABLE "account_transactions" ADD COLUMN IF NOT EXISTS "idempotencyKey" TEXT;

-- Backfill only when referenceId is globally unique and not multi-payment IPO repayments.
UPDATE "account_transactions" AS t
SET "idempotencyKey" = t."referenceId"
WHERE t."referenceId" IS NOT NULL
  AND t."idempotencyKey" IS NULL
  AND t."type" <> 'IPO_REPAYMENT'
  AND (
    SELECT COUNT(*)
    FROM "account_transactions" AS other
    WHERE other."referenceId" = t."referenceId"
  ) = 1;

CREATE UNIQUE INDEX IF NOT EXISTS "account_transactions_idempotencyKey_key"
ON "account_transactions"("idempotencyKey");

-- Account financial invariants (fail migration if existing rows violate).
ALTER TABLE "accounts" DROP CONSTRAINT IF EXISTS "accounts_cash_nonneg";
ALTER TABLE "accounts" DROP CONSTRAINT IF EXISTS "accounts_buying_power_nonneg";
ALTER TABLE "accounts" DROP CONSTRAINT IF EXISTS "accounts_frozen_nonneg";
ALTER TABLE "accounts" DROP CONSTRAINT IF EXISTS "accounts_cash_covers_frozen";
ALTER TABLE "accounts"
  ADD CONSTRAINT "accounts_cash_nonneg" CHECK ("cashBalance" >= 0),
  ADD CONSTRAINT "accounts_buying_power_nonneg" CHECK ("buyingPower" >= 0),
  ADD CONSTRAINT "accounts_frozen_nonneg" CHECK ("frozenBalance" >= 0),
  ADD CONSTRAINT "accounts_cash_covers_frozen" CHECK ("cashBalance" >= "frozenBalance");

ALTER TABLE "positions" DROP CONSTRAINT IF EXISTS "positions_quantity_nonneg";
ALTER TABLE "positions" DROP CONSTRAINT IF EXISTS "positions_frozen_quantity_nonneg";
ALTER TABLE "positions" DROP CONSTRAINT IF EXISTS "positions_frozen_lte_quantity";
ALTER TABLE "positions"
  ADD CONSTRAINT "positions_quantity_nonneg" CHECK ("quantity" >= 0),
  ADD CONSTRAINT "positions_frozen_quantity_nonneg" CHECK ("frozenQuantity" >= 0),
  ADD CONSTRAINT "positions_frozen_lte_quantity" CHECK ("frozenQuantity" <= "quantity");

-- Preserve financial history: deleting a user must not cascade-wipe Account/ledger/orders.
ALTER TABLE "accounts" DROP CONSTRAINT IF EXISTS "accounts_userId_fkey";
ALTER TABLE "accounts"
  ADD CONSTRAINT "accounts_userId_fkey"
  FOREIGN KEY ("userId") REFERENCES "users"("id")
  ON DELETE RESTRICT ON UPDATE CASCADE;
