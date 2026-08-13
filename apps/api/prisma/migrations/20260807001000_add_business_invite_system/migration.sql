CREATE TYPE "InviteCodeStatus" AS ENUM (
  'UNUSED',
  'USED',
  'EXPIRED',
  'DISABLED'
);

ALTER TYPE "UserRole" ADD VALUE 'BUSINESS';

ALTER TABLE "users"
ADD COLUMN "assignedBusinessId" TEXT;

CREATE TABLE "business_profiles" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "employeeNo" TEXT NOT NULL,
  "department" TEXT,
  "isActive" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "business_profiles_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "invite_codes" (
  "id" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "businessProfileId" TEXT NOT NULL,
  "customerId" TEXT,
  "status" "InviteCodeStatus" NOT NULL DEFAULT 'UNUSED',
  "expiresAt" TIMESTAMP(3),
  "usedAt" TIMESTAMP(3),
  "disabledAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,

  CONSTRAINT "invite_codes_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "business_profiles_userId_key"
ON "business_profiles"("userId");

CREATE UNIQUE INDEX "business_profiles_employeeNo_key"
ON "business_profiles"("employeeNo");

CREATE UNIQUE INDEX "invite_codes_code_key"
ON "invite_codes"("code");

CREATE UNIQUE INDEX "invite_codes_customerId_key"
ON "invite_codes"("customerId");

CREATE INDEX "invite_codes_businessProfileId_idx"
ON "invite_codes"("businessProfileId");

CREATE INDEX "invite_codes_status_idx"
ON "invite_codes"("status");

CREATE INDEX "invite_codes_createdAt_idx"
ON "invite_codes"("createdAt");

CREATE INDEX "users_assignedBusinessId_idx"
ON "users"("assignedBusinessId");

ALTER TABLE "users"
ADD CONSTRAINT "users_assignedBusinessId_fkey"
FOREIGN KEY ("assignedBusinessId")
REFERENCES "users"("id")
ON DELETE SET NULL
ON UPDATE CASCADE;

ALTER TABLE "business_profiles"
ADD CONSTRAINT "business_profiles_userId_fkey"
FOREIGN KEY ("userId")
REFERENCES "users"("id")
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE "invite_codes"
ADD CONSTRAINT "invite_codes_businessProfileId_fkey"
FOREIGN KEY ("businessProfileId")
REFERENCES "business_profiles"("id")
ON DELETE CASCADE
ON UPDATE CASCADE;

ALTER TABLE "invite_codes"
ADD CONSTRAINT "invite_codes_customerId_fkey"
FOREIGN KEY ("customerId")
REFERENCES "users"("id")
ON DELETE SET NULL
ON UPDATE CASCADE;