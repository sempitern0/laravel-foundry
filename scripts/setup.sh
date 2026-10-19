#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# The wizard needs to run before the starter download; a failed clone must not
# suppress infrastructure questions. app/ can be empty at this point.
[ -f .env ] || cp .env.example .env
docker compose build app
docker compose run --rm --interactive --no-deps app php /opt/letsgo/wizard.php
sh scripts/bootstrap.sh "${1:-}"
docker compose run --rm --no-deps app php /opt/letsgo/configure-app.php

db=$(sed -n 's/^DB_ENGINE=//p' .env | tr -d '"')
https=$(sed -n 's/^HTTPS_ENABLED=//p' .env | tr -d '"')
if [ "$db" = "postgres" ]; then docker compose up -d postgres; fi
if [ "$db" = "mariadb" ]; then docker compose up -d mariadb; fi
docker compose up -d app web

if ! grep -Eq '^APP_KEY=.+$' app/.env; then
  docker compose exec -T app php artisan key:generate --force
fi
docker compose exec -T app php artisan migrate --force
docker compose --profile dev run --rm --no-deps --entrypoint sh node /opt/letsgo/npm-ensure.sh
if [ "$https" = "1" ]; then
  docker compose --profile dev run --rm --no-deps --entrypoint npm node run build
  rm -f app/public/hot
fi
docker compose up -d
docker compose ps
