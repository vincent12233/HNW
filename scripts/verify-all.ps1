param(
  [string]$BaseUrl = "http://localhost:3000",
  [switch]$SkipVerification
)

$ErrorActionPreference = "Stop"

$root = Resolve-Path (Join-Path $PSScriptRoot "..")

function Invoke-Step($Name, $ScriptBlock) {
  Write-Host ""
  Write-Host "== $Name ==" -ForegroundColor Cyan
  & $ScriptBlock
}

function Invoke-Native($Command, $Arguments) {
  & $Command @Arguments
  if ($LASTEXITCODE -ne 0) {
    throw "$Command $($Arguments -join ' ') failed with exit code $LASTEXITCODE"
  }
}

function Set-FlutterGitSafeDirectory {
  $flutterCommand = Get-Command "flutter" -ErrorAction SilentlyContinue
  if (-not $flutterCommand) {
    return
  }

  $flutterBin = Split-Path -Parent $flutterCommand.Source
  $flutterRoot = Split-Path -Parent $flutterBin
  if (-not (Test-Path -LiteralPath (Join-Path $flutterRoot ".git"))) {
    return
  }

  $existingCount = 0
  if ($env:GIT_CONFIG_COUNT) {
    $existingCount = [int]$env:GIT_CONFIG_COUNT
  }

  $env:GIT_CONFIG_COUNT = [string]($existingCount + 1)
  Set-Item -Path "env:GIT_CONFIG_KEY_$existingCount" -Value "safe.directory"
  Set-Item -Path "env:GIT_CONFIG_VALUE_$existingCount" -Value $flutterRoot
}

function Set-FlutterWritableDirectories {
  $appData = Join-Path $root ".flutter-appdata"
  $localAppData = Join-Path $root ".flutter-localappdata"
  $pubCache = Join-Path $root ".pub-cache"

  New-Item -ItemType Directory -Force -Path $appData, $localAppData, $pubCache | Out-Null

  $env:APPDATA = $appData
  $env:LOCALAPPDATA = $localAppData
  $env:PUB_CACHE = $pubCache
}

Invoke-Step "API build" {
  Push-Location (Join-Path $root "apps/api")
  try {
    Invoke-Native "npm.cmd" @("run", "build")
  } finally {
    Pop-Location
  }
}

Invoke-Step "Admin build" {
  Push-Location (Join-Path $root "apps/admin")
  try {
    Invoke-Native "npm.cmd" @("run", "build")
  } finally {
    Pop-Location
  }
}

Invoke-Step "Support build" {
  Push-Location (Join-Path $root "apps/support")
  try {
    Invoke-Native "npm.cmd" @("run", "build")
  } finally {
    Pop-Location
  }
}

Invoke-Step "Client analyze" {
  Push-Location (Join-Path $root "apps/client")
  try {
    Set-FlutterGitSafeDirectory
    Set-FlutterWritableDirectories
    Invoke-Native "flutter" @("pub", "get")
    Invoke-Native "flutter" @("analyze")
  } finally {
    Pop-Location
  }
}

if (-not $SkipVerification) {
  Invoke-Step "Business verification test" {
    & (Join-Path $root "scripts/verification-test.ps1") -BaseUrl $BaseUrl
  }
}

Write-Host ""
Write-Host "All selected checks passed." -ForegroundColor Green
