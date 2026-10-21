#!/usr/bin/env sh
set -eu
repo=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
temp=$(mktemp -d)
trap 'rm -rf "$temp"' EXIT HUP INT TERM
mkdir -p "$temp/project/scripts" "$temp/bin"
cp "$repo/scripts/check-http.sh" "$temp/project/scripts/check-http.sh"
printf 'HTTP_PORT=18080\n' > "$temp/project/.env"
cat > "$temp/bin/curl" <<'MOCK'
#!/bin/sh
for url do :; done
case "$url" in
 */up) printf '%s' "${MOCK_UP:-000}" ;;
 */) printf '%s' "${MOCK_ROOT:-000}" ;;
esac
MOCK
chmod +x "$temp/bin/curl"
test_case() {
  up=$1; root=$2; expected=$3
  if (cd "$temp/project" && PATH="$temp/bin:$PATH" MOCK_UP="$up" MOCK_ROOT="$root" sh scripts/check-http.sh --strict >/dev/null 2>&1); then got=ok; else got=fail; fi
  [ "$got" = "$expected" ] || { echo "HTTP $up / $root expected $expected, got $got" >&2; exit 1; }
}
test_case 200 000 ok
test_case 302 000 ok
test_case 404 200 ok
test_case 404 401 ok
test_case 404 404 fail
test_case 500 200 fail
test_case 000 000 fail
test_case 000 503 fail
echo 'PASS Laravel HTTP probe 200, redirect, auth, 404, 500 and unavailable'
