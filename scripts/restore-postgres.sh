#!/usr/bin/env bash
# Host PostgreSQL restore from custom-format dump. Requires pg_restore on PATH.
set -euo pipefail

INPUT_PATH="${1:-}"
DATABASE_URL="${DATABASE_URL:-}"

if [[ -z "$INPUT_PATH" ]]; then
  echo "Usage: $0 <input.dump>" >&2
  echo "Set DATABASE_URL or export it before running." >&2
  exit 1
fi

if [[ -z "$DATABASE_URL" ]]; then
  echo "DATABASE_URL is required." >&2
  exit 1
fi

if [[ ! -f "$INPUT_PATH" ]]; then
  echo "Dump file not found: $INPUT_PATH" >&2
  exit 1
fi

if ! command -v pg_restore >/dev/null 2>&1; then
  echo "pg_restore not found. Install PostgreSQL client tools." >&2
  exit 1
fi

pg_restore --dbname="$DATABASE_URL" --clean --if-exists --no-owner --exit-on-error "$INPUT_PATH"
echo "Restore completed from: $INPUT_PATH"
