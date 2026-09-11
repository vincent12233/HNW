ALTER TABLE "users" ADD COLUMN "clientTier" TEXT NOT NULL DEFAULT 'STANDARD', ADD COLUMN "avatarData" TEXT;
ALTER TABLE "user_preferences" ADD COLUMN "theme" TEXT NOT NULL DEFAULT 'light';
CREATE TABLE "two_factor_credentials" (
  "userId" TEXT PRIMARY KEY REFERENCES "users"("id") ON DELETE CASCADE,
  "secret" TEXT, "pendingSecret" TEXT, "pendingExpiresAt" TIMESTAMP(3),
  "enabled" BOOLEAN NOT NULL DEFAULT false, "lastStep" INTEGER NOT NULL DEFAULT -1,
  "recoveryHashes" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
  "attempts" INTEGER NOT NULL DEFAULT 0, "lockedUntil" TIMESTAMP(3)
);
