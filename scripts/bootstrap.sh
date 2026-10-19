#!/usr/bin/env sh
set -eu
[ -f .env ] || cp .env.example .env
if [ ! -f app/artisan ]; then
  mkdir -p app
  if [ -n "$(ls -A app 2>/dev/null)" ]; then
    echo "app/ is not empty. Refusing to overwrite." >&2
    exit 1
  fi
  docker compose run --rm --no-deps --user "$(id -u):$(id -g)" app composer create-project --no-interaction laravel/svelte-starter-kit /var/www/html
fi
if grep -q '"laravel/sail"' app/composer.json; then
  docker compose run --rm --no-deps app composer remove laravel/sail --dev --no-interaction --no-progress
fi
if [ ! -f app/.env ]; then cp app/.env.example app/.env; fi
docker compose run --rm --no-deps app php artisan key:generate --force
echo "Laravel scaffold ready. Configure app/.env database settings and run: make up"
