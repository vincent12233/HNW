ALTER TABLE "admin_watchlist_items"
  ADD COLUMN "direction" TEXT NOT NULL DEFAULT 'UP',
  ADD COLUMN "referencePrice" DECIMAL(18,4),
  ADD COLUMN "expectedReturn" DECIMAL(8,2);
UPDATE "admin_watchlist_items" SET "status" = CASE WHEN "status" IN ('ACTIVE', '展示中') THEN 'ACTIVE' ELSE 'PAUSED' END;
