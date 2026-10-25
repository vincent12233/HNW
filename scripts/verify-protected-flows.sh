#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
mode="${1:-all}"

if [[ "$mode" != "all" && "$mode" != "--api-only" && "$mode" != "--flutter-only" ]]; then
  echo "Usage: $0 [--api-only|--flutter-only]" >&2
  exit 64
fi

if [[ "$mode" != "--flutter-only" ]]; then
  (
    cd "$repo_root/apps/api"
    npm test -- --runInBand auth/auth-register.characterization.spec.ts auth/auth-login.characterization.spec.ts deposit/deposit-self-serve.http.spec.ts trading/trading-path.characterization.spec.ts
  )
fi

if [[ "$mode" != "--api-only" ]]; then
  (
    cd "$repo_root/apps/client"
    flutter test test/protected_flows_contract_test.dart test/auth_kyc_characterization_test.dart test/order_idempotency_test.dart test/deposit_history_j1_test.dart test/password_recovery_lifecycle_test.dart
  )
fi

echo 'Protected flow contracts passed.'
