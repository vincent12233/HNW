ALTER TABLE "withdrawal_requests" ADD COLUMN "orderNo" TEXT;

UPDATE "withdrawal_requests"
SET "orderNo" = 'WD' || TO_CHAR("createdAt", 'YYYYMMDD') || UPPER(SUBSTRING(REPLACE("id", '-', ''), 1, 8))
WHERE "orderNo" IS NULL;

CREATE UNIQUE INDEX "withdrawal_requests_orderNo_key" ON "withdrawal_requests"("orderNo") WHERE "orderNo" IS NOT NULL;
CREATE INDEX "withdrawal_requests_orderNo_idx" ON "withdrawal_requests"("orderNo");
