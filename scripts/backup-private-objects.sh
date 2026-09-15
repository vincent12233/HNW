#!/usr/bin/env bash
# Archive PRIVATE_OBJECT_ROOT (KYC documents live on disk, not in Postgres).
set -euo pipefail

OUTPUT_PATH="${1:-}"
ROOT="${PRIVATE_OBJECT_ROOT:-}"

if [[ -z "$OUTPUT_PATH" ]]; then
  echo "Usage: $0 <output.tar.gz>" >&2
  echo "Set PRIVATE_OBJECT_ROOT to the absolute storage directory." >&2
  exit 1
fi

if [[ -z "$ROOT" || "$ROOT" != /* ]]; then
  echo "PRIVATE_OBJECT_ROOT must be an absolute path." >&2
  exit 1
fi

if [[ ! -d "$ROOT" ]]; then
  echo "PRIVATE_OBJECT_ROOT directory not found: $ROOT" >&2
  exit 1
fi

mkdir -p "$(dirname "$OUTPUT_PATH")"
tar -C "$(dirname "$ROOT")" -czf "$OUTPUT_PATH" "$(basename "$ROOT")"
echo "Private object backup written: $OUTPUT_PATH"
