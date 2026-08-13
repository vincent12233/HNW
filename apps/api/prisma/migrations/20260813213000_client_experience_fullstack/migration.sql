CREATE TYPE "BankAccountStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED');

CREATE TABLE "bank_accounts" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
  "userId" TEXT NOT NULL,
  "bankName" TEXT NOT NULL,
  "accountHolder" TEXT NOT NULL,
  "accountNumber" TEXT NOT NULL,
  "ifscCode" TEXT NOT NULL,
  "status" "BankAccountStatus" NOT NULL DEFAULT 'APPROVED',
  "isPrimary" BOOLEAN NOT NULL DEFAULT false,
  "reviewNote" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "bank_accounts_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "bank_accounts_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
);
CREATE INDEX "bank_accounts_userId_status_idx" ON "bank_accounts"("userId", "status");

CREATE TABLE "user_preferences" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
  "userId" TEXT NOT NULL,
  "orderNotifications" BOOLEAN NOT NULL DEFAULT true,
  "accountNotifications" BOOLEAN NOT NULL DEFAULT true,
  "supportNotifications" BOOLEAN NOT NULL DEFAULT true,
  "biometricEnabled" BOOLEAN NOT NULL DEFAULT false,
  "language" TEXT NOT NULL DEFAULT 'en',
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "user_preferences_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "user_preferences_userId_key" UNIQUE ("userId"),
  CONSTRAINT "user_preferences_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
);

CREATE TABLE "notifications" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
  "userId" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "title" TEXT NOT NULL,
  "body" TEXT NOT NULL,
  "referenceId" TEXT,
  "readAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "notifications_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "notifications_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
);
CREATE INDEX "notifications_userId_readAt_createdAt_idx" ON "notifications"("userId", "readAt", "createdAt");

CREATE TABLE "user_devices" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
  "userId" TEXT NOT NULL,
  "deviceName" TEXT NOT NULL,
  "platform" TEXT NOT NULL,
  "pushToken" TEXT,
  "lastIp" TEXT,
  "lastSeenAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "revokedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "user_devices_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "user_devices_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
);
CREATE INDEX "user_devices_userId_revokedAt_idx" ON "user_devices"("userId", "revokedAt");

ALTER TABLE "support_messages" ADD COLUMN "attachmentName" TEXT;
ALTER TABLE "support_messages" ADD COLUMN "attachmentUrl" TEXT;
ALTER TABLE "support_messages" ADD COLUMN "attachmentType" TEXT;
ALTER TABLE "support_messages" ADD COLUMN "readAt" TIMESTAMP(3);

CREATE TABLE "portfolio_snapshots" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
  "accountId" TEXT NOT NULL,
  "cashValue" DECIMAL(18,2) NOT NULL,
  "instValue" DECIMAL(18,2) NOT NULL,
  "otcValue" DECIMAL(18,2) NOT NULL,
  "ipoValue" DECIMAL(18,2) NOT NULL,
  "totalValue" DECIMAL(18,2) NOT NULL,
  "capturedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "portfolio_snapshots_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "portfolio_snapshots_accountId_fkey" FOREIGN KEY ("accountId") REFERENCES "accounts"("id") ON DELETE CASCADE
);
CREATE INDEX "portfolio_snapshots_accountId_capturedAt_idx" ON "portfolio_snapshots"("accountId", "capturedAt");

ALTER TABLE "users" ADD COLUMN "googleSubject" TEXT;
CREATE UNIQUE INDEX "users_googleSubject_key" ON "users"("googleSubject");

CREATE TABLE "password_reset_codes" (
  "id" TEXT NOT NULL DEFAULT gen_random_uuid()::text,
  "userId" TEXT NOT NULL,
  "codeHash" TEXT NOT NULL,
  "expiresAt" TIMESTAMP(3) NOT NULL,
  "usedAt" TIMESTAMP(3),
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "password_reset_codes_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "password_reset_codes_userId_fkey" FOREIGN KEY ("userId") REFERENCES "users"("id") ON DELETE CASCADE
);
CREATE INDEX "password_reset_codes_userId_expiresAt_idx" ON "password_reset_codes"("userId", "expiresAt");
