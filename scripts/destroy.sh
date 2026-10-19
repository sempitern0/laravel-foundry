#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
printf 'This permanently deletes local database and service volumes. Type DELETE to continue: '
IFS= read -r confirmation
[ "$confirmation" = DELETE ] || { echo "Cancelled."; exit 1; }
docker compose --profile dev --profile workers --profile redis down --volumes --remove-orphans
