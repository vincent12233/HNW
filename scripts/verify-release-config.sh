#!/usr/bin/env bash
set -euo pipefail
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
grep -q 'android:allowBackup="false"' "$root/apps/client/android/app/src/main/AndroidManifest.xml"
grep -q 'android:usesCleartextTraffic="false"' "$root/apps/client/android/app/src/main/AndroidManifest.xml"
grep -Eq '^version: [0-9]+\.[0-9]+\.[0-9]+\+[0-9]+' "$root/apps/client/pubspec.yaml"
for key in DATABASE_URL RATE_LIMIT_REDIS_URL JWT_SECRET TWO_FACTOR_ENCRYPTION_KEY OBJECT_SIGNING_SECRET TRUST_PROXY_HOPS; do
  grep -Fq '${'"$key"':?' "$root/compose.production.yaml" || { echo "missing required $key" >&2; exit 1; }
done
grep -q 'no-new-privileges:true' "$root/compose.production.yaml"
echo 'Release configuration checks passed.'
