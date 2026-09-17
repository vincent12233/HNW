# Exercise the verification entrypoint without starting services or real builds.
$ErrorActionPreference = 'Stop'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("hnw-verify-script-test-" + [Guid]::NewGuid().ToString('N'))
$testScripts = Join-Path $testRoot 'scripts'
$global:hnwVerifyTestSdk = Join-Path $testRoot 'sdk'
$directories = @(
  $testScripts, (Join-Path $testRoot 'apps\api\node_modules'),
  (Join-Path $testRoot 'apps\admin\node_modules'), (Join-Path $testRoot 'apps\client'),
  (Join-Path $global:hnwVerifyTestSdk 'bin'), (Join-Path $global:hnwVerifyTestSdk '.git')
)
New-Item -ItemType Directory -Path $directories -Force | Out-Null
$testScript = Join-Path $testScripts 'verify-all.ps1'
Copy-Item -LiteralPath (Join-Path $PSScriptRoot '..\verify-all.ps1') -Destination $testScript

function Get-Command {
  [CmdletBinding()]
  param([string]$Name)
  if ($Name -eq 'flutter') {
    return @{ Source = (Join-Path $global:hnwVerifyTestSdk 'bin\flutter.bat') }
  }
  throw "Unexpected command lookup: $Name"
}
function npm.cmd { $global:LASTEXITCODE = 0 }
function npx.cmd { $global:LASTEXITCODE = 0 }
function flutter {
  if (-not $env:APPDATA.EndsWith('.flutter-appdata') -or
      -not $env:LOCALAPPDATA.EndsWith('.flutter-localappdata')) {
    throw 'Temporary Flutter directories were not active during the command.'
  }
  $global:LASTEXITCODE = if ($global:hnwVerifyTestFailure) { 1 } else { 0 }
}

$environmentNames = @(
  'APPDATA', 'LOCALAPPDATA', 'PUB_CACHE', 'GIT_CONFIG_COUNT',
  'GIT_CONFIG_KEY_0', 'GIT_CONFIG_VALUE_0', 'GIT_CONFIG_KEY_2', 'GIT_CONFIG_VALUE_2'
)
$originalEnvironment = @{}
foreach ($name in $environmentNames) {
  $originalEnvironment[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
}
$originalLocation = (Get-Location).Path
$count = 0
try {
  foreach ($existingCount in @($null, '2')) {
    foreach ($failBuild in @($false, $true)) {
      $env:APPDATA = 'original-appdata'
      $env:LOCALAPPDATA = 'original-localappdata'
      [Environment]::SetEnvironmentVariable('PUB_CACHE', $null, 'Process')
      [Environment]::SetEnvironmentVariable('GIT_CONFIG_COUNT', $existingCount, 'Process')
      # Even a pre-existing unused slot must be restored, not just deleted.
      $env:GIT_CONFIG_KEY_0 = 'original-key-0'
      $env:GIT_CONFIG_VALUE_0 = 'original-value-0'
      $env:GIT_CONFIG_KEY_2 = 'original-key-2'
      $env:GIT_CONFIG_VALUE_2 = 'original-value-2'
      $expected = @{}
      foreach ($name in $environmentNames) {
        $expected[$name] = [Environment]::GetEnvironmentVariable($name, 'Process')
      }
      $global:hnwVerifyTestFailure = $failBuild
      $failure = $null
      try { & $testScript -SkipVerification } catch { $failure = $_.Exception.Message }
      if ($failBuild -and $failure -notlike '*flutter*failed with exit code 1*') {
        throw "Expected Flutter failure, received: $failure"
      }
      if (-not $failBuild -and $failure) { throw $failure }
      foreach ($name in $environmentNames) {
        $actual = [Environment]::GetEnvironmentVariable($name, 'Process')
        if ($actual -cne $expected[$name]) {
          throw "Environment variable $name was not restored."
        }
      }
      if ((Get-Location).Path -ne $originalLocation) {
        throw 'Working directory was not restored.'
      }
      $count++
      Write-Host "PASS: environment restored (existing Git count '$existingCount', failure $failBuild)"
    }
  }
  Write-Host "$count verification environment regression checks passed."
  # GitHub's PowerShell runner propagates LASTEXITCODE after the script.
  # The final scenario intentionally simulated a failing native command.
  $global:LASTEXITCODE = 0
} finally {
  foreach ($name in $environmentNames) {
    [Environment]::SetEnvironmentVariable($name, $originalEnvironment[$name], 'Process')
  }
  $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
  $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $resolvedRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or
      (Split-Path -Leaf $resolvedRoot) -notlike 'hnw-verify-script-test-*') {
    throw "Refusing to remove unexpected test path: $resolvedRoot"
  }
  Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
}
