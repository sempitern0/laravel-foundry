#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"

port=$(sed -n 's/^HTTP_PORT=//p' .env | tail -n 1 | tr -d '"\r')
[ -n "$port" ] || port=8080
case "$port" in ''|*[!0-9]*) echo '[WARN] HTTP_PORT must be numeric. Review .env.' >&2; [ "${1:-}" != '--strict' ]; exit $?;; esac

if ! command -v curl >/dev/null 2>&1; then
  echo '[WARN] curl is unavailable; Laravel HTTP probe skipped.' >&2
  [ "${1:-}" != '--strict' ]
  exit $?
fi

probe() {
  # Do not follow redirects or disable TLS verification: this tests local HTTP.
  code=$(curl -sS -o /dev/null -w '%{http_code}' --max-time 5 "http://127.0.0.1:$port$1" 2>/dev/null) || code=000
  case "$code" in
    2??|3??|401|403) return 0 ;;
    *) return 1 ;;
  esac
}

if probe /up; then
  echo "[OK] Laravel responded over HTTP (/up: $code)."
  exit 0
fi
up_code=$code

# Laravel's /up is optional in custom starters. Do not hide an upstream 500
# merely because another route happens to be served successfully.
if [ "$up_code" = 404 ] || [ "$up_code" = 000 ]; then
  if probe /; then
    echo "[OK] Laravel responded over HTTP (/: $code; /up: $up_code)."
    exit 0
  fi
  root_code=$code
else
  root_code='no consultado'
fi

echo "[WARN] Laravel HTTP probe failed (/up: $up_code; /: $root_code)." >&2
echo 'Next steps: docker compose logs --tail=80 web app; make artisan CMD="about"' >&2
[ "${1:-}" != '--strict' ]
