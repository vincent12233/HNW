CREATE TABLE "kyc_submissions" (
  "id" TEXT PRIMARY KEY DEFAULT gen_random_uuid(),
  "userId" TEXT NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "businessUserId" TEXT NOT NULL REFERENCES "users"("id") ON DELETE CASCADE,
  "documentType" TEXT NOT NULL,
  "status" TEXT NOT NULL DEFAULT 'PENDING',
  "fileName" TEXT NOT NULL,
  "filePath" TEXT NOT NULL,
  "mimeType" TEXT,
  "recognizedType" TEXT,
  "recognizedText" TEXT,
  "reviewNote" TEXT,
  "reviewedById" TEXT REFERENCES "users"("id"),
  "reviewedAt" TIMESTAMP(3),
  "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "updatedAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX "kyc_submissions_userId_idx" ON "kyc_submissions"("userId");
CREATE INDEX "kyc_submissions_businessUserId_status_idx" ON "kyc_submissions"("businessUserId", "status");
