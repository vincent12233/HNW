ALTER TABLE "DepositRequest" ADD COLUMN "referenceId" TEXT;
CREATE UNIQUE INDEX "DepositRequest_referenceId_key" ON "DepositRequest"("referenceId");
CREATE INDEX "DepositRequest_status_createdAt_idx" ON "DepositRequest"("status", "createdAt");
