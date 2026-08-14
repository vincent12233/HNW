CREATE TYPE "ApprovalStatus" AS ENUM ('PENDING', 'APPROVED', 'REJECTED', 'EXPIRED', 'CANCELLED');
CREATE TABLE "approval_requests" (
  "id" TEXT NOT NULL, "action" TEXT NOT NULL, "resource" TEXT NOT NULL, "resourceId" TEXT NOT NULL,
  "payload" JSONB NOT NULL, "reason" TEXT NOT NULL, "status" "ApprovalStatus" NOT NULL DEFAULT 'PENDING',
  "requestedById" TEXT NOT NULL, "decidedById" TEXT, "decisionNote" TEXT,
  "requestedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP, "decidedAt" TIMESTAMP(3), "expiresAt" TIMESTAMP(3),
  CONSTRAINT "approval_requests_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "approval_four_eyes" CHECK ("decidedById" IS NULL OR "decidedById" <> "requestedById")
);
CREATE INDEX "approval_requests_status_requestedAt_idx" ON "approval_requests"("status", "requestedAt");
CREATE INDEX "approval_requests_resource_resourceId_idx" ON "approval_requests"("resource", "resourceId");
CREATE INDEX "approval_requests_requestedById_idx" ON "approval_requests"("requestedById");
ALTER TABLE "approval_requests" ADD CONSTRAINT "approval_requests_requestedById_fkey" FOREIGN KEY ("requestedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
ALTER TABLE "approval_requests" ADD CONSTRAINT "approval_requests_decidedById_fkey" FOREIGN KEY ("decidedById") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
