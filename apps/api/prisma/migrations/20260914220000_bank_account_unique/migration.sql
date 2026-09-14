-- Prevent duplicate bank rails per user (race-safe uniqueness).
CREATE UNIQUE INDEX IF NOT EXISTS "bank_accounts_userId_accountNumber_ifscCode_key"
ON "bank_accounts"("userId", "accountNumber", "ifscCode");
