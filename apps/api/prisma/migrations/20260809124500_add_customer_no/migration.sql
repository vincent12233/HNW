ALTER TABLE "users" ADD COLUMN "customerNo" TEXT;

UPDATE "users"
SET "customerNo" = 'C' || UPPER(SUBSTRING(REPLACE("id", '-', ''), 1, 10))
WHERE "role" = 'CLIENT'
  AND "customerNo" IS NULL;

CREATE UNIQUE INDEX "users_customerNo_key"
  ON "users"("customerNo")
  WHERE "customerNo" IS NOT NULL;
