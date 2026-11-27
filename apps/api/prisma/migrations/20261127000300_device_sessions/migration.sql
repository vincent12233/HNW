-- Legacy display-only devices cannot be reliably associated with bearer credentials.
-- Existing access/refresh/biometric tokens without sid require password/Google reauthentication.
ALTER TABLE user_devices ADD COLUMN "sessionBound" BOOLEAN NOT NULL DEFAULT false;
UPDATE user_devices SET "revokedAt" = CURRENT_TIMESTAMP WHERE "revokedAt" IS NULL;
