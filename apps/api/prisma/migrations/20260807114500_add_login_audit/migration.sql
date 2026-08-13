CREATE TABLE "login_audits" (
  "id" TEXT NOT NULL,
  "userId" TEXT NOT NULL,
  "ipAddress" TEXT,
  "userAgent" TEXT,
  "success" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

  CONSTRAINT "login_audits_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "login_audits_userId_idx"
ON "login_audits"("userId");

CREATE INDEX "login_audits_createdAt_idx"
ON "login_audits"("createdAt");

ALTER TABLE "login_audits"
ADD CONSTRAINT "login_audits_userId_fkey"
FOREIGN KEY ("userId")
REFERENCES "users"("id")
ON DELETE CASCADE
ON UPDATE CASCADE;