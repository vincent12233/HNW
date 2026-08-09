ALTER TABLE "support_conversations"
ADD COLUMN "internalNote" TEXT,
ADD COLUMN "priority" TEXT NOT NULL DEFAULT '普通',
ADD COLUMN "assignedToId" TEXT;
