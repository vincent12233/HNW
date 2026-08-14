ALTER TABLE "withdrawal_requests"
ADD COLUMN "frozenAmount" DECIMAL(18, 2) NOT NULL DEFAULT 0;
