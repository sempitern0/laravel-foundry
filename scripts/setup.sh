#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# The wizard needs to run before the starter download; a failed clone must not
# suppress infrastructure questions. app/ can be empty at this point.
php scripts/prepare-fresh-project.php
[ -f .env ] || cp .env.example .env
docker compose build composer
docker compose run --rm --no-deps composer php /opt/letsgo/env-sync.php --root-only
docker compose run --rm --no-deps composer php /opt/letsgo/project-config.php restore
docker compose run --rm --interactive --no-deps composer php /opt/letsgo/wizard.php ${FOUNDRY_WIZARD_MODE:---if-needed}
docker compose build app composer node
sh scripts/bootstrap.sh "${1:-}"
docker compose run --rm --no-deps composer php /opt/letsgo/project-config.php save
docker compose run --rm --no-deps composer php /opt/letsgo/configure-app.php

db=$(sed -n 's/^DB_ENGINE=//p' .env | tr -d '"')
https=$(sed -n 's/^HTTPS_ENABLED=//p' .env | tr -d '"')
if [ "$db" = "postgres" ]; then docker compose up -d --wait --wait-timeout 120 postgres; fi
if [ "$db" = "mariadb" ]; then docker compose up -d --wait --wait-timeout 120 mariadb; fi
if [ "$db" = "mysql" ]; then docker compose up -d --wait --wait-timeout 120 mysql; fi
docker compose up -d --wait --wait-timeout 120 app web

if ! grep -Eq '^APP_KEY=("[^"]+"|[^"[:space:]]+)$' app/.env; then
  docker compose exec -T app php artisan key:generate --force
fi
docker compose exec -T app php artisan migrate --force
if [ -f app/package.json ]; then
  docker compose --profile dev run --rm --no-deps --entrypoint sh node /opt/letsgo/npm-ensure.sh
  docker compose --profile dev run --rm --no-deps --entrypoint npm node run build
  rm -f app/public/hot
fi
docker compose up -d
docker compose ps
tenancy_mode=$(sed -n 's/^TENANCY_MODE=//p' .env | tr -d '"')
if [ "$tenancy_mode" != "none" ] && [ -n "$tenancy_mode" ]; then
  printf 'SaaS blueprint: %s. Check tenant hosts with make tenancy-check; implement Laravel tenant isolation separately.\n' "$tenancy_mode"
fi

# The CA root is generated within Caddy; installing trust on the host is a
# distinct, opt-in operation, never part of unattended setup.
if [ "$https" = "1" ]; then
  domain=$(sed -n 's/^LOCAL_DOMAIN=//p' .env | tr -d '"')
  port=$(sed -n 's/^HTTPS_PORT=//p' .env | tr -d '"')
  suffix=":$port"
  [ "$port" = "443" ] && suffix=""
  printf 'HTTPS: https://%s%s\nConfigure hosts and trust the local CA: make https-setup\n' "$domain" "$suffix"
fi
