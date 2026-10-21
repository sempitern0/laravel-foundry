#!/usr/bin/env sh
set -eu
source_dir=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT HUP INT TERM
mkdir -p "$temp/project/scripts" "$temp/bin"
cp "$source_dir/scripts/status.sh" "$temp/project/scripts/status.sh"
cat > "$temp/project/.env" <<'ENV'
PROJECT_NAME="videoapp"
APP_LABEL="VideoApp"
DB_ENGINE="mariadb"
DB_DATABASE="example"
DB_PASSWORD="SECRET-NOT-FOR-LOGS"
QUEUE_ENGINE="database"
MAIL_ENGINE="mailpit"
DB_UI="phpmyadmin"
HTTPS_ENABLED="1"
HTTPS_PORT="443"
LOCAL_DOMAIN="videoapp.test"
DB_UI_PORT="8081"
MAILPIT_PORT="8025"
COMPOSE_PROFILES="mariadb,mailpit,phpmyadmin,https,workers"
ENV
cat > "$temp/bin/docker" <<'DOCKER'
#!/bin/sh
if [ "$1 $2 $3 $4 $5" = "compose ps --services --status running" ]; then
  printf 'app\nweb\ncaddy-local\nmariadb\nmailpit\nphpmyadmin\nworker\n'
  exit 0
fi
exit 1
DOCKER
chmod +x "$temp/bin/docker"
PATH="$temp/bin:$PATH" sh "$temp/project/scripts/status.sh" > "$temp/out"
grep -q 'https://videoapp.test' "$temp/out"
grep -q 'http://localhost:8081' "$temp/out"
grep -q 'http://localhost:8025' "$temp/out"
grep -q 'mariadb' "$temp/out"
if grep -q 'SECRET-NOT-FOR-LOGS' "$temp/out"; then echo 'Status leaked secrets' >&2; exit 1; fi
cat > "$temp/bin/docker" <<'DOCKER'
#!/bin/sh
exit 1
DOCKER
PATH="$temp/bin:$PATH" sh "$temp/project/scripts/status.sh" > "$temp/stop"
grep -q 'configured, not running' "$temp/stop"
if grep -q 'https://videoapp.test' "$temp/stop"; then echo 'Status advertised stopped HTTPS GUI' >&2; exit 1; fi
echo 'PASS Foundry status URLs, secret redaction and stopped-service behavior'
