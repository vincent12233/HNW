DROP INDEX IF EXISTS "account_transactions_referenceId_key";

CREATE INDEX IF NOT EXISTS "account_transactions_referenceId_idx"
ON "account_transactions"("referenceId");