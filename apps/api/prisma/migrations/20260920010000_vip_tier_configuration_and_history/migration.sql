-- Additive VIP configuration and manual-adjustment history.
-- Thresholds stay NULL: no fictional amounts and no User.clientTier rewrite.

CREATE TABLE "vip_tier_configurations" (
    "id" TEXT NOT NULL,
    "tierCode" TEXT NOT NULL,
    "displayName" TEXT NOT NULL,
    "description" TEXT NOT NULL DEFAULT '',
    "minimumCumulativeDeposit" DECIMAL(18,2),
    "displayOrder" INTEGER NOT NULL,
    "isActive" BOOLEAN NOT NULL DEFAULT true,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,
    "updatedById" TEXT,

    CONSTRAINT "vip_tier_configurations_pkey" PRIMARY KEY ("id")
);

CREATE UNIQUE INDEX "vip_tier_configurations_tierCode_key"
    ON "vip_tier_configurations"("tierCode");

CREATE UNIQUE INDEX "vip_tier_configurations_displayOrder_key"
    ON "vip_tier_configurations"("displayOrder");

ALTER TABLE "vip_tier_configurations"
    ADD CONSTRAINT "vip_tier_configurations_min_deposit_nonneg"
    CHECK ("minimumCumulativeDeposit" IS NULL OR "minimumCumulativeDeposit" >= 0);

ALTER TABLE "vip_tier_configurations"
    ADD CONSTRAINT "vip_tier_configurations_updatedById_fkey"
    FOREIGN KEY ("updatedById") REFERENCES "users"("id")
    ON DELETE SET NULL ON UPDATE CASCADE;

CREATE TABLE "vip_tier_histories" (
    "id" TEXT NOT NULL,
    "userId" TEXT NOT NULL,
    "previousTier" TEXT NOT NULL,
    "newTier" TEXT NOT NULL,
    "reason" TEXT NOT NULL,
    "source" TEXT NOT NULL,
    "suggestedTierAtChange" TEXT,
    "cumulativeDepositAtChange" DECIMAL(18,2) NOT NULL,
    "changedById" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "vip_tier_histories_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "vip_tier_histories_userId_createdAt_idx"
    ON "vip_tier_histories"("userId", "createdAt");

CREATE INDEX "vip_tier_histories_changedById_createdAt_idx"
    ON "vip_tier_histories"("changedById", "createdAt");

CREATE INDEX "vip_tier_histories_newTier_createdAt_idx"
    ON "vip_tier_histories"("newTier", "createdAt");

ALTER TABLE "vip_tier_histories"
    ADD CONSTRAINT "vip_tier_histories_deposit_nonneg"
    CHECK ("cumulativeDepositAtChange" >= 0);

ALTER TABLE "vip_tier_histories"
    ADD CONSTRAINT "vip_tier_histories_userId_fkey"
    FOREIGN KEY ("userId") REFERENCES "users"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;

ALTER TABLE "vip_tier_histories"
    ADD CONSTRAINT "vip_tier_histories_changedById_fkey"
    FOREIGN KEY ("changedById") REFERENCES "users"("id")
    ON DELETE RESTRICT ON UPDATE CASCADE;

INSERT INTO "vip_tier_configurations" (
    "id",
    "tierCode",
    "displayName",
    "description",
    "minimumCumulativeDeposit",
    "displayOrder",
    "isActive",
    "createdAt",
    "updatedAt",
    "updatedById"
)
VALUES
    (gen_random_uuid()::text, 'STANDARD', '标准', '', NULL, 1, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, NULL),
    (gen_random_uuid()::text, 'SILVER', '白银', '', NULL, 2, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, NULL),
    (gen_random_uuid()::text, 'GOLD', '黄金', '', NULL, 3, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, NULL),
    (gen_random_uuid()::text, 'PLATINUM', '铂金', '', NULL, 4, true, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP, NULL);
