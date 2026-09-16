$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $projectRoot 'compose.local-test.yaml'

$docker = Get-Command docker.exe -ErrorAction SilentlyContinue
if (!$docker) {
  $candidates = @(
    'C:\Program Files\Docker\Docker\resources\bin\docker.exe',
    (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'),
    (Join-Path $env:LOCALAPPDATA 'Docker\resources\bin\docker.exe')
  )
  $dockerPath = $candidates | Where-Object { Test-Path -LiteralPath $_ } | Select-Object -First 1
  if (!$dockerPath) { throw 'Docker CLI was not found. Start Docker Desktop first.' }
} else {
  $dockerPath = $docker.Source
}

if (!$env:HNW_E2E_DB_PASSWORD) {
  $env:HNW_E2E_DB_PASSWORD = 'HnwE2E_Local_2026_Strong!'
}

$logPath = Join-Path $projectRoot 'docker-compose-startup.log'
$previousPreference = $ErrorActionPreference
$ErrorActionPreference = 'Continue'
try {
  & $dockerPath compose --progress plain -f $composeFile up -d --build 2>&1 |
    Tee-Object -FilePath $logPath
  $composeExitCode = $LASTEXITCODE
} finally {
  $ErrorActionPreference = $previousPreference
}
if ($composeExitCode -ne 0) {
  throw "Docker Compose startup failed. Full log: $logPath"
}

& $dockerPath compose -f $composeFile ps
Write-Host 'API http://localhost:3100 | Admin 3002 | Manager 3004 | Finance 3005 | Business 3006 | Support 3007'
