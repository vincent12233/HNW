#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
if [[ -f "$ROOT/apps/api/prisma.config.ts" ]]; then
  cd "$ROOT/apps/api"
else
  cd "$ROOT"
fi

: "${DATABASE_URL:?Set DATABASE_URL to an empty, disposable PostgreSQL database}"
database_url="${DATABASE_URL%%\?*}"
if [[ "$database_url" == "$DATABASE_URL" ]]; then
  database_url="$DATABASE_URL"
fi

if [[ "$(psql "$database_url" -Atc 'SELECT count(*) FROM information_schema.tables WHERE table_schema = current_schema()')" != 0 ]]; then
  echo 'Upgrade test database must be empty' >&2
  exit 1
fi

latest="$(find prisma/migrations -mindepth 1 -maxdepth 1 -type d | LC_ALL=C sort | tail -n 1)"
if [[ -z "$latest" ]]; then
  echo 'No Prisma migrations found' >&2
  exit 1
fi

temporary_dir="$(mktemp -d)"
trap 'rm -rf "$temporary_dir"' EXIT
cp prisma/migrations/migration_lock.toml "$temporary_dir/"
for migration in prisma/migrations/*/; do
  [[ "${migration%/}" == "$latest" ]] || cp -R "$migration" "$temporary_dir/"
done

export HNW_UPGRADE_MIGRATIONS_PATH="$temporary_dir"
npx --no-install prisma migrate deploy --config prisma.upgrade-test.config.ts

psql "$database_url" -v ON_ERROR_STOP=1 <<'SQL'
INSERT INTO users ("id", "email", "passwordHash", "fullName", "createdAt", "updatedAt")
VALUES ('00000000-0000-4000-8000-000000000101', 'upgrade-client@example.invalid', 'test-hash', 'Upgrade Client', now(), now());
INSERT INTO accounts ("id", "accountNumber", "userId", "cashBalance", "buyingPower", "createdAt", "updatedAt")
VALUES ('00000000-0000-4000-8000-000000000102', 'UPGRADE-CI-001', '00000000-0000-4000-8000-000000000101', 100, 100, now(), now());
INSERT INTO account_transactions ("id", "accountId", "type", "status", "amount", "balanceBefore", "balanceAfter", "createdAt", "updatedAt")
VALUES ('00000000-0000-4000-8000-000000000103', '00000000-0000-4000-8000-000000000102', 'DEPOSIT', 'COMPLETED', 100, 0, 100, now(), now());
SQL

cp -R "$latest" "$temporary_dir/"
npx --no-install prisma migrate deploy --config prisma.upgrade-test.config.ts

psql "$database_url" -v ON_ERROR_STOP=1 <<'SQL'
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM users u
    JOIN accounts a ON a."userId" = u.id
    JOIN account_transactions t ON t."accountId" = a.id
    WHERE u.id = '00000000-0000-4000-8000-000000000101'
      AND a."cashBalance" = 100 AND a."buyingPower" = 100
      AND t."amount" = 100 AND t."balanceAfter" = 100
  ) THEN
    RAISE EXCEPTION 'Upgrade changed seeded account data';
  END IF;
END $$;
SQL

echo "Data-bearing migration upgrade passed: ${latest##*/}"
