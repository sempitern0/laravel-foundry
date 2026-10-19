#!/usr/bin/env sh
set -eu
[ -f .env ] || { echo "Run make setup first (.env missing)" >&2; exit 1; }
[ -f app/.env ] || cp app/.env.example app/.env

getval() {
  value=$(sed -n "s/^$1=//p" .env | head -n 1)
  [ -n "$value" ] || { echo "Missing setting '$1' in .env" >&2; exit 1; }
  printf '%s' "$value"
}
putval() {
  key="$1"
  value="$2"
  escaped=$(printf '%s' "$value" | sed 's/[\\&|]/\\&/g')
  if grep -q "^$key=" app/.env; then
    sed "s|^$key=.*|$key=$escaped|" app/.env > app/.env.letsgo-tmp
    mv app/.env.letsgo-tmp app/.env
  else
    printf '%s=%s\n' "$key" "$value" >> app/.env
  fi
}
putval APP_URL "http://localhost:$(getval HTTP_PORT)"
putval DB_CONNECTION pgsql
putval DB_HOST postgres
putval DB_PORT 5432
putval DB_DATABASE "$(getval DB_DATABASE)"
putval DB_USERNAME "$(getval DB_USERNAME)"
putval DB_PASSWORD "$(getval DB_PASSWORD)"
putval MAIL_MAILER smtp
putval MAIL_HOST mailpit
putval MAIL_PORT 1025
putval QUEUE_CONNECTION database
putval CACHE_STORE database
putval SESSION_DRIVER database
putval REDIS_HOST redis
# APP_KEY is intentionally left untouched. make setup only generates a missing key.
