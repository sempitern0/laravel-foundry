#!/usr/bin/env sh
# Repair ownership of Docker-managed npm volumes only. Never chown the host checkout.
set -eu

uid="${DEV_UID:-1000}"
gid="${DEV_GID:-1000}"
case "$uid:$gid" in
    *[!0-9:]*|:*|*:) echo 'DEV_UID/DEV_GID must be numeric.' >&2; exit 2 ;;
esac

for dir in /var/www/html/node_modules /tmp/npm-cache; do
    mkdir -p "$dir"
    owner="$(stat -c '%u:%g' "$dir")"
    if [ "$owner" != "$uid:$gid" ]; then
        printf 'Repairing npm volume ownership: %s (%s -> %s:%s)\n' "$dir" "$owner" "$uid" "$gid"
        chown -R "$uid:$gid" "$dir"
    fi
done
