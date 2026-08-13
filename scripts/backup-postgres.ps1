param([string]$OutputDirectory = ".\backups")
$ErrorActionPreference = "Stop"
$resolved = [System.IO.Path]::GetFullPath($OutputDirectory)
New-Item -ItemType Directory -Force -Path $resolved | Out-Null
$stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$target = Join-Path $resolved "india-trading-$stamp.sql"
docker compose exec -T postgres pg_dump -U postgres --format=plain --clean --if-exists postgres | Set-Content -Encoding utf8 $target
if ((Get-Item -LiteralPath $target).Length -lt 100) { throw "Backup validation failed" }
Write-Output $target
