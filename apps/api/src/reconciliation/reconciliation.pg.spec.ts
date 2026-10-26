import pg from 'pg';

function isIsolatedLocalTestDatabase(url: string | undefined) {
  if (!url) return false;
  try {
    const parsed = new URL(url);
    const database = parsed.pathname.replace(/^\//, '').split('?')[0];
    return (
      ['localhost', '127.0.0.1', 'postgres', '::1'].includes(parsed.hostname) &&
      /e2e|test|local|dev/i.test(database)
    );
  } catch {
    return false;
  }
}

const databaseUrl = process.env.DATABASE_URL;
const describePg =
  isIsolatedLocalTestDatabase(databaseUrl) && process.env.HNW_VERIFY_PG === '1'
    ? describe
    : describe.skip;

describePg(
  'Financial reconciliation migration on disposable PostgreSQL',
  () => {
    let client: pg.Client;
    beforeAll(async () => {
      client = new pg.Client({ connectionString: databaseUrl });
      await client.connect();
    });
    afterAll(async () => client.end());

    it('has auditable run and issue tables without balance mutation triggers', async () => {
      const tables = await client.query<{ table_name: string }>(
        `SELECT table_name FROM information_schema.tables
       WHERE table_schema = 'public' AND table_name IN ('reconciliation_runs', 'reconciliation_issues')
       ORDER BY table_name`,
      );
      expect(tables.rows.map((row) => row.table_name)).toEqual([
        'reconciliation_issues',
        'reconciliation_runs',
      ]);

      const triggers = await client.query(
        `SELECT trigger_name FROM information_schema.triggers
       WHERE event_object_table IN ('accounts', 'positions', 'orders', 'trades')
         AND action_statement ILIKE '%reconciliation%'`,
      );
      expect(triggers.rowCount).toBe(0);
    });
  },
);
