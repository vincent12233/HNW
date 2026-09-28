param(
  [string]$ClientRoot = (Join-Path $PSScriptRoot '../apps/client')
)
$ErrorActionPreference = 'Stop'
$root = (Resolve-Path $ClientRoot).Path
$manifest = Get-Content (Join-Path $root 'android/app/src/main/AndroidManifest.xml') -Raw
$gradle = Get-Content (Join-Path $root 'android/app/build.gradle.kts') -Raw
$plist = Get-Content (Join-Path $root 'ios/Runner/Info.plist') -Raw
$pubspec = Get-Content (Join-Path $root 'pubspec.yaml') -Raw

if ($manifest -notmatch 'android:allowBackup="false"') { throw 'Android release manifest must disable backups' }
if ($manifest -notmatch 'android:usesCleartextTraffic="false"') { throw 'Android release manifest must disable cleartext traffic' }
if ($gradle -notmatch 'signingConfigs\.getByName\("release"\)') { throw 'Android release must select the release signing config' }
if ($gradle -notmatch 'Release signing requires android/key\.properties') { throw 'Android release signing guard is missing' }
if ($plist -notmatch 'NSFaceIDUsageDescription|NSCameraUsageDescription|NSPhotoLibraryUsageDescription') { throw 'iOS privacy usage descriptions are incomplete' }
if ($pubspec -notmatch '(?m)^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+') { throw 'Flutter release version must be semantic plus build number' }

Write-Host 'Release configuration checks passed.'