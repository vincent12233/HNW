-- Nullable for existing submissions; new submissions require both in the API.
ALTER TABLE "kyc_submissions"
ADD COLUMN "selfieFilePath" TEXT,
ADD COLUMN "selfieMimeType" TEXT,
ADD COLUMN "signatureFilePath" TEXT;
