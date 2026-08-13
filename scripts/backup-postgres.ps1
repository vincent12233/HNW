param([string]$OutputDirectory = ".\backups", [int]$RetentionDays = 14)
$ErrorActionPreference = "Stop"
$resolved = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $resolved | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$target = Join-Path $resolved "india-trading-$stamp.dump"
$containerTarget = "/tmp/india-trading-backup.dump"
try {
  docker compose exec -T postgres pg_dump -U hnw_user --format=custom --compress=9 --file=$containerTarget hnw_trading
  if ($LASTEXITCODE -ne 0) { throw "Database backup failed" }
  docker compose exec -T postgres pg_restore -U hnw_user --list $containerTarget | Out-Null
  if ($LASTEXITCODE -ne 0) { throw "Backup archive is unreadable" }
  docker compose cp "postgres:$containerTarget" $target
  if ($LASTEXITCODE -ne 0 -or (Get-Item -LiteralPath $target).Length -lt 100) { throw "Backup validation failed" }
} finally {
  docker compose exec -T postgres rm -f $containerTarget | Out-Null
}
if ($RetentionDays -gt 0) {
  Get-ChildItem -LiteralPath $resolved -Filter "india-trading-*.dump" -File |
    Where-Object LastWriteTime -lt (Get-Date).AddDays(-$RetentionDays) |
    Remove-Item -Force
}
Write-Output $target
