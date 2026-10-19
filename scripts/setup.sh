#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

sh scripts/bootstrap.sh "${1:-}"
sh scripts/configure-app.sh
docker compose up -d --build postgres mailpit app web

if ! grep -Eq '^APP_KEY=.+$' app/.env; then
  docker compose exec -T app php artisan key:generate --force
fi

docker compose exec -T app php artisan migrate --force
docker compose --profile dev run --rm --no-deps --entrypoint npm node install
docker compose --profile dev up -d node

printf '\nApplication: http://localhost:%s\nMailpit: http://localhost:%s\n' \
  "$(sed -n 's/^HTTP_PORT=//p' .env | head -n 1)" \
  "$(sed -n 's/^MAILPIT_PORT=//p' .env | head -n 1)"
