ALTER TABLE "users" ADD COLUMN "transactionKeyHash" TEXT;

ALTER TYPE "AccountTransactionType" ADD VALUE IF NOT EXISTS 'OTC_SETTLEMENT';

CREATE TYPE "OtcOrderStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

CREATE TABLE "otc_offers" (
  "id" TEXT NOT NULL,
  "instrumentId" TEXT NOT NULL,
  "price" DECIMAL(18,4) NOT NULL,
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "validFrom" TIMESTAMP(3) NOT NULL,
  "validUntil" TIMESTAMP(3) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "otc_offers_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "otc_orders" (
  "id" TEXT NOT NULL,
  "orderNo" TEXT NOT NULL,
  "accountId" TEXT NOT NULL,
  "offerId" TEXT NOT NULL,
  "instrumentId" TEXT NOT NULL,
  "quantity" INTEGER NOT NULL,
  "price" DECIMAL(18,4) NOT NULL,
  "amount" DECIMAL(18,2) NOT NULL,
  "status" "OtcOrderStatus" NOT NULL DEFAULT 'PENDING',
  "reviewNote" TEXT,
  "reviewedById" TEXT,
  "reviewedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "otc_orders_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "otc_offers_instrumentId_key" ON "otc_offers"("instrumentId");
CREATE INDEX "otc_offers_isActive_validFrom_validUntil_idx" ON "otc_offers"("isActive", "validFrom", "validUntil");
CREATE UNIQUE INDEX "otc_orders_orderNo_key" ON "otc_orders"("orderNo");
CREATE INDEX "otc_orders_accountId_createdAt_idx" ON "otc_orders"("accountId", "createdAt");
CREATE INDEX "otc_orders_status_createdAt_idx" ON "otc_orders"("status", "createdAt");
ALTER TABLE "otc_offers" ADD CONSTRAINT "otc_offers_instrumentId_fkey" FOREIGN KEY ("instrumentId") REFERENCES "instruments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "otc_orders" ADD CONSTRAINT "otc_orders_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
ALTER TABLE "otc_orders" ADD CONSTRAINT "otc_orders_offerId_fkey" FOREIGN KEY ("offerId") REFERENCES "otc_offers"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "otc_orders" ADD CONSTRAINT "otc_orders_instrumentId_fkey" FOREIGN KEY ("instrumentId") REFERENCES "instruments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "otc_orders" ADD CONSTRAINT "otc_orders_reviewedById_fkey" FOREIGN KEY ("reviewedById") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
