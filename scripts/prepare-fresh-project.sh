#!/usr/bin/env sh
set -eu
root=$(pwd)
if [ -f app/artisan ]; then exit 0; fi
if [ -f .foundry.json ]; then
  echo 'Configured project has no app/artisan. Restore its source before setup.' >&2
  exit 2
fi
if [ -d app ] && [ -n "$(find app -mindepth 1 -maxdepth 1 ! -name node_modules ! -name vendor -print -quit)" ]; then
  echo 'app/ contains files but no artisan; refusing to overwrite.' >&2
  exit 2
fi
[ -f .env.example ] || { echo 'Missing .env.example.' >&2; exit 2; }
if [ -f .env ] && ! cmp -s .env .env.example; then
  mkdir -p app-backups
  backup="app-backups/foundry-env-$(date +%Y%m%d-%H%M%S)-$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n').bak"
  cp .env "$backup"
  echo 'Previous local settings backed up under app-backups/.'
fi
slug=$(basename "$root" | tr '[:upper:]' '[:lower:]' | tr -c 'a-z0-9_-' '-')
slug=$(printf '%s' "$slug" | sed 's/^-*//;s/-*$//')
case "$slug" in [a-z]*) ;; *) slug="project-$slug";; esac
slug=$(printf '%s' "$slug" | cut -c1-26)
suffix=$(od -An -N4 -tx1 /dev/urandom | tr -d ' \n')
name="$slug-$suffix"
sed "s/^PROJECT_NAME=.*/PROJECT_NAME=$name/" .env.example > .env
rm -f .foundry-starter
printf 'New project: %s. Choose settings in the wizard.\n' "$name"
