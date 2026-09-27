param(
  [Parameter(Mandatory = $true)]
  [string]$SourceDatabaseUrl,
  [Parameter(Mandatory = $true)]
  [string]$DrillDatabaseUrl,
  [Parameter(Mandatory = $true)]
  [string]$PrivateObjectRoot,
  [string]$WorkingDirectory = (Join-Path $PSScriptRoot "../recovery-drill"),
  [string]$ReportPath,
  [switch]$PlanOnly
)

$ErrorActionPreference = "Stop"
$startedAt = Get-Date
$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Assert-PostgresUrl([string]$Value, [string]$Name) {
  if ($Value -notmatch '^postgres(?:ql)?://') {
    throw "$Name must be a PostgreSQL URL"
  }
}

function Get-DatabaseName([string]$Value) {
  $uri = [Uri]$Value
  return $uri.AbsolutePath.Trim('/')
}

function Invoke-Native([string]$Command, [string[]]$Arguments) {
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Command failed with exit code $LASTEXITCODE"
  }
}

function Get-TableCounts([string]$DatabaseUrl) {
  $tables = @(
    'users', 'accounts', 'orders', 'kyc_submissions',
    'withdrawal_requests', 'deposit_requests', 'audit_logs'
  )
  $counts = [ordered]@{}
  foreach ($table in $tables) {
    $exists = (& psql $DatabaseUrl -At -v ON_ERROR_STOP=1 -c "SELECT to_regclass('public.$table') IS NOT NULL").Trim()
    if ($LASTEXITCODE -ne 0) { throw "Could not inspect table $table" }
    if ($exists -eq 't') {
      $value = (& psql $DatabaseUrl -At -v ON_ERROR_STOP=1 -c "SELECT COUNT(*) FROM public.""$table""").Trim()
      if ($LASTEXITCODE -ne 0) { throw "Could not count table $table" }
      $counts[$table] = [long]$value
    }
  }
  return $counts
}

function Get-ObjectManifest([string]$Directory) {
  $base = (Resolve-Path -LiteralPath $Directory).Path
  $manifest = foreach ($file in Get-ChildItem -LiteralPath $base -File -Recurse | Sort-Object FullName) {
    [ordered]@{
      path = [IO.Path]::GetRelativePath($base, $file.FullName).Replace('\\', '/')
      bytes = $file.Length
      sha256 = (Get-FileHash -LiteralPath $file.FullName -Algorithm SHA256).Hash.ToLowerInvariant()
    }
  }
  return @($manifest)
}

Assert-PostgresUrl $SourceDatabaseUrl 'SourceDatabaseUrl'
Assert-PostgresUrl $DrillDatabaseUrl 'DrillDatabaseUrl'
if ($SourceDatabaseUrl.TrimEnd('/') -eq $DrillDatabaseUrl.TrimEnd('/')) {
  throw 'DrillDatabaseUrl must not equal SourceDatabaseUrl'
}
if ((Get-DatabaseName $SourceDatabaseUrl) -eq (Get-DatabaseName $DrillDatabaseUrl)) {
  throw 'The source and drill database names must be different'
}
if (-not [IO.Path]::IsPathRooted($PrivateObjectRoot)) {
  throw 'PrivateObjectRoot must be an absolute path'
}

