[CmdletBinding()]
param(
  [switch]$ApiOnly,
  [switch]$FlutterOnly
)

$ErrorActionPreference = 'Stop'
$repoRoot = Split-Path -Parent $PSScriptRoot

if ($ApiOnly -and $FlutterOnly) {
  throw 'ApiOnly and FlutterOnly cannot be used together.'
}

if (-not $FlutterOnly) {
  Push-Location (Join-Path $repoRoot 'apps/api')
  try {
    npm test -- --runInBand auth/auth-register.characterization.spec.ts auth/auth-login.characterization.spec.ts deposit/deposit-self-serve.http.spec.ts trading/trading-path.characterization.spec.ts
    if ($LASTEXITCODE -ne 0) { throw 'Protected API contract tests failed.' }
  } finally {
    Pop-Location
  }
}

if (-not $ApiOnly) {
  Push-Location (Join-Path $repoRoot 'apps/client')
  try {
    flutter test test/protected_flows_contract_test.dart test/auth_kyc_characterization_test.dart test/order_idempotency_test.dart test/deposit_history_j1_test.dart test/password_recovery_lifecycle_test.dart
    if ($LASTEXITCODE -ne 0) { throw 'Protected Flutter contract tests failed.' }
  } finally {
    Pop-Location
  }
}

Write-Host 'Protected flow contracts passed.'
