#!/usr/bin/env sh
# Read-only status card. Never print passwords or application secrets.
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
[ -f .env ] || { echo 'Foundry: missing .env; run make setup.' >&2; exit 1; }
value() {
  sed -n "s/^$1=//p" .env | tail -n 1 | sed 's/^"//;s/"$//'
}
setting() {
  v=$(value "$1")
  if [ -n "$v" ]; then printf '%s' "$v" | tr -d '\r\n'; else printf '%s' "$2"; fi
}
name=$(setting PROJECT_NAME foundry)
label=$(setting APP_LABEL "$name")
db=$(setting DB_ENGINE postgres)
db_name=$(setting DB_DATABASE foundry)
queue=$(setting QUEUE_ENGINE sync)
mail=$(setting MAIL_ENGINE log)
ui=$(setting DB_UI none)
https=$(setting HTTPS_ENABLED 0)
http_port=$(setting HTTP_PORT 8080)
https_port=$(setting HTTPS_PORT 443)
domain=$(setting LOCAL_DOMAIN foundry.test)
tenancy=$(setting TENANCY_MODE none)
profiles=$(setting COMPOSE_PROFILES '-')
if [ -f app/.letsgo-starter ]; then starter=$(tr -d '\r\n' < app/.letsgo-starter)
elif [ -f app/artisan ]; then starter=existing
else starter=pending
fi

running=''
if docker compose ps --services --status running >/dev/null 2>&1; then
  running=$(docker compose ps --services --status running 2>/dev/null)
  status=available
else
  status=unavailable
fi
active() { printf '%s\n' "$running" | grep -Fxq "$1"; }
service() {
  if active "$1"; then state=running; else state=stopped; fi
  printf '  %-18s %s\n' "$2" "$state"
}
link() {
  if [ "$3" = yes ]; then printf '  %-18s %s\n' "$1" "$2"
  else printf '  %-18s %s\n' "$1" '(configured, not running)'
  fi
}
ready=no
if active app && active web; then ready=yes; fi
printf '\n======================================================\n'
printf '  Laravel Foundry | %s\n' "$label"
printf '======================================================\n'
printf '  Project:        %s\n' "$name"
printf '  Starter:        %s\n' "$starter"
printf '  Database:       %s (%s)\n' "$db" "$db_name"
printf '  Queue:          %s\n' "$queue"
printf '  Mail:           %s\n' "$mail"
printf '  Database UI:    %s\n' "$ui"
printf '  Local HTTPS:    %s\n' "$https"
printf '  Tenancy:        %s (configuration only)\n' "$tenancy"
printf '  Profiles:       %s\n' "$profiles"
printf '\nSERVICES\n'
[ "$status" = available ] || echo '  Could not check Docker. Start Docker Engine or Docker Desktop.'
service app 'Laravel PHP'
service web 'Nginx'
[ "$https" = 1 ] && service caddy-local 'HTTPS Caddy'
[ "$db" = sqlite ] || service "$db" "$db"
[ "$queue" = sync ] || service worker 'Queue worker'
service scheduler 'Scheduler'
[ "$queue" = redis ] && service redis Redis
[ "$mail" = mailpit ] && service mailpit Mailpit
[ "$ui" = none ] || service "$ui" "$ui"
printf '\nBROWSER ACCESS\n'
link 'Application HTTP' "http://localhost:$http_port" "$ready"
if [ "$https" = 1 ]; then
  suffix=":$https_port"; [ "$https_port" = 443 ] && suffix=''
  webready=no
  if [ "$ready" = yes ] && active caddy-local; then webready=yes; fi
  link 'Application HTTPS' "https://$domain$suffix" "$webready"
fi
if [ "$mail" = mailpit ]; then
  enabled=no; active mailpit && enabled=yes
  link Mailpit "http://localhost:$(setting MAILPIT_PORT 8025)" "$enabled"
fi
case "$ui" in
  pgweb|phpmyadmin|adminer)
    enabled=no; active "$ui" && enabled=yes
    link "$ui" "http://localhost:$(setting DB_UI_PORT 8081)" "$enabled"
    ;;
esac
if [ "$https" != 1 ] && active node; then
  printf '  Vite (HMR):       http://localhost:%s (developer tool)\n' "$(setting VITE_PORT 5173)"
fi
printf '\n'
[ "$https" = 1 ] && printf '  HTTPS needs hosts (127.0.0.1 %s) and trusted local CA (make https-setup).\n' "$domain"
[ "$tenancy" = none ] || echo '  Tenancy blueprint does not implement Laravel tenant isolation.'
echo '  Running container does not guarantee an HTTP-ready application.'
echo '  Commands: make status | make ps | make logs | make up-wait | make reconfigure'
echo '======================================================'
