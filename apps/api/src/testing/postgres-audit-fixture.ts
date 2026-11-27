import { ConfigService } from '@nestjs/config';
import { PrismaService } from '../prisma/prisma.service';
import pg from 'pg';

const databaseUrl = process.env.DATABASE_URL;
export const auditPostgresEnabled = (() => {
  if (process.env.HNW_VERIFY_PG !== '1' || !databaseUrl) return false;
  const url = new URL(databaseUrl);
  return (
    ['localhost', '127.0.0.1', 'postgres', '::1'].includes(url.hostname) &&
    /test|ci|e2e|local|dev/i.test(url.pathname)
  );
})();

export function auditPrisma() {
  return new PrismaService(
    new ConfigService({
      DATABASE_URL: databaseUrl ?? 'postgresql://localhost/unused_test',
    }),
  );
}

// A separate connection holds the row while both real service connections reach it.
export async function withBlockedWriters<T>(
  lockSql: string,
  values: string[],
  queryFragment: string,
  operations: () => Promise<T>[],
): Promise<T[]> {
  const holder = new pg.Client({ connectionString: databaseUrl });
  const observer = new pg.Client({ connectionString: databaseUrl });
  await holder.connect();
  await observer.connect();
  let running: Promise<T>[] = [];
  try {
    await holder.query('BEGIN');
    await holder.query(lockSql, values);
    running = operations();
    // Install rejection handlers immediately while preserving results below.
    const results = Promise.allSettled(running);
    const deadline = Date.now() + 4000;
    let blocked = false;
    while (Date.now() < deadline) {
      const state = await observer.query<{ count: number }>(
        `SELECT COUNT(*)::int AS count FROM pg_stat_activity
         WHERE datname = current_database() AND wait_event_type = 'Lock'
           AND query LIKE $1`,
        [`%${queryFragment}%`],
      );
      if (state.rows[0].count >= running.length) {
        blocked = true;
        break;
      }
    }
    await holder.query('COMMIT');
    const settled = await results;
    if (!blocked)
      throw new Error(
        'Concurrent service connections did not reach the lock barrier',
      );
    return settled.map((result) => {
      if (result.status === 'rejected') throw result.reason;
      return result.value;
    });
  } finally {
    await holder.query('ROLLBACK');
    await Promise.allSettled(running);
    await holder.end();
    await observer.end();
  }
}
