import { ConflictException } from '@nestjs/common';
import { Prisma } from '../generated/prisma/client';

type LedgerCreateInput = {
  accountId: string;
  type: Prisma.AccountTransactionCreateInput['type'];
  status?: Prisma.AccountTransactionCreateInput['status'];
  amount: Prisma.Decimal | number | string;
  balanceBefore: Prisma.Decimal | number | string;
  balanceAfter: Prisma.Decimal | number | string;
  referenceId?: string | null;
  note?: string | null;
  createdById?: string | null;
  idempotencyKey: string;
};

/**
 * Creates a ledger row once for a business event.
 * Replays with the same idempotencyKey return the existing row instead of
 * inserting a duplicate settlement / freeze / release / adjustment.
 */
export async function createLedgerEntryIdempotent(
  tx: Prisma.TransactionClient,
  input: LedgerCreateInput,
) {
  const idempotencyKey = input.idempotencyKey.trim();
  if (!idempotencyKey) {
    throw new ConflictException('Ledger idempotency key is required');
  }

  const existing = await tx.accountTransaction.findUnique({
    where: { idempotencyKey },
  });
  if (existing) {
    return { created: false as const, entry: existing };
  }

  try {
    const entry = await tx.accountTransaction.create({
      data: {
        accountId: input.accountId,
        type: input.type,
        status: input.status ?? 'COMPLETED',
        amount: input.amount,
        balanceBefore: input.balanceBefore,
        balanceAfter: input.balanceAfter,
        referenceId: input.referenceId ?? null,
        note: input.note ?? null,
        createdById: input.createdById ?? null,
        idempotencyKey,
      },
    });
    return { created: true as const, entry };
  } catch (error: unknown) {
    if (
      error instanceof Prisma.PrismaClientKnownRequestError &&
      error.code === 'P2002'
    ) {
      const replay = await tx.accountTransaction.findUnique({
        where: { idempotencyKey },
      });
      if (replay) {
        return { created: false as const, entry: replay };
      }
    }
    throw error;
  }
}
