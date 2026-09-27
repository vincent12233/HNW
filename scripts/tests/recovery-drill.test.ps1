$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '../..')
$script = Join-Path $root 'scripts/recovery-drill.ps1'
$temp = Join-Path $root '.tmp-recovery-drill-test'

try {
  if (Test-Path -LiteralPath $temp) {
    Remove-Item -LiteralPath $temp -Recurse -Force
  }
  $objects = Join-Path $temp 'private-objects'
  $work = Join-Path $temp 'work'
  New-Item -ItemType Directory -Force -Path $objects | Out-Null
  Set-Content -LiteralPath (Join-Path $objects 'sample.txt') -Value 'sample' -Encoding utf8

  & $script `
    -SourceDatabaseUrl 'postgresql://source:source-secret@localhost:5432/hnw_source' `
    -DrillDatabaseUrl 'postgresql://drill:drill-secret@localhost:5432/hnw_drill' `
    -PrivateObjectRoot $objects `
    -WorkingDirectory $work `
    -PlanOnly

  $reportPath = Join-Path $work 'recovery-report.json'
  if (-not (Test-Path -LiteralPath $reportPath)) {
    throw 'Recovery drill did not create a report'
  }
  $raw = Get-Content -LiteralPath $reportPath -Raw
  $report = $raw | ConvertFrom-Json
  if ($report.status -ne 'PLANNED' -or -not $report.planOnly) {
    throw 'Recovery drill plan report has an invalid status'
  }
  if ($raw -match 'source-secret|drill-secret') {
    throw 'Recovery drill report leaked database credentials'
  }

  $rejected = $false
  try {
    & $script `
      -SourceDatabaseUrl 'postgresql://user:secret@localhost:5432/hnw' `
      -DrillDatabaseUrl 'postgresql://other:secret@localhost:5432/hnw' `
      -PrivateObjectRoot $objects `
      -WorkingDirectory (Join-Path $temp 'unsafe') `
      -PlanOnly
  } catch {
    $rejected = $_.Exception.Message -match 'database names must be different'
  }
  if (-not $rejected) {
    throw 'Recovery drill accepted the source database as the drill target'
  }

  Write-Host 'Recovery drill script tests passed.' -ForegroundColor Green
} finally {
  if (Test-Path -LiteralPath $temp) {
    Remove-Item -LiteralPath $temp -Recurse -Force
  }
}