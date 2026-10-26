import pg from 'pg';
import { runSerializableTransaction } from '../common/transaction-retry';

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
  isIsolatedLocalTestDatabase(databaseUrl) && process.env.HNW_VERIFY_PG === '1'
    ? describe
    : describe.skip;

describePg('Order concurrency on disposable PostgreSQL', () => {
  let pool: pg.Pool;

  beforeAll(async () => {
    pool = new pg.Pool({ connectionString: databaseUrl, max: 4 });
    await pool.query('DROP TABLE IF EXISTS hnw_order_concurrency_test');
    await pool.query(
      'CREATE TABLE hnw_order_concurrency_test (id integer PRIMARY KEY, balance integer NOT NULL)',
    );
  });

  afterAll(async () => {
    await pool.query('DROP TABLE IF EXISTS hnw_order_concurrency_test');
    await pool.end();
  });

  it('retries one simultaneous serializable command without losing money', async () => {
    await pool.query(
      'INSERT INTO hnw_order_concurrency_test (id, balance) VALUES (1, 100)',
    );

    let firstReads = 0;
    let releaseFirstReads: (() => void) | undefined;
    const bothRead = new Promise<void>((resolve) => {
      releaseFirstReads = resolve;
    });

    const increment = () =>
      runSerializableTransaction(
        async (attempt) => {
          const client = await pool.connect();
          try {
            await client.query('BEGIN ISOLATION LEVEL SERIALIZABLE');
            const result = await client.query<{ balance: number }>(
              'SELECT balance FROM hnw_order_concurrency_test WHERE id = 1',
            );
            if (attempt === 1) {
              firstReads += 1;
              if (firstReads === 2) releaseFirstReads?.();
              await bothRead;
            }
            await client.query(
              'UPDATE hnw_order_concurrency_test SET balance = $1 WHERE id = 1',
              [result.rows[0].balance + 10],
            );
            await client.query('COMMIT');
          } catch (error: unknown) {
            await client.query('ROLLBACK');
            throw error;
          } finally {
            client.release();
          }
        },
        {
          baseDelayMs: 1,
          isRetryable: (error) =>
            typeof error === 'object' &&
            error !== null &&
            'code' in error &&
            (error as { code?: unknown }).code === '40001',
        },
      );

    await Promise.all([increment(), increment()]);

    const final = await pool.query<{ balance: number }>(
      'SELECT balance FROM hnw_order_concurrency_test WHERE id = 1',
    );
    expect(final.rows[0].balance).toBe(120);
  });
});
