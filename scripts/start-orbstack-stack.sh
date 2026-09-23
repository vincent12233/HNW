#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

command -v orbctl >/dev/null || { echo 'Install and start OrbStack first.' >&2; exit 1; }
command -v docker >/dev/null || { echo 'OrbStack Docker CLI is unavailable.' >&2; exit 1; }

if [[ "$(docker context show)" != orbstack ]]; then
  echo 'Docker context must be orbstack. Run: docker context use orbstack' >&2
  exit 1
fi

if [[ "$(orbctl status)" != Running ]]; then
  echo 'OrbStack is not running. Start OrbStack and retry.' >&2
  exit 1
fi

export HNW_E2E_DB_PASSWORD="${HNW_E2E_DB_PASSWORD:-HnwE2E_Local_2026_Strong!}"
docker compose -f "$ROOT/compose.local-test.yaml" up -d --build --wait --wait-timeout 300
docker compose -f "$ROOT/compose.local-test.yaml" ps

echo 'OrbStack test services are ready. API :3100 | Admin :3002 | Manager :3004 | Finance :3005 | Business :3006 | Support :3007'
