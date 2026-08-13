CREATE TYPE "SupportStatus" AS ENUM ('OPEN', 'CLOSED');
CREATE TYPE "SenderType" AS ENUM ('CLIENT', 'SUPPORT', 'ADMIN');

CREATE TABLE "support_conversations" (
    "id" TEXT NOT NULL,
    "clientId" TEXT NOT NULL,
    "status" "SupportStatus" NOT NULL DEFAULT 'OPEN',
    "tags" TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[],
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,
    "updatedAt" TIMESTAMP(3) NOT NULL,

    CONSTRAINT "support_conversations_pkey" PRIMARY KEY ("id")
);

CREATE TABLE "support_messages" (
    "id" TEXT NOT NULL,
    "conversationId" TEXT NOT NULL,
    "senderId" TEXT NOT NULL,
    "senderType" "SenderType" NOT NULL,
    "content" TEXT NOT NULL,
    "createdAt" TIMESTAMP(3) NOT NULL DEFAULT CURRENT_TIMESTAMP,

    CONSTRAINT "support_messages_pkey" PRIMARY KEY ("id")
);

CREATE INDEX "support_conversations_clientId_idx" ON "support_conversations"("clientId");
CREATE INDEX "support_conversations_status_idx" ON "support_conversations"("status");
CREATE INDEX "support_messages_conversationId_idx" ON "support_messages"("conversationId");
CREATE INDEX "support_messages_senderId_idx" ON "support_messages"("senderId");

ALTER TABLE "support_conversations"
ADD CONSTRAINT "support_conversations_clientId_fkey"
FOREIGN KEY ("clientId") REFERENCES "users"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "support_messages"
ADD CONSTRAINT "support_messages_conversationId_fkey"
FOREIGN KEY ("conversationId") REFERENCES "support_conversations"("id") ON DELETE CASCADE ON UPDATE CASCADE;

ALTER TABLE "support_messages"
ADD CONSTRAINT "support_messages_senderId_fkey"
FOREIGN KEY ("senderId") REFERENCES "users"("id") ON DELETE RESTRICT ON UPDATE CASCADE;
