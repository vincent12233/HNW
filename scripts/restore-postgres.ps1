param([Parameter(Mandatory=$true)][string]$BackupFile, [switch]$ConfirmRestore)
$ErrorActionPreference = "Stop"
if (-not $ConfirmRestore) { throw "Restore overwrites database state. Re-run with -ConfirmRestore." }
$resolved = (Resolve-Path -LiteralPath $BackupFile).Path
if ([System.IO.Path]::GetExtension($resolved) -ne ".sql") { throw "Only .sql backups are accepted" }
Get-Content -Raw -LiteralPath $resolved | docker compose exec -T postgres psql -v ON_ERROR_STOP=1 -U postgres postgres
