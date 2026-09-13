CREATE TABLE "company_showcases" (
  "id" TEXT NOT NULL,
  "name" TEXT NOT NULL,
  "tagline" TEXT NOT NULL,
  "description" TEXT NOT NULL,
  "logoUrl" TEXT,
  "websiteUrl" TEXT,
  "sector" TEXT,
  "status" TEXT NOT NULL DEFAULT 'ACTIVE',
  "sortOrder" INTEGER NOT NULL DEFAULT 0,
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL,
  CONSTRAINT "company_showcases_pkey" PRIMARY KEY ("id")
);
CREATE INDEX "company_showcases_status_sortOrder_idx" ON "company_showcases"("status", "sortOrder");
