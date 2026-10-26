CREATE TABLE "support_interaction_references" (
  "id" UUID NOT NULL,
  "provider" TEXT NOT NULL,
  "externalReference" TEXT NOT NULL,
  "purpose" TEXT NOT NULL,
  "recoverySessionId" UUID,
  "actorId" TEXT NOT NULL,
  "status" TEXT NOT NULL,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  CONSTRAINT "support_interaction_references_pkey" PRIMARY KEY ("id"),
  CONSTRAINT "support_interaction_references_recovery_fkey"
    FOREIGN KEY ("recoverySessionId") REFERENCES "account_recovery_sessions"("id")
    ON DELETE SET NULL ON UPDATE CASCADE
);

CREATE UNIQUE INDEX "support_interaction_reference_unique"
  ON "support_interaction_references" ("provider", "externalReference", "purpose");
CREATE INDEX "support_interaction_reference_recovery"
  ON "support_interaction_references" ("recoverySessionId", "createdAt");
