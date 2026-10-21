#!/usr/bin/env sh
set -eu
source=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT HUP INT TERM
mkdir -p "$temp/project/scripts" "$temp/project/app"
cp "$source/scripts/prepare-fresh-project.sh" "$source/scripts/setup-checkpoint.sh" "$source/scripts/preflight.sh" "$temp/project/scripts/"
cp "$source/.env.example" "$temp/project/.env.example"
(
 cd "$temp/project"
 sh scripts/prepare-fresh-project.sh
 sed -i 's/^PROJECT_NAME=.*/PROJECT_NAME=videoapp/;s/^SETUP_CONFIGURED=.*/SETUP_CONFIGURED=1/' .env
 sh scripts/setup-checkpoint.sh begin
 sh scripts/prepare-fresh-project.sh
 grep -q '^PROJECT_NAME=videoapp$' .env
 touch app/artisan app/composer.json
 sh scripts/setup-checkpoint.sh complete
 test ! -e .foundry-setup-pending
 grep -q '^PROJECT_NAME=videoapp$' .foundry-runtime-state
 sed -i 's/^DB_ENGINE=.*/DB_ENGINE=mariadb/' .env
 if sh scripts/preflight.sh run >/dev/null 2>&1; then
    echo 'Changed database engine passed preflight unexpectedly' >&2
    exit 1
 fi
)
echo 'PASS setup checkpoint resume and database drift guard'
