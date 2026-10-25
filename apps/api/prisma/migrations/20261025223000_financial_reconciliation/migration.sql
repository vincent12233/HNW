CREATE TABLE "reconciliation_runs" (
  "id" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'RUNNING',
  "startedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "completedAt" TIMESTAMP(3),
  "durationMs" INTEGER,
  "issueCount" INTEGER NOT NULL DEFAULT 0,
  "errorSummary" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "reconciliation_runs_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "reconciliation_issues" (
  "id" TEXT NOT NULL,
  "runId" TEXT NOT NULL,
  "checkType" TEXT NOT NULL,
  "severity" TEXT NOT NULL DEFAULT 'HIGH',
  "entityType" TEXT NOT NULL,
  "entityId" TEXT,
  "summary" TEXT NOT NULL,
  "details" JSONB,
  "acknowledgedAt" TIMESTAMP(3),
  "acknowledgedBy" TEXT,
  "acknowledgeNote" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "reconciliation_issues_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "reconciliation_issues_runId_fkey" FOREIGN KEY ("runId") REFERENCES "reconciliation_runs"("id") ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE INDEX "reconciliation_runs_startedAt_idx" ON "reconciliation_runs"("startedAt");
CREATE INDEX "reconciliation_runs_status_startedAt_idx" ON "reconciliation_runs"("status", "startedAt");
CREATE INDEX "reconciliation_issues_runId_severity_idx" ON "reconciliation_issues"("runId", "severity");
CREATE INDEX "reconciliation_issues_checkType_createdAt_idx" ON "reconciliation_issues"("checkType", "createdAt");
CREATE INDEX "reconciliation_issues_acknowledgedAt_idx" ON "reconciliation_issues"("acknowledgedAt");
