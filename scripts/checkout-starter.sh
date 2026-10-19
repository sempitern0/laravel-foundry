#!/usr/bin/env sh
# Clone into disposable container storage. /var/www/html contains the
# mounted node_modules volume even when the host's app/ folder is empty.
set -eu
revision="${1:?Missing Git revision}"
repository="${2:?Missing Git repository}"
target=/var/www/html
[ -d "$target" ] || { echo "Missing app mount: $target" >&2; exit 1; }
if [ -e "$target/artisan" ] || [ -e "$target/composer.json" ] || [ -e "$target/.git" ]; then
  echo "Refusing to overwrite an existing Laravel checkout." >&2
  exit 2
fi
scratch=$(mktemp -d /tmp/letsgo-starter.XXXXXX)
trap 'rm -rf "$scratch"' EXIT HUP INT TERM
git clone --depth 1 --branch "$revision" "$repository" "$scratch/source"
# A copy into the mount (not git clone into it) tolerates node_modules/.
cp -a "$scratch/source/." "$target/"
rm -rf "$target/.git"
printf 'Installed starter from %s (%s) into app/\n' "$repository" "$revision"
