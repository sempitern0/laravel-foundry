#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
[ -f .env ] || { echo "Missing root .env" >&2; exit 1; }

getval() { sed -n "s/^$1=//p" .env | tail -n 1 | tr -d '\r' | sed 's/^"//;s/"$//'; }
username="$(getval DB_USERNAME)"
database="$(getval DB_DATABASE)"
[ -n "$username" ] && [ -n "$database" ] || { echo "Missing DB settings." >&2; exit 1; }
case "$username:$database" in
  *[!a-zA-Z0-9_:.-]*) echo "Unexpected characters in DB settings." >&2; exit 1 ;;
esac

mkdir -p backups
file="postgres-$(date +%Y%m%d-%H%M%S).dump"
remote="/tmp/$file"
trap 'docker compose exec -T postgres rm -f "$remote" >/dev/null 2>&1 || true' EXIT HUP INT TERM

docker compose exec -T postgres pg_dump -Fc --no-owner --no-acl -U "$username" -d "$database" -f "$remote"
docker compose cp "postgres:$remote" "backups/$file"
[ -s "backups/$file" ] || { echo "Backup is empty." >&2; exit 1; }
printf 'PostgreSQL dump saved: backups/%s\n' "$file"
echo "This is only a LOCAL backup. Set up encrypted offsite backups for production."
