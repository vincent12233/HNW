param([switch]$SkipBuild)

$projectRoot = Split-Path -Parent $PSScriptRoot
$adminRoot = Join-Path $projectRoot "apps\admin"
$ports = @(3002, 3004, 3005, 3006, 3007)
$env:NODE_ENV = "production"

if (-not $SkipBuild) {
  Push-Location $adminRoot
  try { npm.cmd run build } finally { Pop-Location }
}

foreach ($port in $ports) {
  $listener = Get-NetTCPConnection -LocalPort $port -State Listen -ErrorAction SilentlyContinue
  if ($listener) {
    Write-Host "后台入口已运行: http://localhost:$port/login"
    continue
  }
  $logPrefix = Join-Path $env:TEMP "india-admin-$port"
  $arguments = @("run", "start", "--", "-p", "$port", "-H", "0.0.0.0")
  Start-Process npm.cmd -WorkingDirectory $adminRoot -ArgumentList $arguments -RedirectStandardOutput "$logPrefix.out.log" -RedirectStandardError "$logPrefix.err.log" -WindowStyle Hidden | Out-Null
  Write-Host "后台入口已启动: http://localhost:$port/login"
}
