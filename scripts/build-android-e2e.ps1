param(
  [string]$DeviceSerial,
  [ValidateRange(1024, 65535)]
  [int]$ApiPort = 3100
)

$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$clientRoot = Join-Path $projectRoot 'apps\client'

$adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue
if (-not $adbCommand) {
  throw 'ADB was not found on PATH. Install Android platform-tools and add them to PATH.'
}
$flutterCommand = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCommand) {
  throw 'Flutter was not found on PATH. Install the Flutter SDK and add its bin directory to PATH.'
}

function Invoke-AdbChecked {
  param([string[]]$AdbArguments)
  $output = & $adbCommand.Source @AdbArguments
  if ($LASTEXITCODE -ne 0) {
    throw "ADB $($AdbArguments -join ' ') failed (exit code $LASTEXITCODE)."
  }
  return $output
}

$deviceLines = @(Invoke-AdbChecked -AdbArguments @('devices'))
$devices = @($deviceLines | ForEach-Object {
  if ($_ -match '^(\S+)\s+device\s*$') { $Matches[1] }
})
if ($DeviceSerial) {
  if ($DeviceSerial -notin $devices) {
    throw "Android device '$DeviceSerial' is not ready. Unlock it and authorize USB debugging."
  }
  $device = $DeviceSerial
} else {
  if ($devices.Count -eq 0) {
    throw 'No authorized Android device is connected. Unlock the device and accept USB debugging first.'
  }
  if ($devices.Count -gt 1) {
    throw 'Multiple Android devices are connected. Run again with -DeviceSerial <serial> from adb devices.'
  }
  $device = $devices[0]
}

$apiUrl = "http://127.0.0.1:$ApiPort"
try {
  $health = Invoke-RestMethod -Uri "$apiUrl/health/ready" -TimeoutSec 10
  if ($health.status -ne 'ready' -or $health.database -ne 'connected') {
    throw 'The API did not report a ready database connection.'
  }
} catch {
  throw "Local test API is not ready at $apiUrl. Start the Docker stack and check its database. $($_.Exception.Message)"
}

Write-Host "Using Android device: $device | Local API: $apiUrl"
Push-Location $clientRoot
try {
  & $flutterCommand.Source build apk --debug `
    "--dart-define=API_BASE_URL=$apiUrl" `
    --dart-define=ALLOW_INSECURE_API=true
  if ($LASTEXITCODE -ne 0) {
    throw "Flutter build failed (exit code $LASTEXITCODE). No APK was installed."
  }
  $apk = Join-Path $clientRoot 'build\app\outputs\flutter-apk\app-debug.apk'
  if (-not (Test-Path -LiteralPath $apk)) {
    throw "Flutter build completed without producing the expected APK: $apk"
  }
  Invoke-AdbChecked -AdbArguments @('-s', $device, 'reverse', "tcp:$ApiPort", "tcp:$ApiPort") | Out-Host
  Invoke-AdbChecked -AdbArguments @('-s', $device, 'install', '-r', $apk) | Out-Host
  Invoke-AdbChecked -AdbArguments @('-s', $device, 'shell', 'am', 'force-stop', 'com.indiatrading.india_trading_app') | Out-Host
  Invoke-AdbChecked -AdbArguments @('-s', $device, 'shell', 'monkey', '-p', 'com.indiatrading.india_trading_app', '1') | Out-Host
  Write-Host "Android test app installed and launched. API reverse mapping: tcp:$ApiPort -> tcp:$ApiPort"
  Write-Host 'Setup complete. Registration, KYC, trading, deposit, withdrawal and risk disclosure still require end-to-end verification.'
} finally {
  Pop-Location
}
