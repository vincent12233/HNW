#!/usr/bin/env tsx
/**
 * Preflight for financial integrity migration.
 * Read-only checks against the configured DATABASE_URL.
 * Exits non-zero if unique backfill or CHECK constraints would fail.
 */
import 'dotenv/config';
import pg from 'pg';

async function main() {
  const url = process.env.DATABASE_URL?.trim();
  if (!url) {
    console.error('DATABASE_URL is required');
    process.exit(2);
  }

  const parsed = new URL(url);
  const host = parsed.hostname;
  const database = parsed.pathname.replace(/^\//, '');
  const localHosts = new Set(['localhost', '127.0.0.1', 'postgres', '::1']);
  if (!localHosts.has(host) && !host.endsWith('.local')) {
    console.error(
      `Refusing preflight against non-local host "${host}". Use an isolated local-test database.`,
    );
    process.exit(2);
  }
  if (!/e2e|test|local|dev/i.test(database)) {
    console.error(
      `Refusing preflight against database "${database}". Name must look like a local/test DB.`,
    );
    process.exit(2);
  }

  const client = new pg.Client({ connectionString: url });
  await client.connect();
  try {
    const duplicateRefs = await client.query(`
      SELECT "referenceId", COUNT(*)::int AS count
      FROM "account_transactions"
      WHERE "referenceId" IS NOT NULL
        AND "type"::text <> 'IPO_REPAYMENT'
      GROUP BY "referenceId"
      HAVING COUNT(*) > 1
      ORDER BY count DESC
      LIMIT 20
    `);
    const negativeAccounts = await client.query(`
      SELECT id, "accountNumber", "cashBalance", "buyingPower", "frozenBalance"
      FROM "accounts"
      WHERE "cashBalance" < 0
         OR "buyingPower" < 0
         OR "frozenBalance" < 0
         OR "cashBalance" < "frozenBalance"
      LIMIT 20
    `);
    const badPositions = await client.query(`
      SELECT id, "accountId", quantity, "frozenQuantity"
      FROM "positions"
      WHERE quantity < 0
         OR "frozenQuantity" < 0
         OR "frozenQuantity" > quantity
      LIMIT 20
    `);

    console.log(
      JSON.stringify(
        {
          host,
          database,
          duplicateReferenceIds: duplicateRefs.rows,
          violatingAccounts: negativeAccounts.rows,
          violatingPositions: badPositions.rows,
          safe:
            duplicateRefs.rowCount === 0 &&
            negativeAccounts.rowCount === 0 &&
            badPositions.rowCount === 0,
        },
        null,
        2,
      ),
    );

    if (
      duplicateRefs.rowCount ||
      negativeAccounts.rowCount ||
      badPositions.rowCount
    ) {
      console.error('PREFLIGHT FAILED — do not apply migration until resolved.');
      process.exit(1);
    }
    console.log('PREFLIGHT PASSED');
  } finally {
    await client.end();
  }
}

main().catch((error: unknown) => {
  console.error(error instanceof Error ? error.message : error);
  process.exit(1);
});
