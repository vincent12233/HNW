CREATE TYPE "DepositStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

CREATE TABLE "DepositRequest" (
    "id" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "amount" DECIMAL(18,2) NOT NULL,
    "paymentMethod" TEXT,
    "status" "DepositStatus" NOT NULL DEFAULT 'PENDING',
    "note" TEXT,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "DepositRequest_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "DepositRequest_accountId_idx"
ON "DepositRequest"("accountId");

ALTER TABLE "DepositRequest"
ADD CONSTRAINT "DepositRequest_accountId_fkey"
FOREIGN KEY ("accountId")
REFERENCES "accounts"("id")
ON DELETE CASCADE
ON UPDATE CASCADE;