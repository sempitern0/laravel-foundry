# Laravel Let's Go

A **frontend-neutral Laravel development and self-hosting template**: PHP-FPM, Nginx, PostgreSQL, optional Redis, Docker Compose, local email, and production Caddy HTTPS. **No Sail, Herd, required SaaS or paid local database.**

The infrastructure does not dictate which frontend or authentication approach your project uses. Choose the Laravel starter *when you create an application*, and version the resulting source. This is a Laravel template, **not** a template that pretends SvelteKit or Astro run inside Laravel.

## Requirements

Docker Engine + Compose v2, Git, Make and a POSIX shell. For Windows use WSL2 and keep the checkout on the WSL filesystem for acceptable bind-mount performance. No PHP, Composer, Node or PostgreSQL installation on your host. For Linux/WSL set `DEV_UID` and `DEV_GID` in the root `.env` to match `id -u` and `id -g` if these differ from 1000.

## First run: choose your Laravel starter

```sh
git clone https://github.com/sempitern0/laravel-letsgo.git my-app
cd my-app
make setup
```

`make setup` displays a choice on an interactive terminal. Press Enter for **plain Laravel**, with no Inertia or authentication starter. To use the template unattended or pick explicitly:

| Choice | Command | Included by the selected official starter |
| --- | --- | --- |
| Plain Laravel (default) | `make setup STARTER=laravel` | Standard Laravel app with Blade/Vite; no auth starter |
| Svelte | `make setup STARTER=svelte` | Svelte + Inertia and official authentication flows |
| Vue | `make setup STARTER=vue` | Vue + Inertia and official authentication flows |
| React | `make setup STARTER=react` | React + Inertia and official authentication flows |
| Livewire | `make setup STARTER=livewire` | Laravel Livewire starter and official authentication flows |

The implementation clones the appropriate **official Laravel GitHub starter** (Laravel 13.x for plain Laravel; official starter-kit main branches for the rest), drops its nested Git history, runs Composer inside the PHP container, removes Sail if included, configures PostgreSQL + Mailpit, generates an application key **only if missing**, migrates, installs npm dependencies and launches Vite. No local PHP/Node installs.

- Site: http://localhost:8080
- Email testing: http://localhost:8025
- Vite: localhost:5173
- Database: `postgres` hostname inside Compose, not publicly exposed

For non-interactive environments `make setup` defaults to plain Laravel. `make setup` is idempotent: an existing `app/artisan` is preserved; selecting another starter later does **not** replace your code. To create an app with another frontend, start a separate checkout, do **not** delete a project with user data.

**Your app code is tracked by default.** Commit generated `app/`, `app/composer.lock` and `app/package-lock.json` to the new project's repository. Root and Laravel `.gitignore` rules exclude `app/.env`, PHP vendor deps, Node deps and generated assets. For a new product, use GitHub's template/fork workflow or set the new Git remote after cloning.

## Daily commands

```sh
make help
make up                    # App, DB, Mailpit, Vite
make down                  # Keep persistent volumes
make logs
make artisan CMD="route:list"
make composer CMD="require vendor/package"
make npm CMD="run build"
make migrate
make test
make backup                # Local pg_dump (NOT an offsite backup)
make worker                # Opt-in
make scheduler             # Opt-in
make redis                 # Opt-in
make destroy               # Explicit DELETE confirmation
```

`make lint` invokes the selected app's Composer `lint:check` script, where supported. For plain Laravel, use your project's own lint/test commands as appropriate. Redis is optional: default cache, sessions and queue use PostgreSQL-backed Laravel drivers.

## Staging and production

`compose.production.yaml` describes Caddy (HTTPS) → Nginx → PHP-FPM, PostgreSQL, queue worker, scheduler and persistent storage. Use **independent** Compose project names, databases, credentials and hostnames for staging and production. The build/release workflow compiles the selected starter's assets via its `npm run build`, publishes versioned PHP and Nginx images to GHCR on `v*` tags **after the application code and lockfiles are committed**. Releases are built but **not automatically promoted to a VPS**.

Example deployment on each server:

```sh
cp app.production.env.example app.production.env
cp db.production.env.example db.production.env
# Edit these files: APP_KEY, database secrets, APP_URL, etc.
# APP DB_PASSWORD and PostgreSQL POSTGRES_PASSWORD must match.
export PROJECT_NAME=example-prod
export APP_DOMAIN=example.com
export DB_DATABASE=letsgo
export DB_USERNAME=letsgo
export APP_IMAGE=ghcr.io/OWNER/REPO-php:v1.0.0
export WEB_IMAGE=ghcr.io/OWNER/REPO-web:v1.0.0
docker compose -f compose.production.yaml config -q
docker compose -f compose.production.yaml pull
docker compose -f compose.production.yaml up -d
docker compose -f compose.production.yaml exec -T app php artisan migrate --force
```

For staging supply different credentials/domain/PROJECT_NAME. Configure A/AAAA records and inbound 80/443 before certificate issuance, allow only authorized management access, and confirm all persistent volumes. Rollbacks of images do not roll back DB schema.

## Operational boundaries

- Local defaults intentionally use HTTP on `127.0.0.1`; never expose development containers directly to the internet.
- Production readiness requires **offsite encrypted backups**, tested restores, health checks, monitoring, a configured mail relay where needed and correctly rotated secrets. `make backup` only exports a local SQL dump.
- Never place customer data in staging without appropriate anonymization.
- Default production queue/cache uses Laravel database drivers rather than obligating Redis.
- PHP/Svelte/Vue/React/Livewire apps all require compatible PHP dependencies; build and test your selected starter before deploying.
- Server-rendered separate apps such as **SvelteKit and Astro should have their own templates/Compose stacks**, with their own Node servers or static builds. They are not starters inside Laravel.
