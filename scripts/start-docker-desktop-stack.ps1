[CmdletBinding()]
param(
  [int]$WaitTimeoutSeconds = 600,
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$root = Split-Path -Parent $PSScriptRoot
$composeFile = Join-Path $root 'compose.local-test.yaml'

$docker = Get-Command docker -ErrorAction SilentlyContinue
if (-not $docker) {
  $perUserDocker = Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'
  if (Test-Path -LiteralPath $perUserDocker) {
    $dockerExe = $perUserDocker
  } else {
    throw 'Docker CLI was not found. Install and start Docker Desktop, then open a new terminal.'
  }
} else {
  $dockerExe = $docker.Source
}

& $dockerExe info *> $null
if ($LASTEXITCODE -ne 0) {
  & $dockerExe desktop start
  $deadline = (Get-Date).AddSeconds(120)
  do {
    Start-Sleep -Seconds 5
    & $dockerExe info *> $null
    if ($LASTEXITCODE -eq 0) { break }
  } while ((Get-Date) -lt $deadline)
  if ($LASTEXITCODE -ne 0) {
    throw 'Docker Desktop did not become ready within 120 seconds.'
  }
}

if (-not $env:HNW_E2E_DB_PASSWORD) {
  $env:HNW_E2E_DB_PASSWORD = 'HnwE2E_Local_2026_Strong!'
}

& $dockerExe compose -f $composeFile config --quiet
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose configuration validation failed.' }

$pullSucceeded = $false
for ($attempt = 1; $attempt -le 3; $attempt++) {
  Write-Host "Pulling service images (attempt $attempt/3)..."
  & $dockerExe compose -f $composeFile pull --ignore-buildable
  if ($LASTEXITCODE -eq 0) {
    $pullSucceeded = $true
    break
  }
  if ($attempt -lt 3) { Start-Sleep -Seconds (10 * $attempt) }
}
if (-not $pullSucceeded) {
  throw 'Docker Compose image pull failed after three attempts.'
}
$arguments = @('compose', '-f', $composeFile, 'up', '-d')
if (-not $SkipBuild) { $arguments += '--build' }
$arguments += @('--wait', '--wait-timeout', $WaitTimeoutSeconds)
& $dockerExe @arguments
if ($LASTEXITCODE -ne 0) { throw 'Docker Compose services failed to become healthy.' }

& $dockerExe compose -f $composeFile ps

if ($env:HNW_SMOKE_ADMIN_PASSWORD) {
  $env:HNW_SMOKE_API_URL = if ($env:HNW_SMOKE_API_URL) { $env:HNW_SMOKE_API_URL } else { 'http://127.0.0.1:3100' }
  node (Join-Path $root 'scripts\smoke-auth-content.mjs')
  if ($LASTEXITCODE -ne 0) { throw 'Staff auth/content smoke test failed.' }
} else {
  Write-Host 'Set HNW_SMOKE_ADMIN_PASSWORD to run the staff auth/content smoke test.'
}

Write-Host 'Docker Desktop test services are ready. API :3100 | Admin :3002 | Manager :3004 | Finance :3005 | Business :3006 | Support :3007'
