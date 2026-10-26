#!/usr/bin/env bash
set -euo pipefail
[[ "${HNW_CHAOS_CONFIRM:-}" == "isolated-disposable" ]] || { echo "Set HNW_CHAOS_CONFIRM=isolated-disposable. Never target production." >&2; exit 1; }
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCENARIO="${1:-all}"
allowed=(api redis postgres timescaledb market-feed outbox-worker)
targets=("${allowed[@]}")
if [[ "$SCENARIO" != all ]]; then
  [[ " ${allowed[*]} " == *" $SCENARIO "* ]] || { echo "Unknown scenario: $SCENARIO" >&2; exit 1; }
  targets=("$SCENARIO")
fi
for target in "${targets[@]}"; do
  echo "Testing isolated failure and recovery: $target"
  if [[ "$target" == market-feed || "$target" == outbox-worker ]]; then
    hook_var="HNW_CHAOS_FEED_HOOK"
    [[ "$target" == outbox-worker ]] && hook_var="HNW_CHAOS_WORKER_HOOK"
    hook="${!hook_var:-}"
    [[ -n "$hook" ]] || { echo "$hook_var must point to an approved isolated fault-injection script" >&2; exit 1; }
    "$hook"
    continue
  fi
  docker compose -f "$ROOT/compose.local-test.yaml" stop "$target"
  sleep 5
  docker compose -f "$ROOT/compose.local-test.yaml" start "$target"
  docker compose -f "$ROOT/compose.local-test.yaml" ps "$target"
done
echo "Failure matrix complete. Run reconciliation and attach zero-difference evidence."
