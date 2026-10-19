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
# Remove Git history in disposable storage before writing to the Windows mount.
rm -rf "$scratch/source/.git"
# Docker Desktop bind mounts may reject ownership, mode and timestamp changes
# (notably trying to preserve /var/www/html itself with "cp -a").
# Plain recursive copy does not attempt to preserve these attributes.
# The destination already contains a separate node_modules Docker volume.
cp -R "$scratch/source/." "$target/"
[ -f "$target/artisan" ] && [ -f "$target/composer.json" ] || {
  echo "Starter copy incomplete; existing app/ files have been preserved." >&2
  exit 1
}
printf 'Installed starter from %s (%s) into app/\n' "$repository" "$revision"
