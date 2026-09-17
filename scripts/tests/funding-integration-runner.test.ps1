# Prove the Windows funding runner validates URLs before DATABASE_URL or migrate.
$ErrorActionPreference = 'Stop'
$helper = Join-Path $PSScriptRoot '..\..\apps\api\scripts\assert-funding-integration-url.ps1'
$runner = Join-Path $PSScriptRoot '..\..\apps\api\scripts\run-funding-integration.ps1'
. $helper

function Assert-ThrowsLike {
  param(
    [Parameter(Mandatory = $true)][scriptblock]$Block,
    [Parameter(Mandatory = $true)][string]$Like
  )
  $failed = $false
  try {
    & $Block | Out-Null
  } catch {
    $failed = $true
    $message = [string]$_.Exception.Message
    if ($message -notlike $Like) {
      throw "Expected error like '$Like', received: $message"
    }
  }
  if (-not $failed) {
    throw "Expected the block to fail like '$Like'"
  }
}

Assert-ThrowsLike {
  Assert-FundingIntegrationDatabaseUrl 'postgresql://user:pass@db.production.com:5432/hnw_integration'
} '*Refusing host*'
Write-Host 'PASS: remote host rejected'

Assert-ThrowsLike {
  Assert-FundingIntegrationDatabaseUrl 'postgresql://user:pass@127.0.0.1:5432/hnw_production'
} '*Refusing database*'
Write-Host 'PASS: local host + production database name rejected'

Assert-ThrowsLike {
  Assert-FundingIntegrationDatabaseUrl 'postgresql://user:pass@10.0.0.10:5432/hnw_test'
} '*Refusing host*'
Write-Host 'PASS: private remote host rejected'

Assert-ThrowsLike {
  Assert-FundingIntegrationDatabaseUrl 'postgresql://user:pass@localhost:5432/hnw_prod'
} '*Refusing database*'
Write-Host 'PASS: localhost + prod database name rejected'

$accepted = @(
  'postgresql://hnw_test:supersecret@127.0.0.1:55432/hnw_funding_integration',
  'postgresql://hnw_test:supersecret@localhost:55432/hnw_test',
  'postgresql://hnw_test:supersecret@postgres:5432/hnw_e2e'
)
foreach ($url in $accepted) {
  $output = Assert-FundingIntegrationDatabaseUrl -Url $url | Out-String
  if ($output -match 'supersecret' -or $output -match 'pass') {
    throw 'Helper logged a secret'
  }
  if ($output -notmatch 'Using isolated database') {
    throw "Expected host/database log, received: $output"
  }
}
Write-Host 'PASS: local integration database names accepted without secrets'

$originalDatabaseUrl = $env:DATABASE_URL
$originalFundingUrl = $env:FUNDING_INTEGRATION_DATABASE_URL
$originalPassword = $env:HNW_E2E_DB_PASSWORD
$global:dockerInvoked = $false
$global:npxInvoked = $false
function docker { $global:dockerInvoked = $true; throw 'docker must not run before a valid URL' }
function npx { $global:npxInvoked = $true; throw 'npx must not run before a valid URL' }

try {
  $env:DATABASE_URL = 'postgresql://sentinel:keep-me-out-of-logs@127.0.0.1:5432/hnw_sentinel_test'
  $env:FUNDING_INTEGRATION_DATABASE_URL = 'postgresql://user:pass@db.production.com:5432/hnw_integration'
  Remove-Item Env:HNW_E2E_DB_PASSWORD -ErrorAction SilentlyContinue
  $failure = $null
  try {
    & $runner
  } catch {
    $failure = $_
  }
  if (-not $failure) {
    throw 'Runner must exit non-zero for an unsafe URL'
  }
  if ($env:DATABASE_URL -ne 'postgresql://sentinel:keep-me-out-of-logs@127.0.0.1:5432/hnw_sentinel_test') {
    throw 'DATABASE_URL was assigned before validation failed'
  }
  if ($global:dockerInvoked) {
    throw 'docker ran despite an invalid URL'
  }
  if ($global:npxInvoked) {
    throw 'npx/migrate ran despite an invalid URL'
  }
  Write-Host 'PASS: invalid URL never reaches DATABASE_URL assignment, docker, or migrate'
} finally {
  [Environment]::SetEnvironmentVariable('DATABASE_URL', $originalDatabaseUrl, 'Process')
  [Environment]::SetEnvironmentVariable('FUNDING_INTEGRATION_DATABASE_URL', $originalFundingUrl, 'Process')
  [Environment]::SetEnvironmentVariable('HNW_E2E_DB_PASSWORD', $originalPassword, 'Process')
}

Write-Host 'funding integration Windows runner guard checks passed.'
$global:LASTEXITCODE = 0
