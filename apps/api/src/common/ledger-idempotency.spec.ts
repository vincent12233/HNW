import { createLedgerEntryIdempotent } from './ledger-idempotency';
import { Prisma } from '../generated/prisma/client';

describe('createLedgerEntryIdempotent', () => {
  it('creates a ledger row once and replays the same idempotency key', async () => {
    const created = {
      id: 'tx-1',
      idempotencyKey: 'ORDER:order-1:FREEZE',
    };
    const tx = {
      accountTransaction: {
        findUnique: jest
          .fn()
          .mockResolvedValueOnce(null)
          .mockResolvedValueOnce(created)
          .mockResolvedValueOnce(created),
        create: jest.fn().mockResolvedValue(created),
      },
    };

    const first = await createLedgerEntryIdempotent(tx as never, {
      accountId: 'acct-1',
      type: 'ORDER_FREEZE',
      amount: new Prisma.Decimal(-10),
      balanceBefore: new Prisma.Decimal(100),
      balanceAfter: new Prisma.Decimal(100),
      referenceId: 'ORDER:order-1:FREEZE',
      idempotencyKey: 'ORDER:order-1:FREEZE',
    });
    const second = await createLedgerEntryIdempotent(tx as never, {
      accountId: 'acct-1',
      type: 'ORDER_FREEZE',
      amount: new Prisma.Decimal(-10),
      balanceBefore: new Prisma.Decimal(100),
      balanceAfter: new Prisma.Decimal(100),
      referenceId: 'ORDER:order-1:FREEZE',
      idempotencyKey: 'ORDER:order-1:FREEZE',
    });

    expect(first.created).toBe(true);
    expect(second.created).toBe(false);
    expect(tx.accountTransaction.create).toHaveBeenCalledTimes(1);
    expect(second.entry).toEqual(created);
  });

  it('allows different execution settlements for partial fills', async () => {
    const tx = {
      accountTransaction: {
        findUnique: jest.fn().mockResolvedValue(null),
        create: jest
          .fn()
          .mockResolvedValueOnce({ id: 'tx-a' })
          .mockResolvedValueOnce({ id: 'tx-b' }),
      },
    };

    const first = await createLedgerEntryIdempotent(tx as never, {
      accountId: 'acct-1',
      type: 'TRADE_SETTLEMENT',
      amount: new Prisma.Decimal(-50),
      balanceBefore: new Prisma.Decimal(100),
      balanceAfter: new Prisma.Decimal(50),
      referenceId: 'EXECUTION:exec-1:SETTLEMENT',
      idempotencyKey: 'EXECUTION:exec-1:SETTLEMENT',
    });
    const second = await createLedgerEntryIdempotent(tx as never, {
      accountId: 'acct-1',
      type: 'TRADE_SETTLEMENT',
      amount: new Prisma.Decimal(-25),
      balanceBefore: new Prisma.Decimal(50),
      balanceAfter: new Prisma.Decimal(25),
      referenceId: 'EXECUTION:exec-2:SETTLEMENT',
      idempotencyKey: 'EXECUTION:exec-2:SETTLEMENT',
    });

    expect(first.created).toBe(true);
    expect(second.created).toBe(true);
    expect(tx.accountTransaction.create).toHaveBeenCalledTimes(2);
  });

  it('treats concurrent unique violations as idempotent replays', async () => {
    const existing = { id: 'tx-race', idempotencyKey: 'REF-1' };
    const tx = {
      accountTransaction: {
        findUnique: jest
          .fn()
          .mockResolvedValueOnce(null)
          .mockResolvedValueOnce(existing),
        create: jest.fn().mockRejectedValue(
          new Prisma.PrismaClientKnownRequestError('Unique constraint', {
            code: 'P2002',
            clientVersion: 'test',
          }),
        ),
      },
    };

    const result = await createLedgerEntryIdempotent(tx as never, {
      accountId: 'acct-1',
      type: 'ADMIN_CREDIT',
      amount: new Prisma.Decimal(10),
      balanceBefore: new Prisma.Decimal(0),
      balanceAfter: new Prisma.Decimal(10),
      referenceId: 'REF-1',
      idempotencyKey: 'REF-1',
    });

    expect(result).toEqual({ created: false, entry: existing });
  });
});
