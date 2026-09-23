#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

run_api() {
  cd "$ROOT/apps/api"
  [[ -d node_modules ]] || npm ci
  npm run db:generate
  if [[ -n "${DATABASE_URL:-}" ]]; then
    npm run db:migrate
  fi
  npm run lint
  npm test -- --runInBand
  npm run build
}

run_admin() {
  cd "$ROOT/apps/admin"
  [[ -d node_modules ]] || npm ci
  npm run lint
  npm test
  npx --no-install tsc --noEmit
  npm run build
}

run_client() {
  cd "$ROOT/apps/client"
  flutter pub get --enforce-lockfile
  flutter analyze --no-fatal-infos
  flutter test
}

command -v npm >/dev/null || { echo "npm is required" >&2; exit 1; }
command -v flutter >/dev/null || { echo "flutter is required" >&2; exit 1; }
node_major="$(node -p 'process.versions.node.split(".")[0]')"
if (( node_major < 24 )); then
  echo "Node.js 24 or newer is required; found $(node --version)" >&2
  exit 1
fi

echo "== API =="
run_api
echo "== Admin =="
run_admin
echo "== Client =="
run_client
echo "All selected checks passed."
