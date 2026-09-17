# Isolated local PostgreSQL funding concurrency suite.
# Does not delete Docker volumes, drop non-test databases, or write .env.
$ErrorActionPreference = "Stop"
$Root = Resolve-Path (Join-Path $PSScriptRoot "..\..")
$ComposeFile = Join-Path $Root "compose.local-test.yaml"
$ApiDir = Join-Path $Root "apps\api"

. (Join-Path $PSScriptRoot "assert-funding-integration-url.ps1")

if (-not $env:FUNDING_INTEGRATION_DATABASE_URL) {
  if (-not $env:HNW_E2E_DB_PASSWORD) {
    Write-Error "Set FUNDING_INTEGRATION_DATABASE_URL or HNW_E2E_DB_PASSWORD. Example: postgresql://hnw_test:PASSWORD@127.0.0.1:55432/hnw_funding_integration?schema=public"
  }
  $env:FUNDING_INTEGRATION_DATABASE_URL = "postgresql://hnw_test:$($env:HNW_E2E_DB_PASSWORD)@127.0.0.1:55432/hnw_funding_integration?schema=public"
}

Assert-FundingIntegrationDatabaseUrl -Url $env:FUNDING_INTEGRATION_DATABASE_URL

# Prisma migrate deploy reads DATABASE_URL. Assign only after the URL is proven local/test.
$env:DATABASE_URL = $env:FUNDING_INTEGRATION_DATABASE_URL

if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
  Write-Error "Docker is required to start compose.local-test.yaml PostgreSQL 17."
}

$running = docker compose -f $ComposeFile ps --status running postgres 2>$null
if (-not $running) {
  Write-Host "Starting local compose PostgreSQL 17 (no volume delete)..."
  docker compose -f $ComposeFile up -d postgres
}

$exists = docker compose -f $ComposeFile exec -T postgres psql -U hnw_test -d postgres -tc "SELECT 1 FROM pg_database WHERE datname='hnw_funding_integration'"
if ($exists -notmatch "1") {
  docker compose -f $ComposeFile exec -T postgres psql -U hnw_test -d postgres -c "CREATE DATABASE hnw_funding_integration"
}

Set-Location $ApiDir
npx prisma migrate deploy
npm run test:funding:integration
