ALTER TABLE "withdrawal_requests"
ADD COLUMN "clientRequestId" TEXT;

CREATE UNIQUE INDEX "withdrawal_requests_accountId_clientRequestId_key"
ON "withdrawal_requests"("accountId", "clientRequestId");
