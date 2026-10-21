#!/usr/bin/env sh
set -eu
source_dir=$(CDPATH= cd -- "$(dirname "$0")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT HUP INT TERM
mkdir -p "$temp/project"
cp "$source_dir/.env.example" "$temp/project/.env.example"
cp "$source_dir/.env.example" "$temp/project/.env"
printf '\nSETUP_CONFIGURED=1\nPROJECT_NAME=old-application\n' >> "$temp/project/.env"
(
  cd "$temp/project"
  sh "$source_dir/scripts/prepare-fresh-project.sh"
  grep -q '^SETUP_CONFIGURED=0$' .env
  grep -q '^PROJECT_NAME=project-' .env
  test -n "$(find app-backups -type f -name '*.bak' -print -quit)"
  first=$(sed -n 's/^PROJECT_NAME=//p' .env)
  mkdir -p app
  printf 'fixture' > app/artisan
  sh "$source_dir/scripts/prepare-fresh-project.sh"
  test "$first" = "$(sed -n 's/^PROJECT_NAME=//p' .env)"
  rm app/artisan
  printf '{"version":1}' > .foundry.json
  if sh "$source_dir/scripts/prepare-fresh-project.sh"; then
    echo 'Unexpected fresh install over portable project' >&2
    exit 1
  fi
)
echo 'PASS fresh setup isolation, backup, resume and incomplete project guard'
