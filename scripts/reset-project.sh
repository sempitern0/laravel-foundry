#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
[ -f .env.example ] || { echo "Template .env.example not found." >&2; exit 1; }
project=letsgo
if [ -f .env ]; then
    name=$(sed -n 's/^PROJECT_NAME=//p' .env | head -n 1 | tr -d '"\r')
    [ -z "$name" ] || project="$name"
fi
case "$project" in
    ""|*[!a-zA-Z0-9_-]*) echo "Invalid Compose project name." >&2; exit 1 ;;
esac
[ -t 0 ] || { echo "Interactive terminal required for reset." >&2; exit 2; }

printf 'PERMANENT RESET: remove app/, .env, .foundry.json and all Docker volumes for %s\n' "$project"
printf 'backups/ and app-backups/ will remain. hosts and OS certificate trust will remain unchanged.\n'
printf 'Type exactly "RESET %s" to continue: ' "$project"
IFS= read -r answer || exit 2
[ "$answer" = "RESET $project" ] || { echo "Cancelled without changes." >&2; exit 2; }

docker compose \
  --profile dev --profile workers --profile scheduler \
  --profile redis --profile https --profile pgweb --profile adminer \
  --profile mariadb --profile mysql --profile phpmyadmin --profile postgres --profile mailpit --profile tools \
  down --volumes --remove-orphans

for path in app .env .foundry.json .foundry-starter certs/caddy-local-root.crt caddy-local-root.crt; do
    [ ! -L "$path" ] || { echo "Refusing symlink: $path" >&2; exit 1; }
    [ ! -e "$path" ] || { rm -rf -- "$path"; printf 'Removed: %s\n' "$path"; }
done
[ ! -d certs ] || rmdir certs 2>/dev/null || true
echo "Template reset complete. Run make setup STARTER=svelte (or another starter)."
