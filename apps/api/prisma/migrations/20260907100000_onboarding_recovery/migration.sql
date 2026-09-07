ALTER TABLE "kyc_submissions" ADD COLUMN "fullName" TEXT, ADD COLUMN "bankDetails" JSONB;
CREATE TABLE "account_recovery_sessions" (
  "id" UUID PRIMARY KEY,
  "phone" TEXT NOT NULL,
  "tokenHash" TEXT NOT NULL UNIQUE,
  "status" TEXT NOT NULL DEFAULT 'OPEN',
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "codeHash" TEXT,
  "codeExpiresAt" TIMESTAMP(3),
  "codeUsedAt" TIMESTAMP(3),
  "codeAttempts" INTEGER NOT NULL DEFAULT 0,
  "issuedById" TEXT,
  "issuedUserId" TEXT
);
CREATE INDEX "account_recovery_phone_created" ON "account_recovery_sessions" ("phone", "createdAt");
CREATE TABLE "account_recovery_messages" (
  "id" UUID PRIMARY KEY,
  "sessionId" UUID NOT NULL REFERENCES "account_recovery_sessions"("id") ON DELETE CASCADE,
  "sender" TEXT NOT NULL,
  "content" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);
CREATE INDEX "account_recovery_messages_session" ON "account_recovery_messages" ("sessionId", "createdAt");
