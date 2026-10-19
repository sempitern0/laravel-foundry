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

## Interactive infrastructure configuration

After selecting a Laravel starter, one PHP wizard (running **inside Docker**, so both PowerShell and Unix use identical questions) asks for the application/container project name, PostgreSQL/MariaDB/SQLite, queue (sync/database/Redis), mail (Mailpit/log/custom SMTP), optional Pgweb/Adminer, and custom `.test` HTTPS hostname. All these options are written to the ignored root `.env` as Compose profiles and propagated to `app/.env`.

- **Database:** PostgreSQL is the default; MariaDB and SQLite are optional. Existing database volumes are not destroyed automatically when changing engines; migrate or back up data before changing engines.
- **Queues:** sync requires no worker; database and Redis enable the worker automatically. Redis starts only when chosen.
- **Mail:** Mailpit for development, log or custom SMTP. Mailpit UI is exposed on http://localhost:8025 when selected.
- **DB GUI:** Pgweb for PostgreSQL or Adminer for MariaDB (default port http://localhost:8081). SQLite deliberately has no remote DB GUI.
- **Caddy HTTPS:** opt in, default `https://yourname.test:8443`, using `tls internal`. The wizard disables Vite's live server for HTTPS and builds static assets to avoid mixed content. On ordinary HTTP, Vite HMR remains enabled.

### Local HTTPS and custom domain

When enabling HTTPS, the wizard prints the hostname. Add it to your OS `hosts` file, for example:

```text
127.0.0.1 myapp.test
```

Windows: edit `C:\\Windows\\System32\\drivers\\etc\\hosts` as Administrator. Linux/macOS: edit `/etc/hosts` with appropriate privileges. Start with `make up-detached` or run `make setup`, then visit `https://myapp.test:8443`. The Caddy local CA certificate is available through `make https-cert`. **Inspect it before importing into your OS/browser trusted-root store.** On Windows, install the inspected root CA into Current User → Trusted Root Certification Authorities. Restart your browser. Use this CA only for local development. The port is 8443 to avoid requiring administrator access or conflicting with other software on port 443.

`http://localhost:8080/healthz` should return `ok`. If Laravel routes fail, run `docker compose logs web app` and `docker compose exec app php artisan route:list` before changing domains.

### Recovering from a partially completed setup

If Composer stopped with `artisan install:features` / `npm: not found`, **do not delete `app/` or reset database volumes**. Update this template branch and rerun `make setup STARTER=svelte` (or the original starter). Setup now rebuilds the PHP dev image and detects incomplete bootstrap via `app/.letsgo-starter`; it reruns Composer and explicitly replays the feature-install hook when needed, even if `vendor/autoload.php` already exists.

### Laravel Sail policy

The official Svelte, React, Vue and Livewire starters currently declare `laravel/sail` as a dev dependency. This template deliberately uses its own Compose files, so it strips Sail **before dependency resolution** with `composer remove laravel/sail --dev --no-update --no-scripts --no-plugins`. The generated `composer.lock` therefore does not include Sail. If an existing initialized application still declares Sail, rerunning `make setup` removes it and regenerates the lockfile through Composer. Both PowerShell and POSIX shell bootstrap scripts enforce this rule. CI/release checks reject a committed application containing Sail.

This is a **setup-time cleanup and CI guard, not a Composer `post-install-cmd` hook**: Composer hooks that modify their own dependency graph can cause recursive or inconsistent installs. If you add Sail manually later, CI will flag it and `make setup` can reconcile your application.

## npm installation performance (especially on Windows)

The local app source is still mounted from `./app`, but **`node_modules` now lives in a named Docker volume** shared between the development PHP container (which runs Laravel's Composer hooks) and the Node/Vite container. The npm download cache is persisted in another volume; Composer's download cache is also persisted. This avoids writing tens of thousands of npm files to a slow NTFS bind mount.

The Node and PHP development containers both use **Node.js 22 on Debian/glibc**. This matters for platform-specific binaries (Vite/Rollup, Tailwind) that could break when sharing `node_modules` between Alpine/musl and Debian/glibc.

The `setup` command detects whether Composer has already installed an intact dependency tree and skips a redundant second `npm install`. If it has not, it installs with `--prefer-offline --no-audit --no-fund`. A subsequent `make up` reuses both the images and named volumes; `make rebuild` is available for Dockerfile changes.

**Changing npm packages:** Run `make npm CMD="install"` to install/update dependencies, or `make npm CMD="ci"` to reinstall exactly from the committed lockfile. No host npm required.

**Existing checkout:** Docker will start using fresh named volumes after you update this branch; a previous `app/node_modules` folder on Windows may remain on disk but is shadowed inside containers. Once the new setup works, that obsolete host folder can be removed manually to reclaim space. Do not delete `app/`, `app/.env`, or your database volumes.

**Windows performance tip:** For further acceleration, put a large repository under the WSL2 Linux filesystem rather than `C:\\Users\\...` and open it with your editor's WSL integration. Moving the project is optional.

## Daily development (PowerShell and Unix)

```sh
make up                 # foreground logs
make up-detached        # background
make down               # stop stack without deleting volumes
make down-detached      # alias for down (Compose down is nonblocking)
make rebuild              # Only after changing the Dockerfile/images
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

### Template isolation and existing installations

The template **does not track `app/`**. Its root `.gitignore` excludes the entire generated folder. Any generated application is private to your local checkout. When `make setup` finds a nonempty `app/`, it asks whether to keep its files (default) or replace them. Replacing stops app containers and **moves** the directory to `app-backups/app-YYYYMMDD-HHMMSS` before generating a new app. It does not delete Docker volumes or reset PostgreSQL. In noninteractive runs, setup refuses to overwrite anything.

The backups under `app-backups/` are local archives, **not** offsite backups; do not delete them until verified. Database migrations can change existing database schemas; replacing source code does not reset the database.

For real product repositories, deliberately remove `/app/` from the root ignore file and commit the app and lockfiles (excluding the app's secrets and dependencies). This repository remains only an infrastructure template. The development Dockerfile context excludes `app/`; release builds use a separate production Dockerfile context rule to include source only in your application repository.

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
