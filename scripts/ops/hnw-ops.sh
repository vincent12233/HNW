#!/usr/bin/env bash
set -euo pipefail
command_name="${1:?command required}"; shift
environment=''; sha=''; image_digest=''
while (($#)); do
  case "$1" in
    --environment) environment="$2"; shift 2 ;;
    --sha) sha="$2"; shift 2 ;;
    --image-digest) image_digest="$2"; shift 2 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done
root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
env_file="$($root/scripts/ops/lib/preflight.sh "$environment")"
compose=(docker compose --env-file "$env_file" -f "$root/compose.production.yaml")
case "$command_name" in
  preflight) printf '{"environment":"%s","status":"ready"}\n' "$environment" ;;
  status) "${compose[@]}" ps ;;
  logs) "${compose[@]}" logs --since 30m --tail 500 --no-color ;;
  backup-check)
    marker="$root/backups/$environment/latest.json"; [[ -f "$marker" ]] || { echo 'backup evidence missing' >&2; exit 2; }
    node -e "const e=require(process.argv[1]);if(Date.now()-Date.parse(e.completedAt)>86400000)process.exit(2);console.log(JSON.stringify(e))" "$marker" ;;
  deploy)
    [[ "$environment" != production ]] || { echo 'production deployment is CI-only' >&2; exit 2; }
    [[ -n "$sha" && -n "$image_digest" ]] || { echo 'exact sha and image digest required' >&2; exit 2; }
    "${compose[@]}" pull; "${compose[@]}" up -d --wait ;;
  rollback)
    [[ "$environment" != production ]] || { echo 'production rollback is CI-only' >&2; exit 2; }
    echo 'use an approved immutable image digest from environment inventory' >&2; exit 2 ;;
  *) echo 'unknown command' >&2; exit 2 ;;
esac
