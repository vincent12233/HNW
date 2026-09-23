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

Invoke-Step "API lint, tests and build" {
  Push-Location (Join-Path $root "apps/api")
  try {
    if (-not (Test-Path "node_modules")) { Invoke-Native "npm.cmd" @("ci") }
    Invoke-Native "npm.cmd" @("run", "db:generate")
    Invoke-Native "npm.cmd" @("run", "lint")
    Invoke-Native "npm.cmd" @("test", "--", "--runInBand")
    $previousApiUrl = $env:NEXT_PUBLIC_API_URL
    $env:NEXT_PUBLIC_API_URL = if ($env:HNW_BUILD_API_URL) { $env:HNW_BUILD_API_URL } else { "https://build.invalid" }
    try {
      Invoke-Native "npm.cmd" @("run", "build")
    } finally {
      $env:NEXT_PUBLIC_API_URL = $previousApiUrl
    }
  } finally {
    Pop-Location
  }
}

Invoke-Step "Admin lint, tests, typecheck and build" {
  Push-Location (Join-Path $root "apps/admin")
  try {
    if (-not (Test-Path "node_modules")) { Invoke-Native "npm.cmd" @("ci") }
    Invoke-Native "npm.cmd" @("run", "lint")
    Invoke-Native "npm.cmd" @("test")
    Invoke-Native "npx.cmd" @("--no-install", "tsc", "--noEmit")
    Invoke-Native "npm.cmd" @("run", "build")
  } finally {
    Pop-Location
  }
}

Invoke-Step "Client analyze" {
  $gitConfigIndex = if ($env:GIT_CONFIG_COUNT) { [int]$env:GIT_CONFIG_COUNT } else { 0 }
  $temporaryVariables = @(
    "APPDATA", "LOCALAPPDATA", "PUB_CACHE", "GIT_CONFIG_COUNT",
    "GIT_CONFIG_KEY_$gitConfigIndex", "GIT_CONFIG_VALUE_$gitConfigIndex"
  )
  $previousEnvironment = @{}
  foreach ($name in $temporaryVariables) {
    $previousEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, "Process")
  }
  Push-Location (Join-Path $root "apps/client")
  try {
    Set-FlutterGitSafeDirectory
    Set-FlutterWritableDirectories
    Invoke-Native "flutter" @("pub", "get", "--enforce-lockfile")
    Invoke-Native "flutter" @("analyze", "--no-fatal-infos")
    Invoke-Native "flutter" @("test")
  } finally {
    Pop-Location
    foreach ($name in $temporaryVariables) {
      [Environment]::SetEnvironmentVariable($name, $previousEnvironment[$name], "Process")
    }
  }
}

if (-not $SkipVerification) {
  Invoke-Step "Business verification test" {
    & (Join-Path $root "scripts/verification-test.ps1") -BaseUrl $BaseUrl
  }
}

Write-Host ""
Write-Host "All selected checks passed." -ForegroundColor Green
