import { createLedgerEntryIdempotent } from '../common/ledger-idempotency';

describe('financial history protection', () => {
  it('documents that Account.user uses onDelete Restrict in schema', async () => {
    const schema = await import('fs').then((fs) =>
      fs.promises.readFile('prisma/schema.prisma', 'utf8'),
    );
    expect(schema).toContain('model Account {');
    expect(schema).toMatch(
      /user\s+User\s+@relation\([^)]*onDelete:\s*Restrict/,
    );
    expect(schema).toContain('idempotencyKey String?');
  });

  it('keeps ledger rows when a soft-deleted user cannot authenticate', async () => {
    const ledger = {
      id: 'ledger-1',
      idempotencyKey: 'ORDER:order-1:SETTLEMENT',
    };
    const tx = {
      accountTransaction: {
        findUnique: jest.fn().mockResolvedValue(ledger),
        create: jest.fn(),
      },
    };
    const replay = await createLedgerEntryIdempotent(tx as never, {
      accountId: 'acct-1',
      type: 'TRADE_SETTLEMENT',
      amount: 1,
      balanceBefore: 10,
      balanceAfter: 9,
      idempotencyKey: 'ORDER:order-1:SETTLEMENT',
    });
    expect(replay.created).toBe(false);
    expect(replay.entry).toEqual(ledger);
    expect(tx.accountTransaction.create).not.toHaveBeenCalled();
  });
});
