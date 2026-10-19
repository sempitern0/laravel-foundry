# Laravel Let's Go

Self-hosted Laravel 13 + Svelte 5 + Inertia 3 development template. **No Sail, Herd, paid local databases or platform services required.**

## Requirements
Docker Engine with Compose v2, Git, Make and a POSIX shell (WSL2 recommended on Windows). PHP, Composer, Node and PostgreSQL run in containers.

## Start in three commands

```sh
git clone https://github.com/sempitern0/laravel-letsgo.git my-app
cd my-app
make setup
```

Open **http://localhost:8080**. Mailpit is at **http://localhost:8025**. Vite HMR uses localhost port 5173. Setup downloads the official Laravel Svelte starter into `app/`, removes its Sail dev dependency, generates an application key, configures local PostgreSQL, installs npm packages and runs migrations. First run needs internet access.

**Important:** `app/` is excluded by this *infrastructure template's* .gitignore. To turn a bootstrapped instance into your actual application repository, remove `app/` from .gitignore and commit the generated Laravel source, `composer.lock` and `package-lock.json`, but never `app/.env`. Otherwise production CI will not be reproducible.

## Daily commands
```sh
make up
make down
make logs
make artisan CMD="route:list"
make composer CMD="require vendor/package"
make npm CMD="run check"
make migrate
make test
make backup
make worker
make scheduler
make redis
```

`make destroy` irreversibly deletes Docker volumes with explicit confirmation. `make backup` is a **local plain SQL dump**, not an offsite backup or tested restore strategy.

## Architecture
Local: Nginx → PHP-FPM Laravel, Node Vite, PostgreSQL, Mailpit. Redis, queue worker and scheduler are opt-in. No database ports are exposed; connect from inside Docker with `docker compose exec postgres psql -U letsgo`. In production: Caddy (automated TLS) → Nginx → PHP-FPM, PostgreSQL, queue worker and scheduler, persistent storage.

For production set `APP_IMAGE`, `WEB_IMAGE`, `APP_DOMAIN`, `DB_DATABASE`, `DB_USERNAME`, then supply non-committed `app.production.env` and `db.production.env`. Use:
```sh
docker compose -f compose.production.yaml pull
docker compose -f compose.production.yaml up -d
docker compose -f compose.production.yaml exec -T app php artisan migrate --force
```

Production **requires published images containing the same built Laravel release and web assets**, plus real secrets, TLS DNS records, external backups and deployment validation. The template provides a production topology, not a fully configured release pipeline.

### Known limits and operational rules
- Local HTTP is intentional; production HTTPS is handled by Caddy. Do not expose a development environment to the Internet.
- The generated Laravel app can use database-backed sessions, cache and queues out of the box. Redis is opt-in.
- Separate staging/production Compose projects, databases, secrets and domains. Never reuse production data in staging.
- Reserve migrations with incompatible schema changes for explicitly coordinated releases; image rollback does not undo database changes.
- Restrict SSH access, protect credentials, configure offsite backups and verify restores before accepting customer data.
- The public `/healthz` URL checks only Nginx; use application-level checks before advancing releases.
- First setup is for empty `app/`; it never overwrites an existing Laravel project.
