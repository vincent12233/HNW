CREATE TYPE "AppContentPublicationStatus" AS ENUM ('DRAFT', 'SCHEDULED', 'PUBLISHED', 'EXPIRED');

ALTER TABLE "app_content_entries"
  ADD COLUMN "publicationStatus" "AppContentPublicationStatus" NOT NULL DEFAULT 'PUBLISHED',
  ADD COLUMN "publishAt" TIMESTAMP(3),
  ADD COLUMN "expiresAt" TIMESTAMP(3),
  ADD COLUMN "version" INTEGER NOT NULL DEFAULT 1;

CREATE INDEX "app_content_entries_publicationStatus_publishAt_expiresAt_idx"
  ON "app_content_entries"("publicationStatus", "publishAt", "expiresAt");
