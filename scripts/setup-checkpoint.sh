#!/usr/bin/env sh
# Local state is deliberately limited to non-secret infrastructure identity.
set -eu
cd "$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)"
env_value() { sed -n "s/^$1=//p" .env | tail -n 1 | tr -d '"\r'; }
case "${1:-}" in
 begin)
  name=$(env_value PROJECT_NAME)
  case "$name" in ''|[!a-z]*|*[!a-z0-9_-]*) echo 'Invalid PROJECT_NAME' >&2;exit 2;; esac
  printf '%s\n' "$name" > .foundry-setup-pending
  ;;
 complete)
  { for key in PROJECT_NAME DB_ENGINE DB_DATABASE; do
      printf '%s=%s\n' "$key" "$(env_value "$key")"
    done; } > .foundry-runtime-state.tmp
  mv .foundry-runtime-state.tmp .foundry-runtime-state
  rm -f .foundry-setup-pending
  ;;
 *) echo 'Expected begin or complete' >&2;exit 2;;
esac
