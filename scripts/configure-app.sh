#!/usr/bin/env sh
set -eu
[ -f app/.env ] || cp app/.env.example app/.env
# Keep credentials synchronized with compose .env (no eval or shell sourcing).
getval() { sed -n "s/^$1=//p" .env | head -n 1; }
putval() {
  key="$1"; value="$2"
  if grep -q "^$key=" app/.env; then
    sed -i.bak "s|^$key=.*|$key=$value|" app/.env && rm -f app/.env.bak
  else printf '%s=%s\n' "$key" "$value" >> app/.env; fi
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
