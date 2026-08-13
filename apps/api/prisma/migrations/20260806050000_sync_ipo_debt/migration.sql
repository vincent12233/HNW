-- CreateEnum
CREATE TYPE "IpoPaymentStatus" AS ENUM ('PENDING', 'PAID', 'FAILED');

-- CreateEnum
CREATE TYPE "IpoDebtStatus" AS ENUM ('OPEN', 'PARTIAL', 'PAID', 'DEFAULTED');

-- AlterTable
ALTER TABLE "IpoApplication" ADD COLUMN     "allocatedAmount" DECIMAL(18,2),
ADD COLUMN     "allocatedPrice" DECIMAL(18,2),
ADD COLUMN     "allocatedQuantity" INTEGER,
ADD COLUMN     "paymentStatus" "IpoPaymentStatus" NOT NULL DEFAULT 'PENDING',
ADD COLUMN     "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP;

-- AlterTable
ALTER TABLE "ipos" ADD COLUMN     "instrumentId" TEXT,
ALTER COLUMN "issuePrice" SET DATA TYPE DECIMAL(18,2);

-- CreateTable
CREATE TABLE "ipo_debts" (
    "id" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "ipoApplicationId" TEXT NOT NULL,
    "amount" DECIMAL(18,2) NOT NULL,
    "paidAmount" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "status" "IpoDebtStatus" NOT NULL DEFAULT 'OPEN',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ipo_debts_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "ipo_debts_ipoApplicationId_key" ON "ipo_debts"("ipoApplicationId");

-- CreateIndex
CREATE INDEX "ipo_debts_accountId_idx" ON "ipo_debts"("accountId");

-- CreateIndex
CREATE INDEX "ipo_debts_status_idx" ON "ipo_debts"("status");

-- CreateIndex
CREATE INDEX "ipos_status_idx" ON "ipos"("status");

-- CreateIndex
CREATE INDEX "ipos_instrumentId_idx" ON "ipos"("instrumentId");

-- AddForeignKey
ALTER TABLE "ipos" ADD CONSTRAINT "ipos_instrumentId_fkey" FOREIGN KEY ("instrumentId") REFERENCES "instruments"("id") ON DELETE SET NULL ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ipo_debts" ADD CONSTRAINT "ipo_debts_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "ipo_debts" ADD CONSTRAINT "ipo_debts_ipoApplicationId_fkey" FOREIGN KEY ("ipoApplicationId") REFERENCES "IpoApplication"("id") ON DELETE CASCADE ON UPDATE CASCADE;