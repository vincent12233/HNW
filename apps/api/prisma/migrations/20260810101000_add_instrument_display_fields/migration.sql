ALTER TABLE "instruments"
ADD COLUMN "logoUrl" TEXT,
ADD COLUMN "category" TEXT,
ADD COLUMN "displayOrder" INTEGER NOT NULL DEFAULT 0;

CREATE INDEX "instruments_displayOrder_idx" ON "instruments"("displayOrder");
