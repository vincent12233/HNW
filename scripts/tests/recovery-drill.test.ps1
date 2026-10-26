$ErrorActionPreference = 'Stop'
$root = Resolve-Path (Join-Path $PSScriptRoot '../..')
$script = Join-Path $root 'scripts/recovery-drill.ps1'
$integrity = Join-Path $root 'scripts/recovery-integrity.ps1'
$temp = Join-Path $root '.tmp-recovery-drill-test'

try {
  if (Test-Path -LiteralPath $temp) {
    Remove-Item -LiteralPath $temp -Recurse -Force
  }
  $objects = Join-Path $temp 'private-objects'
  $work = Join-Path $temp 'work'
  New-Item -ItemType Directory -Force -Path $objects | Out-Null
  Set-Content -LiteralPath (Join-Path $objects 'sample.txt') -Value 'sample' -Encoding utf8
  . $integrity
  $checksumFixture = Join-Path $temp 'checksum.txt'
  Set-Content -LiteralPath $checksumFixture -Value 'original' -Encoding utf8
  $expectedChecksum = Get-RecoveryFileSha256 $checksumFixture
  Set-Content -LiteralPath $checksumFixture -Value 'tampered' -Encoding utf8
  $checksumRejected = $false
  try { Assert-RecoveryFileChecksum $checksumFixture $expectedChecksum } catch {
    $checksumRejected = $_.Exception.Message -match 'checksum mismatch'
  }
  if (-not $checksumRejected) { throw 'Recovery integrity check accepted a modified artifact' }

  & $script `
    -CommitSha ('a' * 40) `
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
  if ($report.commitSha -ne ('a' * 40) -or $report.externalEvidenceComplete) {
    throw 'Recovery report is not commit-bound or overstates external evidence'
  }
  if ('backupSha256' -notin $report.database.PSObject.Properties.Name -or 'restoreInputSha256' -notin $report.database.PSObject.Properties.Name -or 'checksumMatch' -notin $report.database.PSObject.Properties.Name -or 'backupSha256' -notin $report.privateObjects.PSObject.Properties.Name -or 'restoreInputSha256' -notin $report.privateObjects.PSObject.Properties.Name -or 'checksumMatch' -notin $report.privateObjects.PSObject.Properties.Name) {
    throw 'Recovery report does not reserve checksum evidence fields'
  }
  if ($null -eq $report.financialReconciliation -or $report.financialReconciliation.status -ne 'NOT_EXECUTED') {
    throw 'Recovery plan must explicitly mark financial reconciliation as not executed'
  }
  if ($raw -match 'source-secret|drill-secret') {
    throw 'Recovery drill report leaked database credentials'
  }

  $rejected = $false
  try {
    & $script `
      -CommitSha ('a' * 40) `
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

  $missingShaRejected = $false
  try {
    & $script `
      -SourceDatabaseUrl 'postgresql://source:secret@localhost:5432/source_db' `
      -DrillDatabaseUrl 'postgresql://drill:secret@localhost:5432/drill_db' `
      -PrivateObjectRoot $objects `
      -WorkingDirectory (Join-Path $temp 'missing-sha') `
      -PlanOnly
  } catch {
    $missingShaRejected = $_.Exception.Message -match 'CommitSha'
  }
  if (-not $missingShaRejected) { throw 'Recovery drill accepted missing commit SHA' }

  Write-Host 'Recovery drill script tests passed.' -ForegroundColor Green
} finally {
  if (Test-Path -LiteralPath $temp) {
    Remove-Item -LiteralPath $temp -Recurse -Force
  }
}
