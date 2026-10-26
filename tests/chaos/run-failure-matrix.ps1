param([string]$Scenario = "all")
$ErrorActionPreference = "Stop"
if ($env:HNW_CHAOS_CONFIRM -ne "isolated-disposable") {
  throw "Set HNW_CHAOS_CONFIRM=isolated-disposable. Chaos tests must never target production."
}
$root = Resolve-Path (Join-Path $PSScriptRoot "../..")
$compose = Join-Path $root "compose.local-test.yaml"
$allowed = @("api", "redis", "postgres", "timescaledb", "market-feed", "outbox-worker")
$targets = if ($Scenario -eq "all") { $allowed } elseif ($allowed -contains $Scenario) { @($Scenario) } else { throw "Unknown scenario: $Scenario" }
foreach ($target in $targets) {
  Write-Host "Testing isolated failure and recovery: $target"
  if ($target -eq "market-feed" -or $target -eq "outbox-worker") {
    $hookName = if ($target -eq "market-feed") { "HNW_CHAOS_FEED_HOOK" } else { "HNW_CHAOS_WORKER_HOOK" }
    $hook = [Environment]::GetEnvironmentVariable($hookName)
    if (-not $hook) { throw "$hookName must point to an approved isolated fault-injection script" }
    & $hook
    if ($LASTEXITCODE -ne 0) { throw "$target fault-injection hook failed" }
    continue
  }
  & docker compose -f $compose stop $target
  if ($LASTEXITCODE -ne 0) { throw "Failed to stop $target" }
  try { Start-Sleep -Seconds 5 } finally {
    & docker compose -f $compose start $target
    if ($LASTEXITCODE -ne 0) { throw "Failed to restart $target" }
  }
  & docker compose -f $compose ps $target
  if ($LASTEXITCODE -ne 0) { throw "$target did not recover" }
}
Write-Host "Failure matrix complete. Run reconciliation and attach zero-difference evidence."
