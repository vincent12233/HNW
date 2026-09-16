$ErrorActionPreference = 'Stop'

$projectRoot = Split-Path -Parent $PSScriptRoot
$clientRoot = Join-Path $projectRoot 'apps\client'
$device = (adb devices | Select-String '\sdevice\s' | Select-Object -First 1).ToString().Split("`t")[0]
if (!$device) {
  throw 'No Android device is connected. Unlock the device and accept USB debugging first.'
}

Write-Host "Using Android device: $device"
adb -s $device reverse tcp:3100 tcp:3100 | Out-Host

Push-Location $clientRoot
try {
  flutter build apk --debug `
    --dart-define=API_BASE_URL=http://127.0.0.1:3100 `
    --dart-define=ALLOW_INSECURE_API=true
  $apk = Join-Path $clientRoot 'build\app\outputs\flutter-apk\app-debug.apk'
  adb -s $device install -r $apk | Out-Host
  adb -s $device shell am force-stop com.indiatrading.india_trading_app
  adb -s $device shell monkey -p com.indiatrading.india_trading_app 1 | Out-Host
  Write-Host "Android E2E app started. API reverse mapping: tcp:3100 -> tcp:3100"
} finally {
  Pop-Location
}
