#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
mode=${1:-run}
case "$mode" in run|setup) :;; *) echo 'Expected run or setup.' >&2; exit 2;; esac
[ -f .env ] || { echo '[ERROR] Missing .env; run make setup.' >&2; exit 1; }
val() { sed -n "s/^$1=//p" .env | tail -n 1 | tr -d '\r' | sed 's/^"//;s/"$//'; }
name=$(val PROJECT_NAME); db=$(val DB_ENGINE); queue=$(val QUEUE_ENGINE)
mail=$(val MAIL_ENGINE); ui=$(val DB_UI); https=$(val HTTPS_ENABLED)
tenancy=$(val TENANCY_MODE); tenancy=${tenancy:-none}
case "$name" in ''|[!a-z]*|*[!a-z0-9_-]*) echo '[ERROR] Invalid PROJECT_NAME.' >&2; exit 1;; esac
case "$db" in postgres|mariadb|mysql|sqlite) :;; *) echo '[ERROR] Invalid DB_ENGINE; run make reconfigure.' >&2;exit 1;; esac
case "$queue" in sync|database|redis) :;; *) echo '[ERROR] Invalid QUEUE_ENGINE; run make reconfigure.' >&2;exit 1;; esac
case "$mail" in mailpit|log|smtp) :;; *) echo '[ERROR] Invalid MAIL_ENGINE; run make reconfigure.' >&2;exit 1;; esac
case "$ui" in none|pgweb|phpmyadmin|adminer) :;; *) echo '[ERROR] Invalid DB_UI; run make reconfigure.' >&2;exit 1;; esac
case "$tenancy" in none|shared-db|database-per-tenant) :;; *) echo '[ERROR] Invalid TENANCY_MODE; run make reconfigure.' >&2;exit 1;; esac
case "$https" in 0|1) :;; *) echo '[ERROR] Invalid HTTPS_ENABLED; run make reconfigure.' >&2;exit 1;; esac
if { [ "$db" = sqlite ] && [ "$ui" != none ]; } || { [ "$ui" = pgweb ] && [ "$db" != postgres ]; } || { [ "$ui" = phpmyadmin ] && [ "$db" != mysql ] && [ "$db" != mariadb ]; }; then
 echo '[ERROR] Database UI is incompatible with DB_ENGINE.' >&2;exit 1
fi
if [ "$https" = 1 ]; then case "$(val LOCAL_DOMAIN)" in *.test) :;; *) echo '[ERROR] HTTPS requires a .test domain.' >&2;exit 1;; esac; fi
if [ "$mode" = run ]; then
 [ -f app/artisan ] && [ -f app/composer.json ] || { echo '[ERROR] Missing Laravel source; run make setup.' >&2;exit 1; }
elif [ -f .foundry.json ] && [ ! -f app/artisan ]; then
 echo '[ERROR] Portable manifest exists but Laravel source is missing; restore app/.' >&2;exit 1
fi
# Compare against the last successful local setup (credentials never stored).
if [ -f .foundry-runtime-state ]; then
  for key in PROJECT_NAME DB_ENGINE DB_DATABASE; do
    previous=$(sed -n "s/^$key=//p" .foundry-runtime-state | tail -n 1 | tr -d '\r')
    current=$(val "$key")
    if [ -n "$previous" ] && [ "$previous" != "$current" ]; then
      echo "[WARN] $key changed ($previous -> $current). Existing data remains in the previous volumes." >&2
      if [ "$mode" = run ]; then echo '[ERROR] Review changes and run make reconfigure before starting.' >&2; exit 1; fi
    fi
  done
fi
ports=''
for spec in "HTTP_PORT:web:8080" "HTTPS_PORT:caddy-local:443" "DB_UI_PORT:$ui:8081" "MAILPIT_PORT:mailpit:8025" "VITE_PORT:node:5173"; do
 key=${spec%%:*}; rest=${spec#*:}; service=${rest%%:*}; default=${rest##*:}
 case "$key" in
 HTTPS_PORT) [ "$https" = 1 ] || continue;;
 DB_UI_PORT) [ "$ui" != none ] || continue;;
 MAILPIT_PORT) [ "$mail" = mailpit ] || continue;;
 VITE_PORT) [ "$https" != 1 ] || continue;;
 esac
 port=$(val "$key"); [ -n "$port" ] || port=$default
 case "$port" in ''|*[!0-9]*) echo "[ERROR] $key must be numeric." >&2;exit 1;; esac
 [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || { echo "[ERROR] $key must be between 1 and 65535." >&2;exit 1; }
 case " $ports " in *" $port "*) echo "[ERROR] Port $port is assigned to multiple services." >&2;exit 1;; esac
 ports="$ports $port"
 if docker compose ps --services --status running 2>/dev/null | grep -Fxq "$service"; then continue; fi
 if command -v python3 >/dev/null 2>&1; then
   if ! python3 - "$port" <<'PY'
import socket,sys
s=socket.socket()
try:
    s.bind(("127.0.0.1",int(sys.argv[1])))
except OSError:
    sys.exit(1)
finally:
    s.close()
PY
   then echo "[ERROR] Port $port is occupied ($key); update .env." >&2;exit 1; fi
 else
   echo "[WARN] Could not check port $port (python3 unavailable)." >&2
 fi
done
echo '[OK] Configuration and ports validated.'
