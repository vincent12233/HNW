import pg from 'pg';

function isIsolatedLocalTestDatabase(url: string | undefined) {
  if (!url) return false;
  try {
    const parsed = new URL(url);
    const host = parsed.hostname;
    const database = parsed.pathname.replace(/^\//, '').split('?')[0];
    const localHosts = new Set(['localhost', '127.0.0.1', 'postgres', '::1']);
    const dockerDns = !host.includes('.') && host !== 'localhost';
    return (
      (localHosts.has(host) || host.endsWith('.local') || dockerDns) &&
      /e2e|test|local|dev/i.test(database)
    );
  } catch {
    return false;
  }
}

const databaseUrl = process.env.DATABASE_URL;
const describePg =
  isIsolatedLocalTestDatabase(databaseUrl) &&
  process.env.HNW_VERIFY_PG === '1'
    ? describe
    : describe.skip;

describePg('Current financial integrity constraints on local PostgreSQL', () => {
  let client: pg.Client;

  beforeAll(async () => {
    client = new pg.Client({ connectionString: databaseUrl });
    await client.connect();
  });

  afterAll(async () => {
    await client.end();
  });

  it('keeps the Phase 1C check constraints and IPO_REPAYMENT enum', async () => {
    const constraints = await client.query(
      `SELECT conname FROM pg_constraint
       WHERE conname IN (
         'accounts_cash_nonneg',
         'accounts_buying_power_nonneg',
         'accounts_frozen_nonneg',
         'accounts_cash_covers_frozen',
         'positions_quantity_nonneg',
         'positions_frozen_quantity_nonneg',
         'positions_frozen_lte_quantity'
       )
       ORDER BY 1`,
    );
    expect(constraints.rows.map((row) => row.conname)).toEqual([
      'accounts_buying_power_nonneg',
      'accounts_cash_covers_frozen',
      'accounts_cash_nonneg',
      'accounts_frozen_nonneg',
      'positions_frozen_lte_quantity',
      'positions_frozen_quantity_nonneg',
      'positions_quantity_nonneg',
    ]);

    const enumValues = await client.query(
      `SELECT enumlabel FROM pg_enum e
       JOIN pg_type t ON t.oid = e.enumtypid
       WHERE t.typname = 'AccountTransactionType'
         AND enumlabel = 'IPO_REPAYMENT'`,
    );
    expect(enumValues.rowCount).toBe(1);

    const unique = await client.query(
      `SELECT indexname FROM pg_indexes
       WHERE indexname = 'account_transactions_idempotencyKey_key'`,
    );
    expect(unique.rowCount).toBe(1);
  });

  it('rejects a negative cash balance with the current CHECK', async () => {
    await client.query('BEGIN');
    try {
      await client.query(
        `INSERT INTO users (id, email, "passwordHash", "fullName", "updatedAt")
         VALUES ('pg-neg-cash', 'pg-neg-cash@test.local', 'x', 'Pg Neg', NOW())`,
      );
      await expect(
        client.query(
          `INSERT INTO accounts (id, "accountNumber", "cashBalance", "userId", "updatedAt")
           VALUES ('pg-neg-acct', 'ACC-PG-NEG', -1.00, 'pg-neg-cash', NOW())`,
        ),
      ).rejects.toMatchObject({ code: '23514' });
    } finally {
      await client.query('ROLLBACK');
    }
  });
});
