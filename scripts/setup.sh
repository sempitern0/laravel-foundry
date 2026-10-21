#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# The wizard needs to run before the starter download; a failed clone must not
# suppress infrastructure questions. app/ can be empty at this point.
sh scripts/prepare-fresh-project.sh
[ -f .env ] || cp .env.example .env
docker compose build composer
docker compose run --rm --no-deps composer php /opt/letsgo/env-sync.php --root-only
docker compose run --rm --no-deps composer php /opt/letsgo/project-config.php restore
docker compose run --rm --interactive --no-deps composer php /opt/letsgo/wizard.php ${FOUNDRY_WIZARD_MODE:---if-needed}
sh scripts/preflight.sh setup
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
sh scripts/check-http.sh || echo 'AVISO: fallo del diagnostico HTTP.'
sh scripts/status.sh || echo 'AVISO: ejecuta make status para volver a mostrar el resumen.'
