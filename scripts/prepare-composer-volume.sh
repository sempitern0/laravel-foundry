#!/usr/bin/env sh
# Only the named composer_home Docker volume is changed, never the bind-mounted app.
set -eu

uid="${DEV_UID:-1000}"
gid="${DEV_GID:-1000}"
case "$uid:$gid" in
    *[!0-9:]*|:*|*:) echo 'DEV_UID and DEV_GID must be numeric.' >&2; exit 2 ;;
esac

dir=/tmp/composer
mkdir -p "$dir"
owner="$(stat -c '%u:%g' "$dir")"
if [ "$owner" != "$uid:$gid" ]; then
    printf 'Repairing Composer volume ownership: %s (%s -> %s:%s)\n' "$dir" "$owner" "$uid" "$gid"
    chown -R "$uid:$gid" "$dir"
fi
