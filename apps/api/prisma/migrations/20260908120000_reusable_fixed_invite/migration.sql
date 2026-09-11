ALTER TABLE "users" ADD COLUMN "usedInviteCodeId" TEXT;

UPDATE "users" AS u
SET "usedInviteCodeId" = i."id"
FROM "invite_codes" AS i
WHERE i."customerId" = u."id";

ALTER TABLE "invite_codes" DROP CONSTRAINT IF EXISTS "invite_codes_customerId_fkey";
DROP INDEX IF EXISTS "invite_codes_customerId_key";
ALTER TABLE "invite_codes" DROP COLUMN "customerId";

CREATE INDEX "users_usedInviteCodeId_idx" ON "users"("usedInviteCodeId");
ALTER TABLE "users"
ADD CONSTRAINT "users_usedInviteCodeId_fkey"
FOREIGN KEY ("usedInviteCodeId") REFERENCES "invite_codes"("id")
ON DELETE SET NULL ON UPDATE CASCADE;
