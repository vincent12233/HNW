-- CreateEnum
CREATE TYPE "LoanStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'DISBURSED', 'PARTIAL_REPAID', 'REPAID', 'OVERDUE');

-- AlterEnum
ALTER TYPE "AccountTransactionType" ADD VALUE 'LOAN_DISBURSEMENT';
ALTER TYPE "AccountTransactionType" ADD VALUE 'LOAN_REPAYMENT';

-- CreateTable
CREATE TABLE "loan_applications" (
    "id" TEXT NOT NULL,
    "orderNo" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "requestedAmount" DECIMAL(18,2) NOT NULL,
    "approvedAmount" DECIMAL(18,2),
    "outstandingAmount" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "interestRate" DECIMAL(8,2) NOT NULL DEFAULT 0,
    "dueDate" TIMESTAMP(3),
    "status" "LoanStatus" NOT NULL DEFAULT 'PENDING',
    "note" TEXT,
    "approvedById" TEXT,
    "approvedAt" TIMESTAMP(3),
    "disbursedAt" TIMESTAMP(3),
    "closedAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "loan_applications_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE UNIQUE INDEX "loan_applications_orderNo_key" ON "loan_applications"("orderNo");
CREATE INDEX "loan_applications_accountId_idx" ON "loan_applications"("accountId");
CREATE INDEX "loan_applications_orderNo_idx" ON "loan_applications"("orderNo");
CREATE INDEX "loan_applications_status_idx" ON "loan_applications"("status");

-- AddForeignKey
ALTER TABLE "loan_applications" ADD CONSTRAINT "loan_applications_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;
