CREATE TABLE "user_watchlist_items" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "instrumentId" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "user_watchlist_items_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "user_watchlist_items_userId_instrumentId_key"
ON "user_watchlist_items"("userId", "instrumentId");

CREATE INDEX "user_watchlist_items_userId_createdAt_idx"
ON "user_watchlist_items"("userId", "createdAt");

ALTER TABLE "user_watchlist_items"
ADD CONSTRAINT "user_watchlist_items_userId_fkey"
FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "user_watchlist_items"
ADD CONSTRAINT "user_watchlist_items_instrumentId_fkey"
FOREIGN KEY ("instrumentId") REFERENCES "instruments"("id") ON DELETE CASCADE ON UPDATE CASCADE;
