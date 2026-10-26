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
foreach ($privacyKey in @('NSFaceIDUsageDescription', 'NSCameraUsageDescription', 'NSPhotoLibraryUsageDescription')) {
  if ($plist -notmatch "<key>$privacyKey</key>\s*<string>[^<]*\S[^<]*</string>") {
    throw "iOS privacy usage description is missing or empty: $privacyKey"
  }
}
if ($pubspec -notmatch '(?m)^version:\s*[0-9]+\.[0-9]+\.[0-9]+\+[0-9]+') { throw 'Flutter release version must be semantic plus build number' }

$compose = Get-Content (Join-Path $PSScriptRoot '../compose.production.yaml') -Raw
foreach ($required in @('DATABASE_URL','RATE_LIMIT_REDIS_URL','JWT_SECRET','TWO_FACTOR_ENCRYPTION_KEY','OBJECT_SIGNING_SECRET','TRUST_PROXY_HOPS')) {
  if ($compose -notmatch [regex]::Escape("`${$required:?")) { throw "Production Compose must require $required" }
}
if ($compose -notmatch 'read_only:\s*true' -or $compose -notmatch 'no-new-privileges:true') { throw 'Production containers require read-only/no-new-privileges controls' }

Write-Host 'Release configuration checks passed.'