$work = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($WorkingDirectory)
if (-not $ReportPath) { $ReportPath = Join-Path $work 'recovery-report.json' }
$reportFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ReportPath)
$databaseBackup = Join-Path $work 'postgres.dump'
$objectsBackup = Join-Path $work 'private-objects.tar.gz'
$objectsRestore = Join-Path $work 'objects-restored'
$workFull = [IO.Path]::GetFullPath($work).TrimEnd('\', '/')
$workRoot = [IO.Path]::GetPathRoot($workFull).TrimEnd('\', '/')
if ($workFull -eq $workRoot) {
  throw 'WorkingDirectory must not be a filesystem root'
}
$objectsRestoreFull = [IO.Path]::GetFullPath($objectsRestore)
if (-not $objectsRestoreFull.StartsWith(
    $workFull + [IO.Path]::DirectorySeparatorChar,
    [StringComparison]::OrdinalIgnoreCase
  )) {
  throw 'Object restore directory must stay inside WorkingDirectory'
}

$report = [ordered]@{
  schemaVersion = 1
  startedAt = $startedAt.ToUniversalTime().ToString('o')
  completedAt = $null
  durationSeconds = $null
  sourceDatabase = Get-DatabaseName $SourceDatabaseUrl
  drillDatabase = Get-DatabaseName $DrillDatabaseUrl
  planOnly = [bool]$PlanOnly
  database = [ordered]@{ backup = $databaseBackup; countsMatch = $null; sourceCounts = $null; restoredCounts = $null }
  privateObjects = [ordered]@{ backup = $objectsBackup; filesMatch = $null; sourceFileCount = $null; restoredFileCount = $null }
  status = if ($PlanOnly) { 'PLANNED' } else { 'RUNNING' }
}

New-Item -ItemType Directory -Force -Path $work | Out-Null
if ($PlanOnly) {
  $report.completedAt = (Get-Date).ToUniversalTime().ToString('o')
  $report.durationSeconds = [math]::Round(((Get-Date) - $startedAt).TotalSeconds, 3)
  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportFile -Encoding utf8
  Write-Host "Recovery drill plan written: $reportFile"
  return
}

foreach ($command in 'pg_dump', 'pg_restore', 'psql', 'tar') {
  if (-not (Get-Command $command -ErrorAction SilentlyContinue)) {
    throw "$command is required for the recovery drill"
  }
}
if (-not (Test-Path -LiteralPath $PrivateObjectRoot -PathType Container)) {
  throw "PrivateObjectRoot not found: $PrivateObjectRoot"
}

try {
  & (Join-Path $root 'scripts/backup-postgres.ps1') -OutputPath $databaseBackup -DatabaseUrl $SourceDatabaseUrl
  $sourceCounts = Get-TableCounts $SourceDatabaseUrl
  & (Join-Path $root 'scripts/restore-postgres.ps1') -InputPath $databaseBackup -DatabaseUrl $DrillDatabaseUrl
  $restoredCounts = Get-TableCounts $DrillDatabaseUrl
  $report.database.sourceCounts = $sourceCounts
  $report.database.restoredCounts = $restoredCounts
  $report.database.countsMatch = (($sourceCounts | ConvertTo-Json -Compress) -eq ($restoredCounts | ConvertTo-Json -Compress))

  if (Test-Path -LiteralPath $objectsRestore) {
    Remove-Item -LiteralPath $objectsRestore -Recurse -Force
  }
  New-Item -ItemType Directory -Force -Path $objectsRestore | Out-Null
  Invoke-Native 'tar' @('-C', (Split-Path -Parent $PrivateObjectRoot), '-czf', $objectsBackup, (Split-Path -Leaf $PrivateObjectRoot))
  Invoke-Native 'tar' @('-C', $objectsRestore, '-xzf', $objectsBackup)
  $restoredObjectRoot = Join-Path $objectsRestore (Split-Path -Leaf $PrivateObjectRoot)
  $sourceManifest = Get-ObjectManifest $PrivateObjectRoot
  $restoredManifest = Get-ObjectManifest $restoredObjectRoot
  $report.privateObjects.sourceFileCount = $sourceManifest.Count
  $report.privateObjects.restoredFileCount = $restoredManifest.Count
  $report.privateObjects.filesMatch = (($sourceManifest | ConvertTo-Json -Compress) -eq ($restoredManifest | ConvertTo-Json -Compress))

  if (-not $report.database.countsMatch -or -not $report.privateObjects.filesMatch) {
    throw 'Recovery validation did not match the source snapshot'
  }
  $report.status = 'PASSED'
} catch {
  $report.status = 'FAILED'
  $report.error = $_.Exception.Message
  throw
} finally {
  $completedAt = Get-Date
  $report.completedAt = $completedAt.ToUniversalTime().ToString('o')
  $report.durationSeconds = [math]::Round(($completedAt - $startedAt).TotalSeconds, 3)
  $report | ConvertTo-Json -Depth 8 | Set-Content -LiteralPath $reportFile -Encoding utf8
  Write-Host "Recovery drill report written: $reportFile"
}
