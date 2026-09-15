-- Institutional stocks settle at live market quotes only.
-- Admin referencePrice is no longer used.
ALTER TABLE "admin_watchlist_items" DROP COLUMN IF EXISTS "referencePrice";
