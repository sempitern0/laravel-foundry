#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
mode=${1:-run}
[ -f .env ] || { echo 'ERROR: falta .env; ejecuta make setup.' >&2; exit 1; }
val() { sed -n "s/^$1=//p" .env | tail -n 1 | sed 's/^"//;s/"$//'; }
name=$(val PROJECT_NAME); db=$(val DB_ENGINE); queue=$(val QUEUE_ENGINE)
mail=$(val MAIL_ENGINE); ui=$(val DB_UI); https=$(val HTTPS_ENABLED)
case "$name" in ''|[!a-z]*|*[!a-z0-9_-]*) echo 'ERROR: PROJECT_NAME no valido.' >&2; exit 1;; esac
case "$db" in postgres|mariadb|mysql|sqlite) :;; *) echo 'ERROR: DB_ENGINE invalido.' >&2;exit 1;; esac
case "$queue" in sync|database|redis) :;; *) echo 'ERROR: QUEUE_ENGINE invalido.' >&2;exit 1;; esac
case "$mail" in mailpit|log|smtp) :;; *) echo 'ERROR: MAIL_ENGINE invalido.' >&2;exit 1;; esac
case "$ui" in none|pgweb|phpmyadmin|adminer) :;; *) echo 'ERROR: DB_UI invalido.' >&2;exit 1;; esac
case "$https" in 0|1) :;; *) echo 'ERROR: HTTPS_ENABLED invalido.' >&2;exit 1;; esac
if { [ "$db" = sqlite ] && [ "$ui" != none ]; } || { [ "$ui" = pgweb ] && [ "$db" != postgres ]; } || { [ "$ui" = phpmyadmin ] && [ "$db" != mysql ] && [ "$db" != mariadb ]; }; then
 echo 'ERROR: DB_UI incompatible con DB_ENGINE.' >&2;exit 1
fi
if [ "$https" = 1 ]; then case "$(val LOCAL_DOMAIN)" in *.test) :;; *) echo 'ERROR: HTTPS requiere dominio .test.' >&2;exit 1;; esac; fi
if [ "$mode" = run ]; then
 [ -f app/artisan ] && [ -f app/composer.json ] || { echo 'ERROR: faltan archivos Laravel; ejecuta make setup.' >&2;exit 1; }
elif [ -f .foundry.json ] && [ ! -f app/artisan ]; then
 echo 'ERROR: manifiesto portable sin Laravel; recupera el codigo.' >&2;exit 1
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
 case "$port" in ''|*[!0-9]*) echo "ERROR: $key no es numerico." >&2;exit 1;; esac
 [ "$port" -ge 1 ] && [ "$port" -le 65535 ] || { echo "ERROR: $key fuera de rango." >&2;exit 1; }
 case " $ports " in *" $port "*) echo "ERROR: puerto $port duplicado entre servicios." >&2;exit 1;; esac
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
   then echo "ERROR: puerto $port ocupado ($key); cambia el puerto en .env." >&2;exit 1; fi
 else
   echo "AVISO: no se ha podido probar ocupacion de puerto $port (python3 no disponible)." >&2
 fi
done
echo '[OK] Configuracion y puertos comprobados.'
