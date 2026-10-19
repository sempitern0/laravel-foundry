#!/usr/bin/env sh
# Runs inside the Debian Node container, identically on Windows and Unix hosts.
set -eu
cd /var/www/html

[ -f package.json ] || {
  echo "package.json missing. Run make setup first." >&2
  exit 1
}

# Composer's Laravel install:features hook may already have run npm install
# inside PHP. Reuse that work instead of installing the same tree twice.
if [ -f package-lock.json ] && [ -f node_modules/.package-lock.json ] \
  && npm ls --depth=0 --silent >/dev/null 2>&1; then
  echo "npm dependencies already installed; skipping redundant installation."
  exit 0
fi

echo "Installing npm dependencies to Docker-managed node_modules..."
npm install --prefer-offline --no-audit --no-fund --progress=false
