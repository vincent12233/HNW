CREATE TYPE "TimeInForce" AS ENUM ('DAY', 'IOC', 'FOK');

ALTER TABLE "orders"
ADD COLUMN "timeInForce" "TimeInForce" NOT NULL DEFAULT 'DAY';
