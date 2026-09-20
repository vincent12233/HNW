-- Immutable MANAGER ownership history for BUSINESS users.
-- Transfer updates User.businessCreatorId only; client assignedBusinessId is unchanged.

CREATE TABLE "business_manager_assignment_histories" (
    "id" TEXT NOT NULL,
    "businessUserId" TEXT NOT NULL,
    "previousManagerId" TEXT,
    "newManagerId" TEXT,
    "reason" TEXT NOT NULL,
    "changedById" TEXT NOT NULL,
    "idempotencyKey" TEXT NOT NULL,
    "businessEmployeeNo" TEXT,
    "previousManagerEmployeeNo" TEXT,
    "newManagerEmployeeNo" TEXT,
    "clientCountAtChange" INTEGER NOT NULL DEFAULT 0,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "business_manager_assignment_histories_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "business_manager_assignment_histories_idempotencyKey_key"
    ON "business_manager_assignment_histories"("idempotencyKey");

CREATE INDEX "business_manager_assignment_histories_businessUserId_createdAt_idx"
    ON "business_manager_assignment_histories"("businessUserId", "createdAt");

CREATE INDEX "business_manager_assignment_histories_previousManagerId_createdAt_idx"
    ON "business_manager_assignment_histories"("previousManagerId", "createdAt");

CREATE INDEX "business_manager_assignment_histories_newManagerId_createdAt_idx"
    ON "business_manager_assignment_histories"("newManagerId", "createdAt");

CREATE INDEX "business_manager_assignment_histories_changedById_createdAt_idx"
    ON "business_manager_assignment_histories"("changedById", "createdAt");

ALTER TABLE "business_manager_assignment_histories"
    ADD CONSTRAINT "business_manager_assignment_histories_reason_required"
    CHECK (char_length(btrim("reason")) > 0);

ALTER TABLE "business_manager_assignment_histories"
    ADD CONSTRAINT "business_manager_assignment_histories_managers_distinct"
    CHECK ("previousManagerId" IS DISTINCT FROM "newManagerId");

ALTER TABLE "business_manager_assignment_histories"
    ADD CONSTRAINT "business_manager_assignment_histories_client_count_nonneg"
    CHECK ("clientCountAtChange" >= 0);

ALTER TABLE "business_manager_assignment_histories"
    ADD CONSTRAINT "business_manager_assignment_histories_businessUserId_fkey"
    FOREIGN KEY ("businessUserId") REFERENCES "users"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "business_manager_assignment_histories"
    ADD CONSTRAINT "business_manager_assignment_histories_previousManagerId_fkey"
    FOREIGN KEY ("previousManagerId") REFERENCES "users"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "business_manager_assignment_histories"
    ADD CONSTRAINT "business_manager_assignment_histories_newManagerId_fkey"
    FOREIGN KEY ("newManagerId") REFERENCES "users"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "business_manager_assignment_histories"
    ADD CONSTRAINT "business_manager_assignment_histories_changedById_fkey"
    FOREIGN KEY ("changedById") REFERENCES "users"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;
