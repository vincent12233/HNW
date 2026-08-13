-- CreateEnum
CREATE TYPE "Exchange" AS ENUM ('NSE', 'BSE');

-- CreateEnum
CREATE TYPE "InstrumentType" AS ENUM ('EQUITY', 'ETF');

-- CreateEnum
CREATE TYPE "OrderSide" AS ENUM ('BUY', 'SELL');

-- CreateEnum
CREATE TYPE "OrderType" AS ENUM ('MARKET', 'LIMIT');

-- CreateEnum
CREATE TYPE "OrderStatus" AS ENUM ('PENDING', 'OPEN', 'PARTIALLY_FILLED', 'FILLED', 'CANCELLED', 'REJECTED');

-- CreateTable
CREATE TABLE "instruments" (
    "id" TEXT NOT NULL,
    "symbol" TEXT NOT NULL,
    "exchange" "Exchange" NOT NULL,
    "name" TEXT NOT NULL,
    "isin" TEXT,
    "type" "InstrumentType" NOT NULL DEFAULT 'EQUITY',
    "currency" TEXT NOT NULL DEFAULT 'INR',
    "lotSize" INTEGER NOT NULL DEFAULT 1,
    "tickSize" DECIMAL(10,2) NOT NULL DEFAULT 0.05,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "instruments_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "market_quotes" (
    "id" TEXT NOT NULL,
    "instrumentId" TEXT NOT NULL,
    "lastPrice" DECIMAL(18,4) NOT NULL,
    "openPrice" DECIMAL(18,4),
    "highPrice" DECIMAL(18,4),
    "lowPrice" DECIMAL(18,4),
    "previousClose" DECIMAL(18,4),
    "bidPrice" DECIMAL(18,4),
    "askPrice" DECIMAL(18,4),
    "volume" BIGINT NOT NULL DEFAULT 0,
    "source" TEXT NOT NULL DEFAULT 'LIVE_FEED',
    "asOf" TIMESTAMP(3) NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "market_quotes_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "orders" (
    "id" TEXT NOT NULL,
    "clientOrderId" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "instrumentId" TEXT NOT NULL,
    "side" "OrderSide" NOT NULL,
    "type" "OrderType" NOT NULL,
    "status" "OrderStatus" NOT NULL DEFAULT 'PENDING',
    "quantity" INTEGER NOT NULL,
    "filledQuantity" INTEGER NOT NULL DEFAULT 0,
    "limitPrice" DECIMAL(18,4),
    "averageFillPrice" DECIMAL(18,4),
    "frozenAmount" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "rejectionReason" TEXT,
    "placedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "completedAt" TIMESTAMP(3),
    "cancelledAt" TIMESTAMP(3),
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "orders_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "trades" (
    "id" TEXT NOT NULL,
    "executionId" TEXT NOT NULL,
    "orderId" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "instrumentId" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL,
    "price" DECIMAL(18,4) NOT NULL,
    "grossAmount" DECIMAL(18,2) NOT NULL,
    "fees" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "netAmount" DECIMAL(18,2) NOT NULL,
    "executedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "trades_pkey" PRIMARY KEY ("id")
);

-- CreateTable
CREATE TABLE "positions" (
    "id" TEXT NOT NULL,
    "accountId" TEXT NOT NULL,
    "instrumentId" TEXT NOT NULL,
    "quantity" INTEGER NOT NULL DEFAULT 0,
    "averagePrice" DECIMAL(18,4) NOT NULL DEFAULT 0,
    "realizedPnl" DECIMAL(18,2) NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "positions_pkey" PRIMARY KEY ("id")
);

-- CreateIndex
CREATE INDEX "instruments_symbol_idx" ON "instruments"("symbol");

-- CreateIndex
CREATE INDEX "instruments_isin_idx" ON "instruments"("isin");

-- CreateIndex
CREATE INDEX "instruments_isActive_idx" ON "instruments"("isActive");

-- CreateIndex
CREATE UNIQUE INDEX "instruments_exchange_symbol_key" ON "instruments"("exchange", "symbol");

-- CreateIndex
CREATE UNIQUE INDEX "market_quotes_instrumentId_key" ON "market_quotes"("instrumentId");

-- CreateIndex
CREATE INDEX "market_quotes_asOf_idx" ON "market_quotes"("asOf");

-- CreateIndex
CREATE INDEX "orders_accountId_status_placedAt_idx" ON "orders"("accountId", "status", "placedAt");

-- CreateIndex
CREATE INDEX "orders_instrumentId_status_idx" ON "orders"("instrumentId", "status");

-- CreateIndex
CREATE UNIQUE INDEX "orders_accountId_clientOrderId_key" ON "orders"("accountId", "clientOrderId");

-- CreateIndex
CREATE UNIQUE INDEX "trades_executionId_key" ON "trades"("executionId");

-- CreateIndex
CREATE INDEX "trades_accountId_executedAt_idx" ON "trades"("accountId", "executedAt");

-- CreateIndex
CREATE INDEX "trades_instrumentId_executedAt_idx" ON "trades"("instrumentId", "executedAt");

-- CreateIndex
CREATE INDEX "trades_orderId_idx" ON "trades"("orderId");

-- CreateIndex
CREATE INDEX "positions_accountId_idx" ON "positions"("accountId");

-- CreateIndex
CREATE UNIQUE INDEX "positions_accountId_instrumentId_key" ON "positions"("accountId", "instrumentId");

-- AddForeignKey
ALTER TABLE "market_quotes" ADD CONSTRAINT "market_quotes_instrumentId_fkey" FOREIGN KEY ("instrumentId") REFERENCES "instruments"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "orders" ADD CONSTRAINT "orders_instrumentId_fkey" FOREIGN KEY ("instrumentId") REFERENCES "instruments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trades" ADD CONSTRAINT "trades_orderId_fkey" FOREIGN KEY ("orderId") REFERENCES "orders"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trades" ADD CONSTRAINT "trades_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "trades" ADD CONSTRAINT "trades_instrumentId_fkey" FOREIGN KEY ("instrumentId") REFERENCES "instruments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "positions" ADD CONSTRAINT "positions_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "accounts"("id") ON DELETE CASCADE ON UPDATE CASCADE;

-- AddForeignKey
ALTER TABLE "positions" ADD CONSTRAINT "positions_instrumentId_fkey" FOREIGN KEY ("instrumentId") REFERENCES "instruments"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
