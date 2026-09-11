param(
  [switch]$SkipBuild,
  [switch]$SkipSeed
)

$ErrorActionPreference = "Stop"
$projectRoot = Split-Path -Parent $PSScriptRoot
$apiRoot = Join-Path $projectRoot "apps\api"
$envFile = Join-Path $projectRoot ".env.docker"
$pgBin = "C:\Program Files\PostgreSQL\17\bin"
$pgCtl = Join-Path $pgBin "pg_ctl.exe"
$pgData = Join-Path $projectRoot ".local\postgres-data"
$pgLog = Join-Path $projectRoot ".local\postgres.log"

if (-not (Test-Path $envFile)) {
  throw "缺少 $envFile。请先复制 .env.docker.example 为 .env.docker 并填写本地密钥。"
}

# Load only simple KEY=value entries from the local, ignored environment file.
Get-Content $envFile | ForEach-Object {
  if ($_ -match '^\s*([A-Za-z_][A-Za-z0-9_]*)=(.*)\s*$') {
    [Environment]::SetEnvironmentVariable($matches[1], $matches[2])
  }
}
$env:DATABASE_URL = "postgresql://hnw_user:hnw_dev_password@127.0.0.1:5433/hnw_trading"
$env:SHADOW_DATABASE_URL = "postgresql://hnw_user:hnw_dev_password@127.0.0.1:5433/hnw_trading_shadow"
$env:HOST = "0.0.0.0"

if (-not (Test-Path $pgCtl)) {
  throw "未找到 PostgreSQL 17: $pgCtl"
}

New-Item -ItemType Directory -Force (Split-Path $pgData), (Split-Path $pgLog) | Out-Null
$pgReady = & (Join-Path $pgBin "pg_isready.exe") -h 127.0.0.1 -p 5433 2>$null
if ($LASTEXITCODE -ne 0) {
  & $pgCtl start -D $pgData -o "-p 5433" -l $pgLog | Out-Null
  Start-Sleep -Seconds 3
}

Push-Location $apiRoot
try {
  npm.cmd run db:migrate
  if (-not $SkipSeed) { npm.cmd run seed }
  if (-not $SkipBuild) { npm.cmd run build }
} finally { Pop-Location }

$apiListener = Get-NetTCPConnection -LocalPort 3000 -State Listen -ErrorAction SilentlyContinue
if (-not $apiListener) {
  $apiOut = Join-Path $env:TEMP "india-api.out.log"
  $apiErr = Join-Path $env:TEMP "india-api.err.log"
  Start-Process node -WorkingDirectory $apiRoot -ArgumentList "dist/src/main.js" -RedirectStandardOutput $apiOut -RedirectStandardError $apiErr -WindowStyle Hidden | Out-Null
  Write-Host "API 已启动: http://localhost:3000/health"
}

& (Join-Path $PSScriptRoot "start-backends.ps1") -SkipBuild
Write-Host "本地交易平台已启动，API 与五个后台均已准备。"
