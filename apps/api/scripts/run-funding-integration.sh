#!/usr/bin/env bash
set -euo pipefail

# Isolated local PostgreSQL funding concurrency suite.
# Does not delete Docker volumes, drop non-test databases, or write .env.

ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
COMPOSE_FILE="$ROOT/compose.local-test.yaml"
API_DIR="$ROOT/apps/api"

if [[ -z "${FUNDING_INTEGRATION_DATABASE_URL:-}" ]]; then
  if [[ -z "${HNW_E2E_DB_PASSWORD:-}" ]]; then
    echo "Set FUNDING_INTEGRATION_DATABASE_URL or HNW_E2E_DB_PASSWORD." >&2
    echo "Example: postgresql://hnw_test:PASSWORD@127.0.0.1:55432/hnw_funding_integration?schema=public" >&2
    exit 1
  fi
  FUNDING_INTEGRATION_DATABASE_URL="postgresql://hnw_test:${HNW_E2E_DB_PASSWORD}@127.0.0.1:55432/hnw_funding_integration?schema=public"
fi

python3 "$ROOT/apps/api/scripts/assert-funding-integration-url.py" \
  "$FUNDING_INTEGRATION_DATABASE_URL"

export FUNDING_INTEGRATION_DATABASE_URL
# Prisma migrate deploy reads DATABASE_URL. Point it only at the isolated test DB.
export DATABASE_URL="$FUNDING_INTEGRATION_DATABASE_URL"

if ! command -v docker >/dev/null 2>&1; then
  echo "Docker is required to start compose.local-test.yaml PostgreSQL 17." >&2
  exit 1
fi

echo "Ensuring local compose PostgreSQL 17 is up (no volume delete)..."
docker compose -f "$COMPOSE_FILE" up -d postgres
for _ in $(seq 1 30); do
  if docker compose -f "$COMPOSE_FILE" exec -T postgres pg_isready -U hnw_test >/dev/null 2>&1; then
    break
  fi
  sleep 1
done


docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U hnw_test -d postgres -tc \
  "SELECT 1 FROM pg_database WHERE datname='hnw_funding_integration'" | grep -q 1 \
  || docker compose -f "$COMPOSE_FILE" exec -T postgres psql -U hnw_test -d postgres -c \
    "CREATE DATABASE hnw_funding_integration"

cd "$API_DIR"
npx prisma migrate deploy
npm run test:funding:integration
