CREATE TYPE "LedgerAccountType" AS ENUM ('ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE');
CREATE TYPE "LedgerEntrySide" AS ENUM ('DEBIT', 'CREDIT');
CREATE TYPE "ApprovalStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED', 'CANCELLED');

CREATE TABLE "ledger_accounts" (
  "id" TEXT NOT NULL,
  "code" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "type" "LedgerAccountType" NOT NULL,
  "currency" TEXT NOT NULL DEFAULT 'INR',
  "customerAccountId" TEXT,
  "active" BOOLEAN NOT NULL DEFAULT true,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ledger_accounts_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ledger_journals" (
  "id" TEXT NOT NULL,
  "journalNo" TEXT NOT NULL,
  "eventType" TEXT NOT NULL,
  "referenceType" TEXT NOT NULL,
  "referenceId" TEXT NOT NULL,
  "currency" TEXT NOT NULL DEFAULT 'INR',
  "description" TEXT,
  "idempotencyKey" TEXT NOT NULL,
  "createdById" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ledger_journals_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "ledger_entries" (
  "id" TEXT NOT NULL,
  "journalId" TEXT NOT NULL,
  "ledgerAccountId" TEXT NOT NULL,
  "side" "LedgerEntrySide" NOT NULL,
  "amount" DECIMAL(18,2) NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "ledger_entries_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "ledger_entries_positive_amount" CHECK ("amount" > 0)
);

CREATE TABLE "approval_requests" (
  "id" TEXT NOT NULL,
  "action" TEXT NOT NULL,
  "resource" TEXT NOT NULL,
  "resourceId" TEXT NOT NULL,
  "payload" JSONB NOT NULL,
  "reason" TEXT NOT NULL,
  "status" "ApprovalStatus" NOT NULL DEFAULT 'PENDING',
  "requestedById" TEXT NOT NULL,
  "decidedById" TEXT,
  "decisionNote" TEXT,
  "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "decidedAt" TIMESTAMP(3),
  "expiresAt" TIMESTAMP(3),
  CONSTRAINT "approval_requests_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "approval_four_eyes" CHECK ("decidedById" IS NULL OR "decidedById" <> "requestedById")
);

CREATE UNIQUE INDEX "ledger_accounts_code_key" ON "ledger_accounts"("code");
CREATE UNIQUE INDEX "ledger_journals_journalNo_key" ON "ledger_journals"("journalNo");
CREATE UNIQUE INDEX "ledger_journals_idempotencyKey_key" ON "ledger_journals"("idempotencyKey");
CREATE UNIQUE INDEX "ledger_journals_referenceType_referenceId_eventType_key" ON "ledger_journals"("referenceType", "referenceId", "eventType");
CREATE INDEX "ledger_accounts_customerAccountId_idx" ON "ledger_accounts"("customerAccountId");
CREATE INDEX "ledger_accounts_type_active_idx" ON "ledger_accounts"("type", "active");
CREATE INDEX "ledger_journals_referenceType_referenceId_idx" ON "ledger_journals"("referenceType", "referenceId");
CREATE INDEX "ledger_journals_createdAt_idx" ON "ledger_journals"("createdAt");
CREATE INDEX "ledger_entries_journalId_idx" ON "ledger_entries"("journalId");
CREATE INDEX "ledger_entries_ledgerAccountId_createdAt_idx" ON "ledger_entries"("ledgerAccountId", "createdAt");
CREATE INDEX "approval_requests_status_requestedAt_idx" ON "approval_requests"("status", "requestedAt");
CREATE INDEX "approval_requests_resource_resourceId_idx" ON "approval_requests"("resource", "resourceId");
CREATE INDEX "approval_requests_requestedById_idx" ON "approval_requests"("requestedById");

ALTER TABLE "ledger_accounts" ADD CONSTRAINT "ledger_accounts_customerAccountId_fkey" FOREIGN KEY ("customerAccountId") REFERENCES "accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ledger_journals" ADD CONSTRAINT "ledger_journals_createdById_fkey" FOREIGN KEY ("createdById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ledger_entries" ADD CONSTRAINT "ledger_entries_journalId_fkey" FOREIGN KEY ("journalId") REFERENCES "ledger_journals"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "ledger_entries" ADD CONSTRAINT "ledger_entries_ledgerAccountId_fkey" FOREIGN KEY ("ledgerAccountId") REFERENCES "ledger_accounts"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "approval_requests" ADD CONSTRAINT "approval_requests_requestedById_fkey" FOREIGN KEY ("requestedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "approval_requests" ADD CONSTRAINT "approval_requests_decidedById_fkey" FOREIGN KEY ("decidedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;

CREATE OR REPLACE FUNCTION prevent_ledger_mutation() RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'Ledger records are immutable';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ledger_journals_immutable BEFORE UPDATE OR DELETE ON "ledger_journals" FOR EACH ROW EXECUTE FUNCTION prevent_ledger_mutation();
CREATE TRIGGER ledger_entries_immutable BEFORE UPDATE OR DELETE ON "ledger_entries" FOR EACH ROW EXECUTE FUNCTION prevent_ledger_mutation();
