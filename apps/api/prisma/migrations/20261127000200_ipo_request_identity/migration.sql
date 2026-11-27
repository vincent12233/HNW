-- Historical applications retain NULL request identity and their original financial records.
ALTER TABLE "IpoApplication" ADD COLUMN "requestId" TEXT, ADD COLUMN "response" JSONB;
CREATE UNIQUE INDEX "IpoApplication_accountId_ipoId_requestId_key" ON "IpoApplication" ("accountId", "ipoId", "requestId");
-- Report pre-existing excess; never delete or invent application/ledger history.
DO $$ DECLARE excess bigint;
BEGIN
 SELECT count(*) INTO excess FROM (SELECT 1 FROM "IpoApplication" GROUP BY "accountId", "ipoId" HAVING count(*) > 5) groups;
 IF excess > 0 THEN RAISE WARNING '% account/IPO groups already exceed five applications; preserved and blocked from new applications', excess; END IF;
END $$;
