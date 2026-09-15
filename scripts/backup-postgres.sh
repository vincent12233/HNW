#!/usr/bin/env bash
# Host PostgreSQL backup (custom format). Requires pg_dump on PATH.
set -euo pipefail

OUTPUT_PATH="${1:-}"
DATABASE_URL="${DATABASE_URL:-}"

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "Usage: $0 <output.dump>" >&2
  echo "Set DATABASE_URL or export it before running." >&2
  exit 1
fi

if [[ -z "$DATABASE_URL" ]]; then
  echo "DATABASE_URL is required." >&2
  exit 1
fi

if ! command -v pg_dump >/dev/null 2>&1; then
  echo "pg_dump not found. Install PostgreSQL client tools." >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
pg_dump --dbname="$DATABASE_URL" --format=custom --compress=9 --file="$OUTPUT_PATH"
echo "Backup written: $OUTPUT_PATH"
