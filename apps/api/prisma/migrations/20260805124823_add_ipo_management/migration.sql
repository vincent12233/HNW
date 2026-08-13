-- CreateEnum
CREATE TYPE "IpoStatus" AS ENUM ('DRAFT', 'OPEN', 'CLOSED', 'ALLOTMENT_DONE');

-- CreateEnum
CREATE TYPE "IpoApplicationStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'ALLOTTED');

-- CreateTable
CREATE TABLE "ipos" (
    "id" TEXT NOT NULL,
    "symbol" TEXT NOT NULL,
    "companyName" TEXT NOT NULL,
    "exchange" "Exchange" NOT NULL,
    "issuePrice" DECIMAL(65,30) NOT NULL,
    "lotSize" INTEGER NOT NULL,
    "totalShares" INTEGER NOT NULL,
    "availableShares" INTEGER NOT NULL,
    "openDate" TIMESTAMP(3) NOT NULL,
    "closeDate" TIMESTAMP(3) NOT NULL,
    "status" "IpoStatus" NOT NULL DEFAULT 'DRAFT',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "ipos_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "IpoApplication" (
    "id" TEXT NOT NULL,
    "ipoId" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL,
    "amount" DECIMAL(65,30) NOT NULL,
    "status" "IpoApplicationStatus" NOT NULL DEFAULT 'PENDING',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "IpoApplication_pkey" PRIMARY KEY ("id")
);

-- AddForeignKey
ALTER TABLE "IpoApplication" ADD CONSTRAINT "IpoApplication_ipoId_fkey" FOREIGN KEY ("ipoId") REFERENCES "ipos"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "IpoApplication" ADD CONSTRAINT "IpoApplication_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
