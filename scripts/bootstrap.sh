#!/usr/bin/env sh
# Select and install an official Laravel starter; this script never switches an
# initialized application's frontend and never overwrites existing code.
set -eu

[ -f .env ] || cp .env.example .env
command -v docker >/dev/null 2>&1 || { echo "Docker is required." >&2; exit 1; }
docker compose version >/dev/null 2>&1 || { echo "Docker Compose v2 is required." >&2; exit 1; }

starter="${1:-}"
if [ -z "$starter" ]; then
  if [ -t 0 ]; then
    printf '\nChoose your Laravel starter:\n' >&2
    printf '  1) Laravel only (no frontend framework or authentication starter) [default]\n' >&2
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
    echo "Non-interactive setup: using plain Laravel. Pass STARTER=svelte|vue|react|livewire to override."
  fi
fi

case "$starter" in
  laravel|blank|none) starter=laravel; repository=laravel/laravel; revision=13.x ;;
  svelte) repository=laravel/svelte-starter-kit; revision=main ;;
  vue) repository=laravel/vue-starter-kit; revision=main ;;
  react) repository=laravel/react-starter-kit; revision=main ;;
  livewire) repository=laravel/livewire-starter-kit; revision=main ;;
  *) echo "Unknown starter: $starter (valid: laravel, svelte, vue, react, livewire)" >&2; exit 2 ;;
esac

if [ -e app/artisan ]; then
  echo "Existing Laravel app found. Preserving application and current starter."
  if [ ! -f app/vendor/autoload.php ]; then
    docker compose run --rm --no-deps --user "$(id -u):$(id -g)" -e HOME=/tmp -e COMPOSER_HOME=/tmp/composer app composer install --no-interaction --prefer-dist --no-progress
  fi
  exit 0
fi

mkdir -p app
if [ -n "$(ls -A app 2>/dev/null)" ]; then
  echo "app/ is not empty but contains no Laravel artisan file. Refusing to overwrite." >&2
  exit 1
fi

echo "Installing Laravel starter: $starter ($repository @ $revision)"
docker compose build app
docker compose run --rm --no-deps --user "$(id -u):$(id -g)" \
  -e HOME=/tmp -e COMPOSER_HOME=/tmp/composer \
  -e STARTER_REPO="$repository" -e STARTER_REF="$revision" app sh -eu -c '
    git clone --depth 1 --branch "$STARTER_REF" "https://github.com/$STARTER_REPO.git" /var/www/html
    cd /var/www/html
    rm -rf .git
    composer install --no-interaction --prefer-dist --no-progress
    if composer show --locked laravel/sail >/dev/null 2>&1; then
      composer remove laravel/sail --dev --no-interaction --no-progress
    fi
  '
printf '%s\n' "$starter" > app/.letsgo-starter
echo "Laravel scaffold created. Source and lockfiles are ready for version control."
