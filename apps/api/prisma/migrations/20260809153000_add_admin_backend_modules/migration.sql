CREATE TABLE "admin_watchlist_items" (
  "id" TEXT NOT NULL,
  "symbol" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "market" TEXT NOT NULL DEFAULT 'NSE',
  "category" TEXT NOT NULL,
  "risk" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT '展示中',
  "reason" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "admin_watchlist_items_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "admin_watchlist_items_symbol_idx" ON "admin_watchlist_items"("symbol");
CREATE INDEX "admin_watchlist_items_status_idx" ON "admin_watchlist_items"("status");

CREATE TABLE "admin_block_trades" (
  "id" TEXT NOT NULL,
  "orderNo" TEXT NOT NULL,
  "symbol" TEXT NOT NULL,
  "side" TEXT NOT NULL,
  "quantity" INTEGER NOT NULL,
  "price" DECIMAL(18,4) NOT NULL,
  "minTicket" DECIMAL(18,2) NOT NULL,
  "status" TEXT NOT NULL DEFAULT '审核中',
  "note" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "admin_block_trades_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "admin_block_trades_orderNo_key" ON "admin_block_trades"("orderNo");
CREATE INDEX "admin_block_trades_symbol_idx" ON "admin_block_trades"("symbol");
CREATE INDEX "admin_block_trades_status_idx" ON "admin_block_trades"("status");

CREATE TABLE "admin_fund_products" (
  "id" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "nav" DECIMAL(18,4) NOT NULL,
  "minSubscribe" DECIMAL(18,2) NOT NULL,
  "risk" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT '开放申购',
  "manager" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "admin_fund_products_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "admin_fund_products_code_key" ON "admin_fund_products"("code");
CREATE INDEX "admin_fund_products_status_idx" ON "admin_fund_products"("status");

CREATE TABLE "admin_quant_strategies" (
  "id" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "market" TEXT NOT NULL,
  "risk" TEXT NOT NULL,
  "annualReturn" DECIMAL(8,2) NOT NULL,
  "maxDrawdown" DECIMAL(8,2) NOT NULL,
  "authorizedClients" INTEGER NOT NULL DEFAULT 0,
  "status" TEXT NOT NULL DEFAULT '观察中',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "admin_quant_strategies_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "admin_quant_strategies_code_key" ON "admin_quant_strategies"("code");
CREATE INDEX "admin_quant_strategies_status_idx" ON "admin_quant_strategies"("status");
