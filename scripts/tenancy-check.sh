#!/usr/bin/env sh
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
[ -f .env ] || { echo "Missing .env; run setup" >&2; exit 1; }
getval() { sed -n "s/^$1=//p" .env | tail -n 1 | tr -d '\r' | sed 's/^"//;s/"$//'; }
mode=$(getval TENANCY_MODE)
[ -n "$mode" ] && [ "$mode" != none ] || { echo 'SaaS blueprint disabled; reconfigure setup.' >&2; exit 2; }
domain=$(getval LOCAL_DOMAIN)
case "$domain" in *.test) ;; *) echo "Domain must end in .test" >&2; exit 2 ;; esac
https=$(getval HTTPS_ENABLED)
slugs=$(getval TENANCY_TEST_TENANTS)
[ -n "$slugs" ] || slugs=alpha,beta
path=$(getval TENANCY_TEST_PATH)
[ -n "$path" ] || path=/
case "$path" in /*) ;; *) echo 'TENANCY_TEST_PATH must begin with /' >&2; exit 2 ;; esac
case "$path" in //*) echo 'TENANCY_TEST_PATH must be relative' >&2; exit 2 ;; esac
header=$(getval TENANCY_ASSERT_HEADER)
if [ "$https" = 1 ]; then
  scheme=https
  port=$(getval HTTPS_PORT)
  [ -n "$port" ] || port=443
  [ -f certs/caddy-local-root.crt ] || { echo 'Export Caddy CA with make https-setup' >&2; exit 2; }
else
  scheme=http
  port=$(getval HTTP_PORT)
  [ -n "$port" ] || port=8080
fi
oldifs=$IFS
IFS=,
set -- $slugs
IFS=$oldifs
for slug do
  case "$slug" in ""|*[!a-z0-9-]*) echo "Invalid tenant slug" >&2; exit 2 ;; esac
  hostname="$slug.$domain"
  url="$scheme://$hostname:$port$path"
  if [ "$https" = 1 ]; then
    output=$(curl --silent --show-error --fail --max-time 10 --cacert certs/caddy-local-root.crt --resolve "$hostname:$port:127.0.0.1" -D - -o /dev/null "$url") || exit 1
  else
    output=$(curl --silent --show-error --fail --max-time 10 --resolve "$hostname:$port:127.0.0.1" -D - -o /dev/null "$url") || exit 1
  fi
  if [ -n "$header" ]; then
    val=$(printf '%s\n' "$output" | tr -d '\r' | grep -i "^$header:" | tail -n 1 | cut -d ':' -f 2- | sed 's/^ *//;s/ *$//') || true
    [ "$val" = "$slug" ] || { echo "$url failed tenant identity check" >&2; exit 1; }
  fi
  printf 'PASS %s\n' "$url"
done
echo 'Routing checks passed; test real tenant data isolation in Laravel.'
