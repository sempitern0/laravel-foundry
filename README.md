<div align="center">

<img src="assets/foundry-mark.svg" alt="Laravel Foundry logo" width="108" height="108" />

# Laravel Foundry

**A Docker-first, frontend-neutral Laravel development template.**

[![CI](https://github.com/sempitern0/laravel-letsgo/actions/workflows/ci.yml/badge.svg)](https://github.com/sempitern0/laravel-letsgo/actions/workflows/ci.yml)
[![MIT License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Docker Compose](https://img.shields.io/badge/orchestration-Docker%20Compose-2496ED?logo=docker&logoColor=white)](compose.yaml)
[![PowerShell + POSIX](https://img.shields.io/badge/platform-Windows%20%7C%20Linux%20%7C%20macOS-555)](#requirements)
[![Status: Preview](https://img.shields.io/badge/status-preview-yellow)](https://github.com/sempitern0/laravel-letsgo/pull/1)

**Bring your own Laravel starter. No Sail, Herd, required SaaS, or paid local database.**

[Quick start](#quick-start) · [Architecture](#architecture) · [Commands](#daily-commands) · [HTTPS](#local-https-with-caddy) · [Troubleshooting](#troubleshooting)

</div>

> [!IMPORTANT]
> This is an **infrastructure template, not a Laravel application repository**. The generated `app/` directory is deliberately ignored by Git. Release/staging configurations are **reference starting points**, not a verified turnkey production deployment. Never commit secrets.

## At a glance

| Area | Choice |
| --- | --- |
| Backend | Laravel, PHP 8.4-FPM, Nginx |
| Starter | Plain Laravel · Svelte + Inertia · Vue + Inertia · React + Inertia · Livewire |
| Database | PostgreSQL · MariaDB · SQLite |
| Queues | Sync · Database · Redis |
| Email | Mailpit · Log · Custom SMTP |
| Database UI | Pgweb (PostgreSQL) · Adminer · None |
| HTTPS | Caddy local CA, custom `.test` hostname |
| Development tools | Disposable Composer container, separate PHP-capable Node/Vite container |
| Host support | Native PowerShell, Linux, macOS, WSL2 |
| Delivery | Docker Compose; optional image-release workflow via GHCR |

## AI coding agents

[**AGENTS.md**](AGENTS.md) is the repository's framework-agnostic development guide for AI coding assistants. It covers initial repository discovery, Laravel/PHP and PSR conventions, Eloquent models and migrations, authorization, security, queue jobs, Docker tooling, testing, and frontend rules for **Blade, Livewire, Inertia with Svelte/Vue/React** and other installed tools. It avoids imposing a frontend or unnecessary architecture.

The guide is stored at the **template root**, so an assistant working on Laravel Foundry follows its infrastructure standards. If you create a separate *application repository* from `app/`, include an adapted copy of `AGENTS.md` there so the project's own agents retain the relevant Laravel standards. Review its Docker command assumptions and any project-specific rules before copying.

## Quick start

Requirements: Docker Desktop with Linux containers (Windows) or Docker Engine (Linux), **Compose v2**, Git, and GNU Make for the Makefile shortcuts. PHP, Node, Composer, npm and database engines run inside containers.

**Windows prerequisites:** `make setup` cannot install GNU Make because it is itself invoked by Make. Before cloning/running Make on a new machine, use the native PowerShell helper:

```powershell
.\scripts\prerequisites.ps1
.\scripts\prerequisites.ps1 -InstallMissing
```

The first command only audits prerequisites; the second **asks for consent** before installing missing Git/Docker Desktop with WinGet and GNU Make through an available supported package manager (Chocolatey, Scoop, or a verified WinGet package). If no supported Make package is discoverable, the helper provides a manual installation path; it does **not** silently install arbitrary package managers. Docker Desktop/WSL2 may need an administrator, a reboot and first-run initialization. Start Docker Desktop before running setup.

**No Make required:** after Docker Desktop is working, you may use `.\scripts\setup.ps1 -Starter svelte` directly from PowerShell. The project does not silently alter the host system during `make setup`.

```powershell
git clone https://github.com/sempitern0/laravel-letsgo.git my-laravel-app
cd my-laravel-app
make setup STARTER=svelte
```

Or use `make setup` to choose a starter interactively. The setup wizard asks for a Compose project name, application name, database, queue, email, database UI, and optional HTTPS hostname. For a plain Laravel application use `STARTER=laravel`.

Windows without Make:

```powershell
.\scripts\setup.ps1 -Starter svelte
```

Linux/macOS/WSL:

```sh
sh scripts/setup.sh svelte
```

**Existing `app/`:** setup asks whether to keep the current installation or archive and replace it. It does not silently delete code or database volumes. The first run downloads official starter code and dependencies, removes Sail, sets up the chosen database, migrates and prepares assets. First setup may take time; daily startup should not repeat it.

## Architecture

```text
                        Browser
                   HTTP or local HTTPS
                           |
                     Caddy (optional)
                           |
                         Nginx
                           |
                       Laravel
                       PHP-FPM
                           |
              +------------+-------------+
              |                          |
      PostgreSQL/MariaDB/SQLite     Queues / Redis
              |
       Pgweb / Adminer (optional)

    On-demand tools: Composer + PHP + Node/npm
    Frontend:        Node + PHP CLI (Wayfinder) + Vite
    Test email:      Mailpit
```

The PHP-FPM runtime does not carry Composer or npm. The disposable Composer toolbox contains Node/npm because official Laravel starter hooks may invoke npm. The Node/Vite container contains PHP CLI because Wayfinder can invoke `php artisan` while building frontend assets. Containers share project files and selected Docker volumes; networks are separation of responsibilities, **not a full sandbox for untrusted dependencies**.

## Daily commands

| Command | Purpose |
| --- | --- |
| `make up` | **Fast** detached creation/start; does not wait for full health |
| `make up-detached` | Compatibility alias for `make up` |
| `make up-wait` | Start and wait for declared container healthchecks |
| `make up-logs` | Run Compose in foreground |
| `make stop` / `make start` | Quick daily pause/resume without recreating containers |
| `make down` | Stop and remove containers/networks; **keep volumes** |
| `make restart` | Stop/start existing containers |
| `make rebuild` | Explicit image rebuild after Dockerfile changes |
| `make ps` / `make logs` | Inspect containers and logs |
| `make artisan CMD="route:list"` | Laravel Artisan |
| `make composer CMD="require vendor/package"` | Composer in disposable toolbox |
| `make npm CMD="run build"` | Node/Vite tool container |
| `make migrate` / `make test` / `make lint` | Laravel operations |
| `make env-sync` | Add missing root `.env` keys without overwriting values |
| `make backup` | Export **local** database dump (not offsite backup) |
| `make https-setup` | Local hostname/certificate guidance and Windows helper |
| `make reset-project` | **Destructive** full reset of generated app and Compose volumes |
| `make build` / `make rebuild` | Build images / rebuild and recreate selected running services |
| `make config` | Validate Compose configuration |

### Fast startup versus readiness

`make up` is the default quick path: it uses detached Compose startup. Nginx and Caddy depend on their upstream containers **starting**, not each passing a serial 20-second readiness gate. Healthchecks remain enabled and probe rapidly during startup. If you need to know that the stack is ready rather than merely started, run `make up-wait`.

After the first setup, prefer `make stop` and `make start` for short daily development sessions; these retain Docker containers. **Do not use `make reset-project` to restart an app.** Initial cold starts, database recovery, image pulls and Windows filesystem performance still take variable time. Fast startup is **not a promise of a particular latency**.

## Local HTTPS with Caddy

Choose local HTTPS in the setup wizard. For a custom name like `omapop.test`, add `127.0.0.1 omapop.test` to your hosts file (Windows: `C:\Windows\System32\drivers\etc\hosts`; Linux/macOS: `/etc/hosts`). Port **443** is the new-installation default, so the URL is:

**https://omapop.test**

On Windows use `make https-setup` to guide hostname setup and offer to trust the local Caddy CA after confirmation. You must trust the CA in your OS/browser to avoid certificate warnings. Firefox may use its own certificate settings. Caddy's `tls internal` certificates are **development-only**, not public ACME certificates. If port 443 is occupied, choose another `HTTPS_PORT` (e.g. 8443) and append it to the URL. The wizard configures `app/.env` `APP_URL` accordingly.

Existing installations keep their current `HTTPS_PORT` until you change it. For a pre-existing installation, change the root `.env` and Laravel `APP_URL`, recreate Caddy and clear Laravel's cached configuration.

## Environment and project lifecycle

- **`.env.example`:** safe, generic defaults committed to the template.
- **Root `.env`:** generated project-specific Compose/wizard settings; ignored by Git.
- **`app/.env`:** generated Laravel environment; ignored with all of `app/`.
- **`make env-sync`:** adds missing keys from the latest template, **never overwrites** existing values, secrets, or custom settings.
- **`app.production.env.example` / `db.production.env.example`:** separate production references; do not copy development credentials into production.

To replace everything generated with a new app:

```powershell
make reset-project
make setup STARTER=livewire
```

Reset requires typing `RESET <PROJECT_NAME>`. It removes the generated `app/`, root `.env`, and **all volumes of that Compose project** (including database data and Caddy CA). It **preserves** `backups/`, `app-backups/`, the template files, and does not revoke system certificate trust or modify hosts. **Back up data before resetting.**

## Staging, production, and release boundaries

The repository provides a `compose.production.yaml` reference with Caddy, Nginx, PHP-FPM, PostgreSQL, worker and scheduler, and a tag-triggered GitHub Actions release workflow that publishes versioned images to GHCR **only once the generated application source and lockfiles have been committed to an actual application repository**.

> [!WARNING]
> The template intentionally ignores `app/`. Therefore its release workflow **cannot** publish a real application image directly from this pristine template. For a product, create a separate repo that tracks Laravel source, `composer.lock` and `package-lock.json`, while ignoring `vendor/`, `node_modules/` and secrets. Staging and production require separate secrets, database volumes, DNS, external encrypted backups, restore tests, observability and tested deployments. The provided production Compose currently uses PostgreSQL; it is not automatically rewritten to match local MariaDB/SQLite choices.

The local `make backup` command is **not** a disaster-recovery plan. Store encrypted database and file backups outside the VPS/host and routinely verify restoration.

## Troubleshooting

| Symptom | Check |
| --- | --- |
| `http://localhost:8080` fails | `docker compose ps`, `docker compose logs web app`, then `http://localhost:8080/healthz` |
| `https://*.test` fails | Check `hosts`, `HTTPS_PORT`, `COMPOSE_PROFILES`, port ownership and `docker compose logs caddy-local` |
| Browser says HTTPS is not trusted | Run `make https-setup`, review and explicitly trust **your own** Caddy CA |
| Wayfinder build says `php: not found` | Rebuild Node frontend image: `docker compose build node` |
| `composer install` invokes npm | Use the Composer toolbox, which includes Node/npm for Laravel hooks |
| Windows clone/copy fails | Use the bootstrap copy helper and Docker-managed `node_modules`, not `git clone` into a mounted populated directory |
| Slow repeated startups | Use `make start` after `make stop`, or `make up` rather than `make up-wait` |
| Environment file is missing keys | `make env-sync` (preserves existing values) |

## Contributing

Issues and pull requests are welcome. Test shell paths on Linux/WSL and PowerShell paths on Windows when modifying setup; keep `app/` out of template commits. Before proposing infrastructure changes, validate `docker compose config -q` and run the CI workflow.

## License

Released under the [MIT License](LICENSE). © 2026 sempitern0.

### Naming and compatibility

The display name is **Laravel Foundry**. The upstream GitHub repository is still named `laravel-letsgo` until its owner explicitly renames it. Existing Docker projects retain their custom `PROJECT_NAME` and their local `.env`; new installations default to `foundry`. A rename of the GitHub repository is **not** necessary to use the rebranded template.

The **runtime setup** uses `scripts/configure-app.php` as its single Laravel environment configurator. Historical shell/PowerShell configurators and the old `destroy` volume-only scripts have been removed; use `make reset-project` (with explicit confirmation) for a complete reset. For production releases `docker/php/Production.Dockerfile` remains separate from the development toolbox.

The repository icon is an original geometric mark evoking modular building blocks. It is not the official Laravel or Docker brand mark.


### MySQL and MariaDB setup

In `make setup`, select `mysql` or `mariadb`, then choose `phpmyadmin` as your database UI (default for new MySQL/MariaDB projects) or `adminer`. The UI is reachable on the host at `http://localhost:8081`; no database port is exposed to the LAN. Run `make reset-project` with explicit confirmation when intentionally deleting a database and application to start fresh; changing engines with existing data requires a deliberate migration, not just editing `.env`.
