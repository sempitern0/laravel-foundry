#!/usr/bin/env sh
# Runs inside the Debian Node container, identically on Windows and Unix hosts.
set -eu
cd /var/www/html

[ -f package.json ] || {
  echo "package.json missing. Run make setup first." >&2
  exit 1
}

# Reuse dependencies only when the installed lock snapshot still matches.
# A changed lockfile must be installed even if package.json is unchanged.
if [ -f package-lock.json ] && [ -f node_modules/.foundry-package-lock ] \
  && cmp -s package-lock.json node_modules/.foundry-package-lock \
  && npm ls --depth=0 --silent >/dev/null 2>&1; then
  echo "npm dependencies already installed; skipping redundant installation."
  exit 0
fi

echo "Installing npm dependencies to Docker-managed node_modules..."
if [ -f package-lock.json ]; then
  npm ci --prefer-offline --no-audit --no-fund --progress=false
  cp package-lock.json node_modules/.foundry-package-lock
else
  npm install --prefer-offline --no-audit --no-fund --progress=false
  [ ! -f package-lock.json ] || cp package-lock.json node_modules/.foundry-package-lock
fi
