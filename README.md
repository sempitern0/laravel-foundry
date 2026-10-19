# Laravel Let's Go

Docker-first, self-hostable Laravel 13 + Svelte 5 + Inertia 3 template. **No Laravel Sail, Herd, subscription or paid local database.**

## Prerequisites

Docker Engine, Docker Compose v2, Git, Make, a POSIX shell. On Windows, use WSL2 for the development workflow. No host PHP, Composer, PostgreSQL or Node installation required.

## First run

```sh
git clone https://github.com/sempitern0/laravel-letsgo.git my-app
cd my-app
make setup
```

Open http://localhost:8080; Mailpit is http://localhost:8025. Vite HMR uses 5173.

The bootstrap downloads the official Laravel/Svelte starter in `app/`, removes its Sail development dependency, configures PostgreSQL and Mailpit, generates the application key, migrates, and starts Vite. This requires Internet on the first run. It refuses to overwrite a nonempty application directory.

**IMPORTANT FOR A REAL PROJECT:** this infrastructure repository ignores `app/` by default. After the first bootstrap, remove the `app/` entry from the root `.gitignore`, and version your Laravel app, `composer.lock` and `package-lock.json`, while keeping `app/.env`, `vendor/`, `node_modules/` and secrets ignored. Otherwise CI cannot compile and release your application. Consider generating a fresh project repo rather than pushing your application code to this template repository.

## Daily operations

```sh
make help
make up                   # PHP, Nginx, PostgreSQL, Mailpit and Vite
make down                 # Keep database volumes
make logs
make artisan CMD="route:list"
make composer CMD="require vendor/package"
make npm CMD="run check"
make migrate
make test
make lint
make backup               # Local SQL dump only
make redis                # Opt-in Redis, not necessary by default
make worker               # Opt-in queue worker
make scheduler            # Opt-in schedule worker
make destroy              # Destructive, requires typing DELETE
```

Containers run locally with HTTP bound only to loopback. PostgreSQL and Redis do not publish a TCP port to the host. Access PostgreSQL through `docker compose exec postgres psql -U letsgo`.

## Production and staging

The `compose.production.yaml` manifest defines **Caddy → Nginx → PHP-FPM**, PostgreSQL, queue worker, scheduler, isolated internal network, persistent storage and automated public HTTPS. Deploy staging and production as *separate Compose projects* using independent volumes, database credentials, domains, and environment files. Never share production data with staging.

After the app source and both lock files have been committed, a tag `v*` triggers the release workflow. It compiles Laravel/Svelte, builds immutable PHP and Nginx release images and pushes them to GHCR, using your repo's GitHub token. If packages are private, authenticate on the server before pulling.

On each target VPS:
```sh
cp app.production.env.example app.production.env
cp db.production.env.example db.production.env
# Change ALL passwords, APP_KEY, APP_URL and related values.
# The app DB_PASSWORD must equal db POSTGRES_PASSWORD.
# Point APP_DOMAIN DNS to this server and allow TCP 80/443.
export PROJECT_NAME=myapp-prod
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

For staging use a different project name/domain/secrets and optionally different image tags. The release workflow **builds and publishes** images, but deliberately does **not SSH to your VPS** or automatically migrate your customer database; promotion is an explicit operator action.

### Production requirements

- Install real secrets outside Git and generate APP_KEY with `php artisan key:generate --show` in a controlled environment.
- Ensure the server's DNS resolves, TLS can be issued and that the network firewall only exposes 80/443 and authorized management access.
- Configure encrypted **offsite** backups of database and storage, retention and tested restoration. `make backup` is local-only and insufficient for production.
- Use a transactional SMTP relay when required. Do not ship staging/demo email configuration to customer systems.
- Health checks, smoke tests and reversible application changes should precede promotion. Image rollback cannot roll back incompatible database migrations.
- Redis is intentionally optional for development; production defaults to database-backed cache and queue to reduce memory and services.
- Persistent storage is shared by web tasks through the PHP volume; for downloadable files requiring direct Nginx delivery, configure a dedicated secure object-storage or public-files mounting strategy.
