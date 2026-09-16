$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$clientRoot = Join-Path $projectRoot 'apps\client'

$adbCommand = Get-Command adb.exe -ErrorAction SilentlyContinue
if (-not $adbCommand) {
  throw 'ADB was not found on PATH. Install Android platform-tools and add them to PATH.'
}

$deviceLine = @( & $adbCommand.Source devices | Select-String '\sdevice\s' | Select-Object -First 1 )
if ($deviceLine.Count -eq 0) {
  throw 'No Android device is connected. Unlock the device and accept USB debugging first.'
}
$device = ($deviceLine[0].ToString() -split '\s+')[0]
if ([string]::IsNullOrWhiteSpace($device)) {
  throw 'ADB returned an invalid device identifier.'
}

Write-Host "Using Android device: $device"
& $adbCommand.Source -s $device reverse tcp:3100 tcp:3100 | Out-Host
if ($LASTEXITCODE -ne 0) {
  throw "Unable to create ADB reverse mapping for $device (exit code $LASTEXITCODE)."
}

Push-Location $clientRoot
try {
  flutter build apk --debug `
    --dart-define=API_BASE_URL=http://127.0.0.1:3100 `
    --dart-define=ALLOW_INSECURE_API=true
  $apk = Join-Path $clientRoot 'build\app\outputs\flutter-apk\app-debug.apk'
  if (-not (Test-Path -LiteralPath $apk)) {
    throw "Flutter build completed without producing the expected APK: $apk"
  }
  & $adbCommand.Source -s $device install -r $apk | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "APK installation failed for $device (exit code $LASTEXITCODE)."
  }
  & $adbCommand.Source -s $device shell am force-stop com.indiatrading.india_trading_app
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to stop the existing app on $device (exit code $LASTEXITCODE)."
  }
  & $adbCommand.Source -s $device shell monkey -p com.indiatrading.india_trading_app 1 | Out-Host
  if ($LASTEXITCODE -ne 0) {
    throw "Unable to launch the app on $device (exit code $LASTEXITCODE)."
  }
  Write-Host "Android E2E app started. API reverse mapping: tcp:3100 -> tcp:3100"
} finally {
  Pop-Location
}
