#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
# Check Docker before fresh-project preparation can replace local settings.
command -v docker >/dev/null 2>&1 || { echo 'Docker is required.' >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo 'Docker Compose v2 is required.' >&2; exit 1; }
docker info --format '{{.ServerVersion}}' >/dev/null 2>&1 || {
  echo 'Docker Engine unavailable. Start Docker and retry; project settings were not changed.' >&2
  exit 1
}
# The wizard needs to run before the starter download; a failed clone must not
# suppress infrastructure questions. app/ can be empty at this point.
sh scripts/prepare-fresh-project.sh
[ -f .env ] || cp .env.example .env
sh scripts/environment.sh apply
docker compose build composer
docker compose run --rm --no-deps composer php /opt/letsgo/env-sync.php --root-only
docker compose run --rm --no-deps composer php /opt/letsgo/project-config.php restore
docker compose run --rm --interactive --no-deps composer php /opt/letsgo/wizard.php "${FOUNDRY_WIZARD_MODE:---if-needed}"
sh scripts/setup-checkpoint.sh begin
sh scripts/preflight.sh setup
docker compose build app composer node
sh scripts/bootstrap.sh "${1:-}"
docker compose run --rm --no-deps composer php /opt/letsgo/project-config.php save
docker compose run --rm --no-deps composer php /opt/letsgo/configure-app.php

db=$(sed -n 's/^DB_ENGINE=//p' .env | tail -n 1 | tr -d '"\r')
if [ "$db" = "postgres" ]; then docker compose up -d --wait --wait-timeout 120 postgres; fi
if [ "$db" = "mariadb" ]; then docker compose up -d --wait --wait-timeout 120 mariadb; fi
if [ "$db" = "mysql" ]; then docker compose up -d --wait --wait-timeout 120 mysql; fi
docker compose up -d --wait --wait-timeout 120 app web

if ! tr -d '\r' < app/.env | grep -Eq '^APP_KEY=("[^"]+"|[^"[:space:]]+)$'; then
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
sh scripts/setup-checkpoint.sh complete
sh scripts/check-http.sh || echo '[WARN] Laravel HTTP probe failed; inspect the application logs.'
sh scripts/status.sh || echo '[WARN] Summary unavailable; run make status.'
