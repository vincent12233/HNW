#!/usr/bin/env bash
set -euo pipefail
environment="${1:?environment required}"
[[ "$environment" =~ ^[a-z0-9][a-z0-9-]{1,31}$ ]] || { echo 'invalid environment' >&2; exit 2; }
command -v docker >/dev/null
docker info >/dev/null
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
env_file="$root/.env.$environment"
[[ -f "$env_file" ]] || { echo "missing .env.$environment" >&2; exit 2; }
free_kb="$(df -Pk "$root" | awk 'NR==2 {print $4}')"
(( free_kb >= 10485760 )) || { echo 'at least 10 GB free disk is required' >&2; exit 2; }
printf '%s\n' "$env_file"
