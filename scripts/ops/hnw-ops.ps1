param(
  [Parameter(Position=0, Mandatory)][ValidateSet('preflight','status','logs','backup-check','deploy','rollback')][string]$Command,
  [Parameter(Mandatory)][string]$Environment,
  [string]$Sha,
  [string]$ImageDigest
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$check = & (Join-Path $PSScriptRoot 'lib/preflight.ps1') -Environment $Environment
if ($Command -eq 'preflight') { $check | ConvertTo-Json; exit 0 }
$compose = Join-Path $root 'compose.production.yaml'
$envFile = $check.envFile
switch ($Command) {
  'status' { docker compose --env-file $envFile -f $compose ps }
  'logs' { docker compose --env-file $envFile -f $compose logs --since 30m --tail 500 --no-color }
  'backup-check' {
    $marker = Join-Path $root "backups/$Environment/latest.json"
    if (-not (Test-Path -LiteralPath $marker)) { throw 'Backup evidence is missing' }
    $evidence = Get-Content -LiteralPath $marker -Raw | ConvertFrom-Json
    if ((Get-Date).ToUniversalTime() - [datetime]$evidence.completedAt -gt [timespan]::FromHours(24)) { throw 'Latest verified backup is older than 24 hours' }
    $evidence | ConvertTo-Json
  }
  'deploy' {
    if ($Environment -eq 'production') { throw 'Production deployment is CI-only and requires environment approval' }
    if (-not $Sha -or -not $ImageDigest) { throw 'deploy requires exact -Sha and -ImageDigest' }
    docker compose --env-file $envFile -f $compose pull
    docker compose --env-file $envFile -f $compose up -d --wait
  }
  'rollback' {
    if ($Environment -eq 'production') { throw 'Production rollback is CI-only and requires environment approval' }
    if (-not $ImageDigest) { throw 'rollback requires an immutable -ImageDigest' }
    throw 'Set the approved immutable image digest in the environment inventory before rollback'
  }
}
