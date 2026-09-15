param(
  [Parameter(Mandatory = $true)]
  [string]$InputPath,
  [string]$DatabaseUrl = $env:DATABASE_URL
)

$ErrorActionPreference = "Stop"

if (-not $DatabaseUrl) {
  throw "缺少 DATABASE_URL。请传入 -DatabaseUrl 或设置环境变量。"
}

$resolved = Resolve-Path -LiteralPath $InputPath
$pgRestore = Get-Command pg_restore -ErrorAction SilentlyContinue
if (-not $pgRestore) {
  throw "未找到 pg_restore，请先安装 PostgreSQL 客户端工具并加入 PATH。"
}

& $pgRestore.Source --dbname=$DatabaseUrl --clean --if-exists --no-owner --exit-on-error $resolved.Path
if ($LASTEXITCODE -ne 0) {
  throw "pg_restore 失败，退出码 $LASTEXITCODE"
}

Write-Host "恢复完成: $($resolved.Path)"
