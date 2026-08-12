CREATE TABLE "market_quote_history" (
    "id" TEXT NOT NULL,
    "instrumentId" TEXT NOT NULL,
    "bucketAt" TIMESTAMP(3) NOT NULL,
    "openPrice" DECIMAL(18,4) NOT NULL,
    "highPrice" DECIMAL(18,4) NOT NULL,
    "lowPrice" DECIMAL(18,4) NOT NULL,
    "closePrice" DECIMAL(18,4) NOT NULL,
    "volume" BIGINT NOT NULL DEFAULT 0,
    "source" TEXT NOT NULL DEFAULT 'LIVE_FEED',
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "market_quote_history_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "market_quote_history_instrumentId_bucketAt_key"
ON "market_quote_history"("instrumentId", "bucketAt");

CREATE INDEX "market_quote_history_instrumentId_bucketAt_idx"
ON "market_quote_history"("instrumentId", "bucketAt");

ALTER TABLE "market_quote_history"
ADD CONSTRAINT "market_quote_history_instrumentId_fkey"
FOREIGN KEY ("instrumentId") REFERENCES "instruments"("id") ON DELETE CASCADE ON UPDATE CASCADE;
