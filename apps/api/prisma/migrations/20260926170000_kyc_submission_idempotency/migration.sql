ALTER TABLE "kyc_submissions"
  ADD COLUMN "idempotencyKey" TEXT,
  ADD COLUMN "requestFingerprint" TEXT;

CREATE UNIQUE INDEX "kyc_submissions_idempotencyKey_key"
  ON "kyc_submissions"("idempotencyKey");