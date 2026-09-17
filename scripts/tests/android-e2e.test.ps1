# No device, SDK, network or third-party test runner is needed.
$ErrorActionPreference = 'Stop'
$scriptUnderTest = Join-Path $PSScriptRoot '..\build-android-e2e.ps1'
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("hnw-android-script-test-" + [Guid]::NewGuid().ToString('N'))
$testScripts = Join-Path $testRoot 'scripts'
$testClient = Join-Path $testRoot 'apps\client'
New-Item -ItemType Directory -Path $testScripts, $testClient -Force | Out-Null
Copy-Item -LiteralPath $scriptUnderTest -Destination (Join-Path $testScripts 'build-android-e2e.ps1')
$testScript = Join-Path $testScripts 'build-android-e2e.ps1'
$testApk = Join-Path $testClient 'build\app\outputs\flutter-apk\app-debug.apk'
New-Item -ItemType Directory -Path (Split-Path -Parent $testApk) -Force | Out-Null

function Get-Command {
  [CmdletBinding()]
  param([string]$Name)
  if ($Name -eq 'adb.exe') { return @{ Source = 'Invoke-TestAdb' } }
  if ($Name -eq 'flutter') { return @{ Source = 'Invoke-TestFlutter' } }
  throw "Unexpected command lookup: $Name"
}

function Invoke-TestAdb {
  $global:hnwAndroidTestCalls.Add("adb $($args -join ' ')")
  $global:LASTEXITCODE = 0
  if ($args[0] -eq 'devices') {
    $global:LASTEXITCODE = $global:hnwAndroidTestScenario.AdbExit
    return @('List of devices attached') + $global:hnwAndroidTestScenario.Devices
  }
  if ($args -contains 'reverse') { $global:LASTEXITCODE = $global:hnwAndroidTestScenario.ReverseExit }
  if ($args -contains 'install') { $global:LASTEXITCODE = $global:hnwAndroidTestScenario.InstallExit }
}

function Invoke-TestFlutter {
  $global:hnwAndroidTestCalls.Add("flutter $($args -join ' ')")
  $global:LASTEXITCODE = $global:hnwAndroidTestScenario.BuildExit
  if ($global:hnwAndroidTestScenario.BuildExit -eq 0 -and -not $global:hnwAndroidTestScenario.NoApk) {
    Set-Content -LiteralPath $testApk -Value 'new-apk'
  }
}

function Invoke-RestMethod {
  [CmdletBinding()]
  param([string]$Uri, [int]$TimeoutSec)
  $global:hnwAndroidTestCalls.Add("health $Uri")
  if ($global:hnwAndroidTestScenario.BadReady) { throw 'Database unavailable' }
  return @{ status = 'ready'; database = 'connected' }
}

function Assert-True($Condition, [string]$Message) {
  if (-not $Condition) { throw $Message }
}

$cases = @(
  @{ Name = 'Failed build never installs a stale APK'; BuildExit = 1; StaleApk = $true; Error = 'Flutter build failed'; Forbidden = 'adb .* (reverse|install) ' },
  @{ Name = 'Multiple devices require an explicit serial'; Devices = @("one`tdevice", "two`tdevice"); Error = 'Multiple Android devices'; Forbidden = 'flutter|health|adb .* install ' },
  @{ Name = 'Unauthorized device is rejected'; Devices = @("one`tunauthorized"); Error = 'No authorized Android device'; Forbidden = 'flutter|health' },
  @{ Name = 'An unavailable selected device is rejected'; Serial = 'missing'; Error = "device 'missing' is not ready"; Forbidden = 'flutter|health' },
  @{ Name = 'ADB listing failure stops setup'; AdbExit = 1; Error = 'ADB devices failed'; Forbidden = 'flutter|health' },
  @{ Name = 'Unavailable API stops before build and install'; BadReady = $true; Error = 'Local test API is not ready'; Forbidden = 'flutter|adb .* install ' },
  @{ Name = 'Missing build artifact stops installation'; NoApk = $true; Error = 'without producing the expected APK'; Forbidden = 'adb .* install ' },
  @{ Name = 'Failed port mapping prevents installation'; ReverseExit = 1; Error = 'reverse.*failed'; Forbidden = 'adb .* install ' },
  @{ Name = 'Failed installation prevents launch'; InstallExit = 1; Error = 'install.*failed'; Forbidden = 'force-stop|monkey' },
  @{ Name = 'Selected serial and custom port apply throughout'; Devices = @("one`tdevice", "two`tdevice"); Serial = 'two'; Port = 3200 }
)

$originalLocation = (Get-Location).Path
try {
  foreach ($case in $cases) {
    $global:hnwAndroidTestScenario = @{
      Devices = @("one`tdevice"); AdbExit = 0; BuildExit = 0
      ReverseExit = 0; InstallExit = 0; BadReady = $false; NoApk = $false
    }
    foreach ($key in $case.Keys) { $global:hnwAndroidTestScenario[$key] = $case[$key] }
    $global:hnwAndroidTestCalls = [Collections.Generic.List[string]]::new()
    if (Test-Path -LiteralPath $testApk) { Remove-Item -LiteralPath $testApk }
    if ($case.StaleApk) { Set-Content -LiteralPath $testApk -Value 'stale-apk' }
    $parameters = @{}
    if ($case.Serial) { $parameters.DeviceSerial = $case.Serial }
    if ($case.Port) { $parameters.ApiPort = $case.Port }
    $failure = $null
    try { & $testScript @parameters } catch { $failure = $_.Exception.Message }
    if ($case.Error) {
      Assert-True ($failure -match $case.Error) "$($case.Name): unexpected result '$failure'"
    } else {
      Assert-True (-not $failure) "$($case.Name): $failure"
      Assert-True ($global:hnwAndroidTestCalls -contains 'health http://127.0.0.1:3200/health/ready') 'Readiness used the wrong API port.'
      Assert-True ($global:hnwAndroidTestCalls -contains 'adb -s two reverse tcp:3200 tcp:3200') 'Mapping used the wrong serial or port.'
      Assert-True ([bool]($global:hnwAndroidTestCalls -match 'API_BASE_URL=http://127.0.0.1:3200')) 'Build used the wrong API URL.'
      Assert-True ([bool]($global:hnwAndroidTestCalls -match '^adb -s two install -r ')) 'Installation used the wrong serial.'
      Assert-True ($global:hnwAndroidTestCalls -contains 'adb -s two shell monkey -p com.indiatrading.india_trading_app 1') 'The selected app was not launched.'
    }
    if ($case.Forbidden) {
      Assert-True (-not ($global:hnwAndroidTestCalls -match $case.Forbidden)) "$($case.Name): a forbidden follow-up action ran."
    }
    Assert-True ((Get-Location).Path -eq $originalLocation) 'The script did not restore the working directory.'
    Write-Host "PASS: $($case.Name)"
  }
  Write-Host "$($cases.Count) Android setup regression checks passed."
} finally {
  # Only remove the unique temporary directory created by this test run.
  $resolvedRoot = [IO.Path]::GetFullPath($testRoot)
  $tempPrefix = [IO.Path]::GetFullPath([IO.Path]::GetTempPath()).TrimEnd('\', '/') + [IO.Path]::DirectorySeparatorChar
  if (-not $resolvedRoot.StartsWith($tempPrefix, [StringComparison]::OrdinalIgnoreCase) -or
      (Split-Path -Leaf $resolvedRoot) -notlike 'hnw-android-script-test-*') {
    throw "Refusing to remove unexpected test path: $resolvedRoot"
  }
  Remove-Item -LiteralPath $resolvedRoot -Recurse -Force
}

