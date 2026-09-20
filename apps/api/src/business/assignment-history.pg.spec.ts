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

describePg('Business manager assignment history on local PostgreSQL', () => {
  let client: pg.Client;

  beforeAll(async () => {
    client = new pg.Client({ connectionString: databaseUrl });
    await client.connect();
    await client.query(
      `INSERT INTO users (id, email, "passwordHash", "fullName", role, "clientTier", "updatedAt")
       VALUES
         ('pg-asg-admin', 'pg-asg-admin@test.local', 'x', 'Pg Admin', 'ADMIN', 'STANDARD', NOW()),
         ('pg-asg-mgr-a', 'pg-asg-mgr-a@test.local', 'x', 'Pg Mgr A', 'MANAGER', 'STANDARD', NOW()),
         ('pg-asg-mgr-b', 'pg-asg-mgr-b@test.local', 'x', 'Pg Mgr B', 'MANAGER', 'STANDARD', NOW()),
         ('pg-asg-biz', 'pg-asg-biz@test.local', 'x', 'Pg Biz', 'BUSINESS', 'STANDARD', NOW()),
         ('pg-asg-client', 'pg-asg-client@test.local', 'x', 'Pg Client', 'CLIENT', 'GOLD', NOW())
       ON CONFLICT (id) DO NOTHING`,
    );
    await client.query(
      `UPDATE users SET "businessCreatorId" = 'pg-asg-mgr-a' WHERE id = 'pg-asg-biz'`,
    );
    await client.query(
      `UPDATE users SET "assignedBusinessId" = 'pg-asg-biz' WHERE id = 'pg-asg-client'`,
    );
  });

  afterAll(async () => {
    await client.query(
      `DELETE FROM business_manager_assignment_histories WHERE id LIKE 'pg-asg-%'`,
    );
    await client.query(
      `UPDATE users SET "assignedBusinessId" = NULL, "businessCreatorId" = NULL
       WHERE id LIKE 'pg-asg-%'`,
    );
    await client.query(`DELETE FROM users WHERE id LIKE 'pg-asg-%'`);
    await client.end();
  });

  it('accepts a legal history row and unique idempotency key', async () => {
    await client.query('BEGIN');
    try {
      await client.query(
        `INSERT INTO business_manager_assignment_histories
           (id, "businessUserId", "previousManagerId", "newManagerId", reason, "changedById", "idempotencyKey", "clientCountAtChange")
         VALUES
           ('pg-asg-hist-1', 'pg-asg-biz', 'pg-asg-mgr-a', 'pg-asg-mgr-b', 'Rebalance', 'pg-asg-admin', 'pg-asg-idem-1', 1)`,
      );
      const rows = await client.query(
        `SELECT "idempotencyKey" FROM business_manager_assignment_histories WHERE id = 'pg-asg-hist-1'`,
      );
      expect(rows.rowCount).toBe(1);
      await expect(
        client.query(
          `INSERT INTO business_manager_assignment_histories
             (id, "businessUserId", "previousManagerId", "newManagerId", reason, "changedById", "idempotencyKey")
           VALUES
             ('pg-asg-hist-dup', 'pg-asg-biz', 'pg-asg-mgr-a', 'pg-asg-mgr-b', 'Replay', 'pg-asg-admin', 'pg-asg-idem-1')`,
        ),
      ).rejects.toMatchObject({ code: '23505' });
    } finally {
      await client.query('ROLLBACK');
    }
  });

  it('rejects an empty reason', async () => {
    await client.query('BEGIN');
    try {
      await expect(
        client.query(
          `INSERT INTO business_manager_assignment_histories
             (id, "businessUserId", "previousManagerId", "newManagerId", reason, "changedById", "idempotencyKey")
           VALUES
             ('pg-asg-hist-reason', 'pg-asg-biz', 'pg-asg-mgr-a', 'pg-asg-mgr-b', '   ', 'pg-asg-admin', 'pg-asg-idem-reason')`,
        ),
      ).rejects.toMatchObject({ code: '23514' });
    } finally {
      await client.query('ROLLBACK');
    }
  });

  it('rejects identical previous and new managers', async () => {
    await client.query('BEGIN');
    try {
      await expect(
        client.query(
          `INSERT INTO business_manager_assignment_histories
             (id, "businessUserId", "previousManagerId", "newManagerId", reason, "changedById", "idempotencyKey")
           VALUES
             ('pg-asg-hist-same', 'pg-asg-biz', 'pg-asg-mgr-a', 'pg-asg-mgr-a', 'Same', 'pg-asg-admin', 'pg-asg-idem-same')`,
        ),
      ).rejects.toMatchObject({ code: '23514' });
    } finally {
      await client.query('ROLLBACK');
    }
  });

  it('rejects an invalid foreign key', async () => {
    await client.query('BEGIN');
    try {
      await expect(
        client.query(
          `INSERT INTO business_manager_assignment_histories
             (id, "businessUserId", "previousManagerId", "newManagerId", reason, "changedById", "idempotencyKey")
           VALUES
             ('pg-asg-hist-fk', 'missing-user', 'pg-asg-mgr-a', 'pg-asg-mgr-b', 'Bad fk', 'pg-asg-admin', 'pg-asg-idem-fk')`,
        ),
      ).rejects.toMatchObject({ code: '23503' });
    } finally {
      await client.query('ROLLBACK');
    }
  });

  it('keeps client assignedBusinessId and VIP tier when only the manager owner changes', async () => {
    await client.query('BEGIN');
    try {
      await client.query(
        `UPDATE users SET "businessCreatorId" = 'pg-asg-mgr-b' WHERE id = 'pg-asg-biz'`,
      );
      await client.query(
        `INSERT INTO business_manager_assignment_histories
           (id, "businessUserId", "previousManagerId", "newManagerId", reason, "changedById", "idempotencyKey", "clientCountAtChange")
         VALUES
           ('pg-asg-hist-keep', 'pg-asg-biz', 'pg-asg-mgr-a', 'pg-asg-mgr-b', 'Move team', 'pg-asg-admin', 'pg-asg-idem-keep', 1)`,
      );
      const clientRow = await client.query(
        `SELECT "assignedBusinessId", "clientTier" FROM users WHERE id = 'pg-asg-client'`,
      );
      expect(clientRow.rows[0]).toEqual({
        assignedBusinessId: 'pg-asg-biz',
        clientTier: 'GOLD',
      });
    } finally {
      await client.query('ROLLBACK');
    }
  });

  it('rolls back the owner change when history insert fails', async () => {
    await client.query('BEGIN');
    try {
      await client.query(
        `UPDATE users SET "businessCreatorId" = 'pg-asg-mgr-b' WHERE id = 'pg-asg-biz'`,
      );
      await expect(
        client.query(
          `INSERT INTO business_manager_assignment_histories
             (id, "businessUserId", "previousManagerId", "newManagerId", reason, "changedById", "idempotencyKey")
           VALUES
             ('pg-asg-hist-rb', 'pg-asg-biz', 'pg-asg-mgr-b', 'pg-asg-mgr-b', 'No-op', 'pg-asg-admin', 'pg-asg-idem-rb')`,
        ),
      ).rejects.toMatchObject({ code: '23514' });
    } finally {
      await client.query('ROLLBACK');
    }
    const owner = await client.query(
      `SELECT "businessCreatorId" FROM users WHERE id = 'pg-asg-biz'`,
    );
    expect(owner.rows[0].businessCreatorId).toBe('pg-asg-mgr-a');
  });

  it('serializes concurrent transfers with FOR UPDATE', async () => {
    const second = new pg.Client({ connectionString: databaseUrl });
    await second.connect();
    try {
      await client.query('BEGIN');
      await client.query(
        `SELECT id FROM users WHERE id = 'pg-asg-biz' FOR UPDATE`,
      );
      await second.query("SET lock_timeout = '400ms'");
      await second.query('BEGIN');
      await expect(
        second.query(`SELECT id FROM users WHERE id = 'pg-asg-biz' FOR UPDATE`),
      ).rejects.toMatchObject({ code: '55P03' });
      await second.query('ROLLBACK');
    } finally {
      await client.query('ROLLBACK');
      await second.end();
    }
  });

  it('restricts deleting a referenced actor so history is retained', async () => {
    await client.query('BEGIN');
    try {
      await client.query(
        `INSERT INTO business_manager_assignment_histories
           (id, "businessUserId", "previousManagerId", "newManagerId", reason, "changedById", "idempotencyKey")
         VALUES
           ('pg-asg-hist-keep-actor', 'pg-asg-biz', 'pg-asg-mgr-a', 'pg-asg-mgr-b', 'Move', 'pg-asg-admin', 'pg-asg-idem-actor')`,
      );
      await client.query('SAVEPOINT after_insert');
      await expect(
        client.query(`DELETE FROM users WHERE id = 'pg-asg-admin'`),
      ).rejects.toMatchObject({ code: '23503' });
      await client.query('ROLLBACK TO SAVEPOINT after_insert');
      await expect(
        client.query(`DELETE FROM users WHERE id = 'pg-asg-biz'`),
      ).rejects.toMatchObject({ code: '23503' });
      await client.query('ROLLBACK TO SAVEPOINT after_insert');
      const kept = await client.query(
        `SELECT id FROM business_manager_assignment_histories WHERE id = 'pg-asg-hist-keep-actor'`,
      );
      expect(kept.rowCount).toBe(1);
    } finally {
      await client.query('ROLLBACK');
    }
  });
});
