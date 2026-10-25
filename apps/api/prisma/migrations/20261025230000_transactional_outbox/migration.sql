CREATE TABLE "outbox_events" (
  "id" TEXT NOT NULL,
  "eventId" TEXT NOT NULL,
  "type" TEXT NOT NULL,
  "aggregateType" TEXT NOT NULL,
  "aggregateId" TEXT NOT NULL,
  "aggregateVersion" INTEGER NOT NULL,
  "schemaVersion" INTEGER NOT NULL DEFAULT 1,
  "occurredAt" TIMESTAMP(3) NOT NULL,
  "correlationId" TEXT,
  "payload" JSONB NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "attempts" INTEGER NOT NULL DEFAULT 0,
  "availableAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "leasedUntil" TIMESTAMP(3),
  "processedAt" TIMESTAMP(3),
  "lastError" TEXT,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "outbox_events_pkey" PRIMARY KEY ("id")
);
CREATE UNIQUE INDEX "outbox_events_eventId_key" ON "outbox_events"("eventId");
CREATE INDEX "outbox_events_status_availableAt_createdAt_idx" ON "outbox_events"("status", "availableAt", "createdAt");
CREATE INDEX "outbox_events_leasedUntil_idx" ON "outbox_events"("leasedUntil");
CREATE INDEX "outbox_events_aggregateType_aggregateId_aggregateVersion_idx" ON "outbox_events"("aggregateType", "aggregateId", "aggregateVersion");
ALTER TABLE "notifications" ADD COLUMN "outboxEventId" TEXT;
CREATE UNIQUE INDEX "notifications_outboxEventId_key" ON "notifications"("outboxEventId");
