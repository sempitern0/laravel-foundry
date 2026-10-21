#!/usr/bin/env sh
# Read-only status card. Never print passwords or application secrets.
set -eu
if [ -t 1 ] && [ "${NO_COLOR:-}" = '' ] && [ "${TERM:-}" != dumb ]; then
  cyan=$(printf '\033[36m'); green=$(printf '\033[32m'); yellow=$(printf '\033[33m'); dim=$(printf '\033[90m'); reset=$(printf '\033[0m')
else cyan=''; green=''; yellow=''; dim=''; reset=''; fi
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
[ -f .env ] || { echo 'Foundry: missing .env; run make setup.' >&2; exit 1; }
value() {
  sed -n "s/^$1=//p" .env | tail -n 1 | tr -d '\r' | sed 's/^"//;s/"$//'
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
section() { printf '\n%s-- %s ------------------------------------------------%s\n' "$cyan" "$1" "$reset"; }
item() { printf '  %-20s %s\n' "$1" "$2"; }
service() {
  if active "$1"; then state="${green}[OK] En marcha${reset}"
  elif [ "$status" = unavailable ]; then state="${yellow}[?] No comprobable${reset}"
  else state="${yellow}[--] Detenido${reset}"; fi
  printf '  %-23s %s\n' "$2" "$state"
}
link() {
  if [ "$3" = yes ]; then printf '  %-20s %s%s%s\n' "$1" "$4" "$2" "$reset"
  else printf '  %-20s %s[--] Configurado, detenido%s\n' "$1" "$yellow" "$reset"; fi
}
ready=no
if active app && active web; then ready=yes; fi
printf '\n%s======================================================%s\n' "$cyan" "$reset"
printf '%s  LARAVEL FOUNDRY  /  %s%s\n' "$cyan" "$label" "$reset"
printf '%s======================================================%s\n' "$cyan" "$reset"
section 'ACCESOS WEB'
if [ "$https" = 1 ]; then
  suffix=":$https_port"; [ "$https_port" = 443 ] && suffix=''
  webready=no
  if [ "$ready" = yes ] && active caddy-local; then webready=yes; fi
  link 'APP PRINCIPAL' "https://$domain$suffix" "$webready" "$green"
fi
primary="$cyan"; [ "$https" = 1 ] || primary="$green"
link 'Aplicacion HTTP' "http://localhost:$http_port" "$ready" "$primary"
if [ "$mail" = mailpit ]; then
  enabled=no; active mailpit && enabled=yes
  link 'Mailpit' "http://localhost:$(setting MAILPIT_PORT 8025)" "$enabled" "$cyan"
fi
case "$ui" in
 pgweb|phpmyadmin|adminer)
   enabled=no; active "$ui" && enabled=yes
   link "$ui" "http://localhost:$(setting DB_UI_PORT 8081)" "$enabled" "$cyan";;
esac
if [ "$https" != 1 ] && active node; then
  link 'Vite HMR' "http://localhost:$(setting VITE_PORT 5173)" yes "$cyan"
fi
section 'CONFIGURACION'
item 'Proyecto / starter' "$name / $starter"
item 'Base de datos' "$db | $db_name"
item 'Colas / correo' "$queue | $mail"
item 'Panel de BD' "$ui"
item 'HTTPS / tenancy' "$https | $tenancy"
item 'Perfiles' "$profiles"
section 'CONTENEDORES'
[ "$status" = available ] || printf '  %sDocker no disponible: no se pueden verificar los servicios.%s\n' "$yellow" "$reset"
service app 'Laravel PHP'
service web 'Nginx'
[ "$https" = 1 ] && service caddy-local 'HTTPS Caddy'
[ "$db" = sqlite ] || service "$db" "$db"
[ "$queue" = sync ] || service worker 'Worker de colas'
service scheduler 'Scheduler'
[ "$queue" = redis ] && service redis 'Redis'
[ "$mail" = mailpit ] && service mailpit 'Mailpit'
[ "$ui" = none ] || service "$ui" "$ui"
section 'NOTAS'
[ "$https" = 1 ] && printf '  %sHTTPS: hosts 127.0.0.1 %s / make https-setup.%s\n' "$yellow" "$domain" "$reset"
[ "$tenancy" = none ] || printf '  %sTenancy requiere aislamiento implementado en Laravel.%s\n' "$yellow" "$reset"
printf '  %s[OK] = contenedor iniciado, no prueba HTTP.%s\n' "$dim" "$reset"
echo '  make status | make ps | make logs | make up-wait | make reconfigure'
printf '%s======================================================%s\n' "$cyan" "$reset"
