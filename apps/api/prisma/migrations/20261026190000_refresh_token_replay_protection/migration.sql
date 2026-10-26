CREATE TABLE "consumed_refresh_tokens" (
  "tokenHash" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "consumedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "consumed_refresh_tokens_pkey" PRIMARY KEY ("tokenHash"),
  CONSTRAINT "consumed_refresh_tokens_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "consumed_refresh_tokens_expiresAt_idx"
  ON "consumed_refresh_tokens"("expiresAt");

CREATE INDEX "consumed_refresh_tokens_userId_consumedAt_idx"
  ON "consumed_refresh_tokens"("userId", "consumedAt");
