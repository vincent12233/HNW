-- Additive only: client update destination for force/optional update CTAs.
-- Null is allowed; clients must not hard-lock when missing/invalid.
ALTER TABLE "app_client_settings" ADD COLUMN "updateUrl" TEXT;
