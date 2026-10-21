#!/usr/bin/env sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT HUP INT TERM
mkdir -p "$temp/project/scripts" "$temp/project/app" "$temp/bin"
cp "$repo/scripts/preflight.sh" "$temp/project/scripts/"
cat > "$temp/project/.env" <<'ENV'
PROJECT_NAME="videoapp"
DB_ENGINE="mariadb"
QUEUE_ENGINE="database"
MAIL_ENGINE="mailpit"
DB_UI="phpmyadmin"
HTTPS_ENABLED="1"
LOCAL_DOMAIN="videoapp.test"
HTTP_PORT=18080
HTTPS_PORT=18443
DB_UI_PORT=18081
MAILPIT_PORT=18025
ENV
touch "$temp/project/app/artisan" "$temp/project/app/composer.json"
cat > "$temp/bin/docker" <<'DOCKER'
#!/bin/sh
if [ "$1" = compose ]; then printf 'web\ncaddy-local\nmailpit\nphpmyadmin\n';fi
DOCKER
chmod +x "$temp/bin/docker"
(cd "$temp/project"; PATH="$temp/bin:$PATH" sh scripts/preflight.sh run)
printf '\nHTTP_PORT=18443\n' >> "$temp/project/.env"
if (cd "$temp/project"; PATH="$temp/bin:$PATH" sh scripts/preflight.sh run); then
 echo 'Duplicate port was not rejected' >&2;exit 1
fi
echo 'PASS preflight valid config and conflicting ports'
