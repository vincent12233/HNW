#!/usr/bin/env bash
# Build five admin role bundles into separate Next.js dist directories.
# Usage (from repo root):
#   NEXT_PUBLIC_API_URL=https://api.example.com ./scripts/build-admin-roles.sh
set -euo pipefail

API_URL="${NEXT_PUBLIC_API_URL:?Set NEXT_PUBLIC_API_URL to the production API origin}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ADMIN_DIR="$ROOT/apps/admin"

cd "$ADMIN_DIR"
npm ci

roles=(ADMIN MANAGER FINANCE BUSINESS SUPPORT)
for role in "${roles[@]}"; do
  dist=".next-${role}"
  echo "==> Building $role into $dist"
  NEXT_PUBLIC_API_URL="$API_URL" \
    NEXT_PUBLIC_BACKEND_ROLE="$role" \
    NEXT_DIST_DIR="$dist" \
    npm run build
done

cat <<'EOF'
Build complete. Start each role with a matching NEXT_DIST_DIR, for example:

  cd apps/admin
  NEXT_DIST_DIR=.next-ADMIN    npm run start:admin
  NEXT_DIST_DIR=.next-MANAGER  npm run start:manager
  NEXT_DIST_DIR=.next-FINANCE  npm run start:finance
  NEXT_DIST_DIR=.next-BUSINESS npm run start:business
  NEXT_DIST_DIR=.next-SUPPORT  npm run start:support

Do not share one .next directory across five processes — NEXT_PUBLIC_* is baked at build time.
EOF
