#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
port=$(sed -n 's/^HTTP_PORT=//p' .env | tail -n 1 | tr -d '"')
[ -n "$port" ] || port=8080
if ! command -v curl >/dev/null 2>&1; then
  echo 'AVISO: curl no disponible; sin verificacion HTTP.' >&2
  exit 0
fi
for path in /up /; do
  code=$(curl -sS -L -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$port$path" 2>/dev/null || :)
  case "$code" in 2??|3??|4??) echo '[OK] Laravel responde por HTTP.'; exit 0;; esac
done
echo 'AVISO: Laravel no responde correctamente; revisa make logs.' >&2
[ "${1:-}" = --strict ] && exit 1
exit 0
