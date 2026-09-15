param(
  [Parameter(Mandatory = $true)]
  [string]$OutputPath,
  [string]$DatabaseUrl = $env:DATABASE_URL
)

$ErrorActionPreference = "Stop"

if (-not $DatabaseUrl) {
  throw "缺少 DATABASE_URL。请传入 -DatabaseUrl 或设置环境变量。"
}

$pgDump = Get-Command pg_dump -ErrorAction SilentlyContinue
if (-not $pgDump) {
  throw "未找到 pg_dump，请先安装 PostgreSQL 客户端工具并加入 PATH。"
}

$resolved = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($OutputPath)
$parent = Split-Path -Parent $resolved
if ($parent -and -not (Test-Path -LiteralPath $parent)) {
  New-Item -ItemType Directory -Path $parent | Out-Null
}

& $pgDump.Source --dbname=$DatabaseUrl --format=custom --compress=9 --file=$resolved
if ($LASTEXITCODE -ne 0) {
  throw "pg_dump 失败，退出码 $LASTEXITCODE"
}

Write-Host "备份完成: $resolved"
