ALTER TABLE "users" ADD COLUMN "withdrawalPinHash" TEXT,
ADD COLUMN "withdrawalPinAttempts" INTEGER NOT NULL DEFAULT 0,
ADD COLUMN "withdrawalPinLockedUntil" TIMESTAMP(3);
ALTER TABLE "portfolio_snapshots" ADD COLUMN "profitValue" DECIMAL(18,2);
