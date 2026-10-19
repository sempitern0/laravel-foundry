#!/usr/bin/env sh
set -eu

[ -f .env ] || cp .env.example .env
command -v docker >/dev/null 2>&1 || { echo "Docker is required." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 is required." >&2; exit 1; }

starter="${1:-}"
if [ -z "$starter" ]; then
  if [ -t 0 ]; then
    printf '\nChoose your Laravel starter:\n' >&2
    printf '  1) Laravel only (no authentication starter) [default]\n' >&2
    printf '  2) Svelte + Inertia\n  3) Vue + Inertia\n' >&2
    printf '  4) React + Inertia\n  5) Livewire\n' >&2
    printf 'Select [1-5]: ' >&2
    IFS= read -r answer || exit 1
    case "$answer" in
      ""|1) starter=laravel ;;
      2) starter=svelte ;;
      3) starter=vue ;;
      4) starter=react ;;
      5) starter=livewire ;;
      *) echo "Invalid starter selection." >&2; exit 2 ;;
    esac
  else
    starter=laravel
    echo "Non-interactive setup: plain Laravel. Use STARTER=svelte|vue|react|livewire to override."
  fi
fi

case "$starter" in
  laravel|blank|none) starter=laravel; repository=laravel/laravel; revision=13.x ;;
  svelte) repository=laravel/svelte-starter-kit; revision=main ;;
  vue) repository=laravel/vue-starter-kit; revision=main ;;
  react) repository=laravel/react-starter-kit; revision=main ;;
  livewire) repository=laravel/livewire-starter-kit; revision=main ;;
  *) echo "Unknown starter: $starter (laravel|svelte|vue|react|livewire)" >&2; exit 2 ;;
esac

if [ -f app/artisan ]; then
  echo "Existing Laravel app found. Preserving its code and frontend."
  if grep -Eq '"laravel/sail"[[:space:]]*:' app/composer.json; then
    echo "Removing unwanted Laravel Sail from existing app (and updating composer.lock)."
    docker compose build app
    docker compose run --rm --no-deps app composer remove laravel/sail --dev --no-interaction --no-progress
  fi
  if [ ! -f app/vendor/autoload.php ]; then
    docker compose build app
    docker compose run --rm --no-deps app composer install --no-interaction --prefer-dist --no-progress
  fi
  exit 0
fi

mkdir -p app
if [ -n "$(ls -A app 2>/dev/null)" ]; then
  echo "app/ has contents but no artisan file. Refusing to overwrite." >&2
  exit 1
fi

echo "Installing Laravel starter $starter from $repository ($revision)"
docker compose build app
docker compose run --rm --no-deps app git clone --depth 1 --branch "$revision" "https://github.com/$repository.git" /var/www/html
docker compose run --rm --no-deps app rm -rf /var/www/html/.git
# Fresh official starter repositories have no composer.lock. Drop Sail from
# composer.json before dependency resolution so it is never downloaded or locked.
if grep -Eq '"laravel/sail"[[:space:]]*:' app/composer.json; then
  echo "Excluding Laravel Sail before Composer installs dependencies."
  docker compose run --rm --no-deps app composer remove laravel/sail --dev --no-update --no-scripts --no-plugins --no-interaction --no-progress
fi
docker compose run --rm --no-deps app composer install --no-interaction --prefer-dist --no-progress
printf '%s\n' "$starter" > app/.letsgo-starter
echo "Laravel scaffold ready."
