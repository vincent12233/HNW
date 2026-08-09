CREATE TYPE "WithdrawalStatus" AS ENUM (
  'PENDING',
  'APPROVED',
  'REJECTED'
);

CREATE TABLE "withdrawal_requests" (
  "id" TEXT NOT NULL,
  "accountId" TEXT NOT NULL,
  "amount" DECIMAL(18,2) NOT NULL,
  "bankName" TEXT,
  "accountNumber" TEXT,
  "ifscCode" TEXT,
  "upiId" TEXT,
  "note" TEXT,
  "status" "WithdrawalStatus" NOT NULL DEFAULT 'PENDING',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "withdrawal_requests_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "withdrawal_requests_accountId_idx"
ON "withdrawal_requests"("accountId");

CREATE INDEX "withdrawal_requests_status_idx"
ON "withdrawal_requests"("status");

ALTER TABLE "withdrawal_requests"
ADD CONSTRAINT "withdrawal_requests_accountId_fkey"
FOREIGN KEY ("accountId")
REFERENCES "accounts"("id")
ON DELETE CASCADE
ON UPDATE CASCADE;