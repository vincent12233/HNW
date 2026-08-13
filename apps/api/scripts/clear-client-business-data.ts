import 'dotenv/config';

import { PrismaPg } from '@prisma/adapter-pg';
import { PrismaClient } from '../src/generated/prisma/client';

const connectionString = process.env.DATABASE_URL;

if (!connectionString) {
  throw new Error('DATABASE_URL is not configured');
}

const prisma = new PrismaClient({
  adapter: new PrismaPg({ connectionString }),
});

async function main() {
  const result = await prisma.$transaction(async (tx) => {
    const clients = await tx.$queryRaw<{ id: string }[]>`
      SELECT "id" FROM "users" WHERE "role" = 'CLIENT'
    `;
    const clientCount = clients.length;

    await tx.$executeRaw`
      UPDATE "invite_codes"
      SET "customerId" = NULL,
          "status" = 'UNUSED',
          "usedAt" = NULL,
          "updatedAt" = NOW()
      WHERE "customerId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
    `;

    await tx.$executeRaw`
      DELETE FROM "support_messages"
      WHERE "conversationId" IN (
        SELECT "id" FROM "support_conversations"
        WHERE "clientId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
      )
      OR "senderId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
    `;

    await tx.$executeRaw`
      DELETE FROM "support_conversations"
      WHERE "clientId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
    `;

    await tx.$executeRaw`
      DELETE FROM "ipo_debts"
      WHERE "accountId" IN (
        SELECT "id" FROM "accounts"
        WHERE "userId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
      )
    `;

    await tx.$executeRaw`
      DELETE FROM "IpoApplication"
      WHERE "accountId" IN (
        SELECT "id" FROM "accounts"
        WHERE "userId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
      )
    `;

    await tx.$executeRaw`
      DELETE FROM "loan_applications"
      WHERE "accountId" IN (
        SELECT "id" FROM "accounts"
        WHERE "userId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
      )
    `;

    await tx.$executeRaw`
      DELETE FROM "trades"
      WHERE "accountId" IN (
        SELECT "id" FROM "accounts"
        WHERE "userId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
      )
    `;

    await tx.$executeRaw`
      DELETE FROM "orders"
      WHERE "accountId" IN (
        SELECT "id" FROM "accounts"
        WHERE "userId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
      )
    `;

    await tx.$executeRaw`
      DELETE FROM "positions"
      WHERE "accountId" IN (
        SELECT "id" FROM "accounts"
        WHERE "userId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
      )
    `;

    await tx.$executeRaw`
      DELETE FROM "withdrawal_requests"
      WHERE "accountId" IN (
        SELECT "id" FROM "accounts"
        WHERE "userId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
      )
    `;

    await tx.$executeRaw`
      DELETE FROM "DepositRequest"
      WHERE "accountId" IN (
        SELECT "id" FROM "accounts"
        WHERE "userId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
      )
    `;

    await tx.$executeRaw`
      DELETE FROM "account_transactions"
      WHERE "accountId" IN (
        SELECT "id" FROM "accounts"
        WHERE "userId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
      )
      OR "createdById" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
    `;

    await tx.$executeRaw`
      DELETE FROM "kyc_submissions"
      WHERE "userId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
    `;

    await tx.$executeRaw`
      DELETE FROM "login_audits"
      WHERE "userId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
    `;

    await tx.$executeRaw`DELETE FROM "audit_logs"`;

    await tx.$executeRaw`
      DELETE FROM "accounts"
      WHERE "userId" IN (SELECT "id" FROM "users" WHERE "role" = 'CLIENT')
    `;

    await tx.$executeRaw`DELETE FROM "users" WHERE "role" = 'CLIENT'`;

    return { clientCount };
  });

  console.log(
    JSON.stringify(
      {
        ok: true,
        deletedClientCount: result.clientCount,
        preserved: [
          'staff users',
          'business profiles',
          'unused invite codes',
          'market instruments',
          'IPO definitions',
          'admin products',
        ],
      },
      null,
      2,
    ),
  );
}

main()
  .catch((error) => {
    console.error(error);
    process.exitCode = 1;
  })
  .finally(async () => {
    await prisma.$disconnect();
  });
