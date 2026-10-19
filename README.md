# Laravel Let's Go

**Frontend-neutral Laravel template with native Windows PowerShell and Linux/macOS shell support.** No Laravel Sail, Herd or paid local database. Docker Compose runs PHP-FPM, Nginx, PostgreSQL, Mailpit and Node; Redis, queue workers and scheduler are optional.

## Requirements

- Docker Desktop with Linux containers + Compose v2 on Windows, or Docker Engine + Compose v2 on Linux.
- Git and GNU Make if you want `make` shortcuts. **PowerShell users can also run the scripts directly without Make.**
- No host PHP, Composer, Node or PostgreSQL. The development PHP image includes Node/npm because the official Laravel starter's Composer hooks can invoke npm during `artisan install:features`. Production PHP images do not include Node; Vite remains a separate dev service.
- On Linux set `DEV_UID` and `DEV_GID` in root `.env` to match your user when necessary. Windows uses Docker Desktop's bind mount handling.

## Initialize a Laravel project

Use `make setup` to choose the starter interactively, or specify it explicitly:

| Frontend choice | GNU Make (all platforms) | Native PowerShell (Windows) |
| --- | --- | --- |
| Laravel only (default) | `make setup STARTER=laravel` | `.\scripts\setup.ps1 -Starter laravel` |
| Svelte + Inertia | `make setup STARTER=svelte` | `.\scripts\setup.ps1 -Starter svelte` |
| Vue + Inertia | `make setup STARTER=vue` | `.\scripts\setup.ps1 -Starter vue` |
| React + Inertia | `make setup STARTER=react` | `.\scripts\setup.ps1 -Starter react` |
| Livewire | `make setup STARTER=livewire` | `.\scripts\setup.ps1 -Starter livewire` |

For example, from **Windows PowerShell**:

```powershell
make setup STARTER=svelte
# Or without GNU Make:
.\scripts\setup.ps1 -Starter svelte
```

On **Linux/macOS/WSL**:

```sh
make setup STARTER=svelte
# Or directly:
sh scripts/setup.sh svelte
```

Without a STARTER option, an interactive selection menu appears. In non-interactive execution, plain Laravel is used by default. Setup is designed to be repeatable: it preserves an existing `app/artisan` and does not silently change frontend. When creating a new application, use a fresh template checkout rather than deleting code.

**Important:** the initial setup downloads the chosen official Laravel starter into `app/`, **removes Laravel Sail from composer.json before the first `composer install`**, then installs Composer and npm dependencies in Docker, sets up PostgreSQL and Mailpit, generates a missing APP_KEY and runs Laravel migrations. Internet access is needed for the initial downloads.

### Recovering from a partially completed setup

If Composer stopped with `artisan install:features` / `npm: not found`, **do not delete `app/` or reset database volumes**. Update this template branch and rerun `make setup STARTER=svelte` (or the original starter). Setup now rebuilds the PHP dev image and detects incomplete bootstrap via `app/.letsgo-starter`; it reruns Composer and explicitly replays the feature-install hook when needed, even if `vendor/autoload.php` already exists.

### Laravel Sail policy

The official Svelte, React, Vue and Livewire starters currently declare `laravel/sail` as a dev dependency. This template deliberately uses its own Compose files, so it strips Sail **before dependency resolution** with `composer remove laravel/sail --dev --no-update --no-scripts --no-plugins`. The generated `composer.lock` therefore does not include Sail. If an existing initialized application still declares Sail, rerunning `make setup` removes it and regenerates the lockfile through Composer. Both PowerShell and POSIX shell bootstrap scripts enforce this rule. CI/release checks reject a committed application containing Sail.

This is a **setup-time cleanup and CI guard, not a Composer `post-install-cmd` hook**: Composer hooks that modify their own dependency graph can cause recursive or inconsistent installs. If you add Sail manually later, CI will flag it and `make setup` can reconcile your application.

## Daily development (PowerShell and Unix)

```sh
make up
make down
make logs
make ps
make artisan CMD="route:list"
make composer CMD="require vendor/package"
make npm CMD="run build"
make migrate
make test
make worker
make scheduler
make redis
make backup
make destroy
```

For Windows without GNU Make, use `docker compose up -d`, `docker compose exec app php artisan ...`, and the PowerShell scripts in `scripts/`. For example:

```powershell
.\scripts\backup.ps1
.\scripts\destroy.ps1
```

Local site: http://localhost:8080; Mailpit: http://localhost:8025. Node/Vite is exposed on localhost:5173. PostgreSQL and Redis do not expose host TCP ports.

### Operating-system parity

- GNU Make checks `OS=Windows_NT` and invokes **powershell.exe**, not `sh`, on native Windows.
- Bash/WSL/Linux/macOS invoke `scripts/*.sh` through the host POSIX shell.
- PowerShell scripts use `docker compose` and .NET filesystem APIs; **no Unix shell is required on the host**.
- Linux shells inside Docker containers are normal and independent of the host PowerShell.
- The PostgreSQL backup uses `pg_dump -Fc` inside the container followed by `docker compose cp`, avoiding PowerShell 5.1 redirection corrupting binary or text encoding.
- Do not execute `./scripts/*.sh` directly in Windows PowerShell. Use the `.ps1` versions.

### Source versioning

Commit your initialized `app/` directory, `composer.lock` and `package-lock.json` into the new product's repository. The root `.gitignore` protects `app/.env`, dependencies and generated assets. For each new product, initialize from an independent copy of this template.

## Staging and production

`compose.production.yaml` provides a separate base topology with **Caddy TLS → Nginx → PHP-FPM**, PostgreSQL, scheduler, queue worker and persistent storage. Build releases from the selected starter: the GitHub Actions `v*` workflow compiles `npm run build` and publishes Docker images to GHCR when app source and lockfiles are committed. Deployment is an explicit operator promotion; **no staging/prod deployment has been verified yet**.

See `app.production.env.example` and `db.production.env.example`, configure independent secrets/domains/projects for staging and production, and use:

```sh
export PROJECT_NAME=myapp-prod APP_DOMAIN=example.com DB_DATABASE=letsgo DB_USERNAME=letsgo
export APP_IMAGE=ghcr.io/OWNER/REPO-php:v1.0.0 WEB_IMAGE=ghcr.io/OWNER/REPO-web:v1.0.0
docker compose -f compose.production.yaml config -q
docker compose -f compose.production.yaml pull
docker compose -f compose.production.yaml up -d
docker compose -f compose.production.yaml exec -T app php artisan migrate --force
```

In PowerShell, set environment variables using `$env:PROJECT_NAME='myapp-prod'`, `$env:APP_DOMAIN='example.com'`, etc., rather than Unix `export`. Production requires correctly managed secrets, firewall, offsite encrypted backups **and restore tests**, application health checks and monitoring.

`make backup` produces a local dump only; it is not a production backup policy. `make destroy` deletes volumes after the explicit confirmation `DELETE`.
