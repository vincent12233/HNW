param(
  [string]$ApiBaseUrl = 'http://192.168.1.150:3000',
  [string]$DeviceId = ''
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$flutter = 'C:\src\flutter\bin\flutter.bat'
$adb = 'C:\Users\suyan\AppData\Local\Android\sdk\platform-tools\adb.exe'
$javaHome = 'C:\Program Files\Android\Android Studio\jbr'
$package = 'com.indiatrading.india_trading_app'

if (-not (Test-Path $flutter)) { throw "Flutter not found: $flutter" }
if (-not (Test-Path $adb)) { throw "ADB not found: $adb" }
if (-not (Test-Path $javaHome)) { throw "Android Studio JDK not found: $javaHome" }

$env:HOME = 'C:\Users\suyan'
$env:USERPROFILE = 'C:\Users\suyan'
$env:ANDROID_USER_HOME = 'C:\Users\suyan\.android'
$env:JAVA_HOME = $javaHome
$env:Path = "$javaHome\bin;$env:Path"
New-Item -ItemType Directory -Force -Path $env:ANDROID_USER_HOME | Out-Null

& $adb start-server | Out-Host
$devices = @(& $adb devices | Select-String "\t(device)$")
if ($devices.Count -eq 0) {
  throw 'No authorized Android device found. Connect the phone, enable USB debugging, unlock it, and accept the RSA prompt.'
}
if ([string]::IsNullOrWhiteSpace($DeviceId)) {
  $DeviceId = (($devices[0].ToString() -split "\s+")[0])
}

Push-Location (Join-Path $repo 'apps/client')
try {
  & $flutter pub get
  if ($LASTEXITCODE -ne 0) { throw 'flutter pub get failed.' }
  & $flutter build apk --debug --dart-define=API_BASE_URL=$ApiBaseUrl --dart-define=ALLOW_INSECURE_API=true
  if ($LASTEXITCODE -ne 0) { throw 'Android APK build failed.' }
  $apk = Join-Path (Get-Location) 'build\app\outputs\flutter-apk\app-debug.apk'
  & $adb -s $DeviceId install -r $apk
  if ($LASTEXITCODE -ne 0) { throw 'APK installation failed.' }
  & $adb -s $DeviceId shell monkey -p $package 1 | Out-Host
  Write-Host "Installed $apk on $DeviceId (API: $ApiBaseUrl)"
} finally {
  Pop-Location
}
