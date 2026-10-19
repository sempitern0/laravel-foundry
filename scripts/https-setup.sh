#!/usr/bin/env sh
set -eu
cd "$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)"
echo "Local HTTPS: add your domain to /etc/hosts (e.g. 127.0.0.1 yourapp.test)."
echo "Only edit hosts with elevated permissions if you authorize it."
docker compose --profile https up -d caddy-local
mkdir -p certs
attempt=0
while :; do
    if docker compose --profile https cp caddy-local:/data/caddy/pki/authorities/local/root.crt certs/caddy-local-root.crt 2>/dev/null &&
        [ -s certs/caddy-local-root.crt ]; then
        break
    fi
    attempt=$((attempt + 1))
    if [ "$attempt" -ge 10 ]; then
        echo "Caddy root certificate not available. Inspect docker compose logs caddy-local." >&2
        exit 1
    fi
    sleep 1
done
echo "Root CA exported to certs/caddy-local-root.crt. Review its fingerprint and"
echo "import into your OS/browser trust store manually only if you trust it."
