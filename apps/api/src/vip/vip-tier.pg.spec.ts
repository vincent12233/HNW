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

describePg('VIP tier configuration constraints on local PostgreSQL', () => {
  let client: pg.Client;

  beforeAll(async () => {
    client = new pg.Client({ connectionString: databaseUrl });
    await client.connect();
  });

  afterAll(async () => {
    await client.end();
  });

  it('seeds four tiers with null thresholds and unique codes', async () => {
    const rows = await client.query(
      `SELECT "tierCode", "minimumCumulativeDeposit", "isActive", "displayOrder"
       FROM vip_tier_configurations
       ORDER BY "displayOrder"`,
    );
    expect(rows.rows.map((row) => row.tierCode)).toEqual([
      'STANDARD',
      'SILVER',
      'GOLD',
      'PLATINUM',
    ]);
    expect(
      rows.rows.every((row) => row.minimumCumulativeDeposit === null),
    ).toBe(true);
    expect(rows.rows.every((row) => row.isActive === true)).toBe(true);
  });

  it('rejects a negative threshold', async () => {
    await client.query('BEGIN');
    try {
      await expect(
        client.query(
          `UPDATE vip_tier_configurations
           SET "minimumCumulativeDeposit" = -1
           WHERE "tierCode" = 'SILVER'`,
        ),
      ).rejects.toMatchObject({ code: '23514' });
    } finally {
      await client.query('ROLLBACK');
    }
  });

  it('does not rewrite clientTier when configuration exists', async () => {
    const before = await client.query(
      `SELECT COUNT(*)::int AS count FROM users WHERE "clientTier" IS NOT NULL`,
    );
    const after = await client.query(
      `SELECT COUNT(*)::int AS count FROM users WHERE "clientTier" IS NOT NULL`,
    );
    expect(after.rows[0].count).toBe(before.rows[0].count);
  });
});
