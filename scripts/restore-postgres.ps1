param([Parameter(Mandatory=$true)][string]$BackupFile, [switch]$ConfirmRestore)
$ErrorActionPreference = "Stop"
if (-not $ConfirmRestore) { throw "Restore overwrites database state. Re-run with -ConfirmRestore." }
$resolved = (Resolve-Path -LiteralPath $BackupFile).Path
if ([System.IO.Path]::GetExtension($resolved) -ne ".dump") { throw "Only validated .dump backups are accepted" }
$containerTarget = "/tmp/india-trading-restore.dump"
try {
  docker compose cp $resolved "postgres:$containerTarget"
  if ($LASTEXITCODE -ne 0) { throw "Could not copy backup into database container" }
  docker compose exec -T postgres pg_restore -U hnw_user --list $containerTarget | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Backup archive is unreadable" }
  docker compose exec -T postgres pg_restore -U hnw_user --dbname=hnw_trading --clean --if-exists --no-owner --exit-on-error $containerTarget
  if ($LASTEXITCODE -ne 0) { throw "Database restore failed" }
} finally {
  docker compose exec -T postgres rm -f $containerTarget | Out-Null
}
