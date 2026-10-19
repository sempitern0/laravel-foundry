#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
echo "Local HTTPS: add your domain to /etc/hosts (e.g. 127.0.0.1 yourapp.test)."
echo "Only edit hosts with elevated permissions if you authorize it."
docker compose --profile https up -d caddy-local
mkdir -p certs
docker compose --profile https cp caddy-local:/data/caddy/pki/authorities/local/root.crt certs/caddy-local-root.crt
echo "Root CA exported to certs/caddy-local-root.crt. Review its fingerprint and"
echo "import into your OS/browser trust store manually only if you trust it."
