param(
  [ValidateSet('api', 'client', 'admin', 'manager', 'finance', 'business', 'support')]
  [string[]]$Services = @('api', 'client', 'admin', 'manager', 'finance', 'business', 'support'),
  [switch]$SkipBuild
)

$ErrorActionPreference = 'Stop'
$projectRoot = Split-Path -Parent $PSScriptRoot

function Resolve-DockerCli {
  $command = Get-Command docker -ErrorAction SilentlyContinue
  if ($command) { return $command.Source }

  $candidates = @(
    (Join-Path $env:ProgramFiles 'Docker\Docker\resources\bin\docker.exe'),
    (Join-Path $env:LOCALAPPDATA 'Programs\DockerDesktop\resources\bin\docker.exe'),
    (Join-Path $env:LOCALAPPDATA 'Docker\resources\bin\docker.exe')
  ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

  if ($candidates.Count -gt 0) { return $candidates[0] }
  throw 'Docker CLI was not found. Open a new PowerShell after Docker Desktop is running, then run this script again.'
}

$docker = Resolve-DockerCli
Push-Location $projectRoot
try {
  & $docker version --format '{{.Server.Version}}' | Out-Null
  if ($LASTEXITCODE -ne 0) { throw 'Docker Desktop is not ready.' }

  $upArgs = @('compose', 'up', '-d', '--force-recreate')
  if (-not $SkipBuild) { $upArgs += '--build' }
  $upArgs += $Services
  & $docker @upArgs
  if ($LASTEXITCODE -ne 0) { throw 'Docker Compose deployment failed.' }

  $checks = @{
    3000 = '/health/ready'
    3001 = '/'
    3002 = '/login'
    3004 = '/login'
    3005 = '/login'
    3006 = '/login'
    3007 = '/login'
  }
  foreach ($port in $checks.Keys | Sort-Object) {
    $uri = "http://localhost:$port$($checks[$port])"
    $response = Invoke-WebRequest -UseBasicParsing -Uri $uri -TimeoutSec 15
    if ($response.StatusCode -lt 200 -or $response.StatusCode -ge 400) {
      throw "Health check failed for ${uri}: $($response.StatusCode)"
    }
    Write-Host "Ready: $uri"
  }

  & $docker compose ps
} finally {
  Pop-Location
}
