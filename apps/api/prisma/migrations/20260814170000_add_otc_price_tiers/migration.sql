ALTER TABLE "otc_offers"
  ADD COLUMN "priceTier2" DECIMAL(18,4),
  ADD COLUMN "priceTier3" DECIMAL(18,4),
  ADD COLUMN "profitTier1" DECIMAL(8,2),
  ADD COLUMN "profitTier2" DECIMAL(8,2),
  ADD COLUMN "profitTier3" DECIMAL(8,2),
  ADD COLUMN "keyHashTier1" TEXT,
  ADD COLUMN "keyHashTier2" TEXT,
  ADD COLUMN "keyHashTier3" TEXT;

ALTER TABLE "otc_orders" ADD COLUMN "priceTier" INTEGER NOT NULL DEFAULT 1;
