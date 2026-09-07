ALTER TYPE "UserRole" ADD VALUE 'MANAGER';
ALTER TABLE "users" ADD COLUMN "businessCreatorId" TEXT;
CREATE INDEX "users_businessCreatorId_idx" ON "users"("businessCreatorId");
ALTER TABLE "users" ADD CONSTRAINT "users_businessCreatorId_fkey" FOREIGN KEY ("businessCreatorId") REFERENCES "users"("id") ON DELETE SET NULL ON UPDATE CASCADE;
