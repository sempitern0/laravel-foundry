# Deployment and environment parity

This is a **reference operating procedure**, not a push-button production release. For a comparison of DigitalOcean, Hetzner, Vultr, Linode, Forge, Laravel Cloud and App Platform, see [HOSTING_PROVIDERS.md](HOSTING_PROVIDERS.md). It explains how to develop against a stack comparable to production, test the *actual release artifacts* locally and in staging, and then promote those exact artifacts to production. Replace sample hosts, image tags and secrets with values for your product.

> **Critical prerequisite:** Laravel Foundry is an infrastructure template and ignores `app/`. Create a **separate product repository** that commits Laravel code, migrations, `composer.lock`, `package-lock.json`, infrastructure and `AGENTS.md`. Do not simply remove the ignore rule on the template and publish private application data.

## 1. What parity means

| Concern | Development | Local production parity | Staging | Production |
| --- | --- | --- | --- | --- |
| Source | Live `app/` mount | Built image | Same tested image | Same tested image |
| PHP | PHP 8.4 + required extensions | PHP 8.4 + required extensions | Identical PHP image | Identical PHP image |
| Web | Nginx / optional local Caddy | Release Nginx + local Caddy | Release Nginx + public Caddy | Release Nginx + public Caddy |
| Assets | Vite HMR or local bundle | Built Vite assets in image | Exactly same built assets | Exactly same built assets |
| Database | PostgreSQL 17 for parity | PostgreSQL 17 | PostgreSQL 17, isolated storage | PostgreSQL 17, isolated storage |
| Queue, cache, session | Configure consistently | Production-mode configuration | Real integrations | Real integrations |
| `APP_ENV` / debug | local / on | production / off | staging / off | production / off |
| Secrets/data | Test-only | Test-only | Unique, synthetic or sanitized | Unique, real |
| DNS/TLS | `.test` local CA | `.test` local CA | Public DNS + trusted TLS | Public DNS + trusted TLS |

**Important compatibility limit:** local setup can select MariaDB, MySQL or SQLite; the *current* `compose.production.yaml` uses PostgreSQL. To claim database parity, use PostgreSQL locally as well, or adapt, review and test the production Compose for the selected database **before** deployment. Likewise production Compose does not provision Redis; do not configure `QUEUE_CONNECTION=redis` or Redis-backed sessions unless adding the service or external Redis appropriately.

You should make **the behavior and runtime comparable**, not copy production customer data or credentials to a laptop. Keep service versions, SQL semantics, migrations, timezones, PHP extensions, queue modes and feature flags compatible. Where strict parity is impossible, document differences and test them in staging.

## 2. Create and version an application repository

1. Run `make setup STARTER=svelte` (or another starter) in a clean Foundry checkout. Record your engine, frontend and optional services.
2. Copy the template infrastructure and the **generated contents of `app/`** to a new Git repository for the product. Adjust its `.gitignore` so it **tracks application source**, while excluding `app/.env`, `vendor/`, `node_modules/`, caches, logs and generated secrets.
3. Commit `composer.json`, `composer.lock`, `package.json`, `package-lock.json` and all migrations with the application. Keep the chosen starter's lockfile; never silently install arbitrary latest dependencies when reproducing a release.
4. Copy/adapt `AGENTS.md` and record any architecture decisions or environment-specific integrations.
5. Protect the default branch, run automated tests on pull requests and grant minimal CI permissions. Do not check in credentials, database dumps or production `.env` files.

The included `.github/workflows/release.yml` triggers for Git tags `v*` and currently pushes a PHP-FPM and Nginx image to GHCR. It requires the app + lockfiles in the product repository and registry permissions. Review and validate the release job against the selected starter first. In particular, verify your Wayfinder/Vite build, image contents and the runtime permissions in CI.

## 3. Build once and identify the exact release

Use a commit SHA as the immutable **release identity**, e.g. `RELEASE=git-<full-commit-sha>` (the value here is a placeholder, not a runnable shell substitution). Publish separate PHP and web images **with that same identifier**. Pin image digests (`image@sha256:...`) when possible; never deploy a moving `latest` tag.

Example resulting image references:

```text
APP_IMAGE=ghcr.io/OWNER/PRODUCT-php:git-<commit-sha>
WEB_IMAGE=ghcr.io/OWNER/PRODUCT-web:git-<commit-sha>
```

Run unit, feature, DB, JS and build checks on the same commit before making the release available. Confirm built assets are present in both the Nginx public directory and the Laravel image as required. Staging must **pull the published image** rather than rebuild it with potentially different dependencies. Production must use **the very same image digest** as staging.

> A new image can be rolled back, but **database migrations are not rolled back automatically**. Favor additive/expand-and-contract migrations for deployments involving live data.

## 4. Configure isolated staging and production

The reference `compose.production.yaml` supports host-level Compose variables:

| Variable | Purpose |
| --- | --- |
| `PROJECT_NAME` | Compose project prefix; use different values for staging and production |
| `APP_IMAGE` / `WEB_IMAGE` | Immutable release image refs, matching the same commit |
| `APP_DOMAIN` | Public hostname used by Caddy |
| `APP_ENV_FILE` | Untracked Laravel runtime variables file |
| `DB_ENV_FILE` | Untracked PostgreSQL container variables file |
| `PUBLIC_BIND_IP` | `0.0.0.0` for public hosts, `127.0.0.1` for local parity |
| `PUBLIC_HTTP_PORT` / `PUBLIC_HTTPS_PORT` | Bind ports (default 80/443) |
| `CADDY_CONFIG_FILE` | Override Caddy config for local-only production parity |
| `LOCAL_DOMAIN` | Domain passed to the local Caddyfile when used |

In your **product checkout** create a `deploy/` folder with ignored files. Example `deploy/staging.env` (Compose substitutions, **not** Laravel secrets):

```dotenv
PROJECT_NAME=product-staging
APP_IMAGE=ghcr.io/OWNER/PRODUCT-php:git-REPLACE_WITH_COMMIT
WEB_IMAGE=ghcr.io/OWNER/PRODUCT-web:git-REPLACE_WITH_COMMIT
APP_DOMAIN=staging.example.com
APP_ENV_FILE=./deploy/staging.app.env
DB_ENV_FILE=./deploy/staging.db.env
PUBLIC_BIND_IP=0.0.0.0
PUBLIC_HTTP_PORT=80
PUBLIC_HTTPS_PORT=443
```

In `deploy/production.env`, set `PROJECT_NAME=product-production`, your production `APP_DOMAIN`, and **the exact images validated in staging**. If both environments live on one machine, their host ports will conflict: use separate hosts or a deliberately designed shared edge reverse proxy. Different Compose project names isolate network and **named volumes**, not ports, disk quotas or host security.

Create `deploy/staging.app.env` based on `app.production.env.example`:

```dotenv
APP_NAME=MyProduct
APP_ENV=staging
APP_DEBUG=false
APP_URL=https://staging.example.com
APP_KEY=base64:REPLACE_WITH_REAL_GENERATED_KEY
LOG_CHANNEL=stderr
DB_CONNECTION=pgsql
DB_HOST=postgres
DB_PORT=5432
DB_DATABASE=product_staging
DB_USERNAME=product_staging
DB_PASSWORD=REPLACE_WITH_UNIQUE_LONG_SECRET
CACHE_STORE=database
SESSION_DRIVER=database
QUEUE_CONNECTION=database
MAIL_MAILER=log
```

Create `deploy/staging.db.env` (these credentials must **match** the app file, but neither staging nor production uses development credentials):

```dotenv
POSTGRES_DB=product_staging
POSTGRES_USER=product_staging
POSTGRES_PASSWORD=REPLACE_WITH_SAME_STAGING_DB_SECRET
```

Repeat for production using **distinct** values in `deploy/production.app.env` and `deploy/production.db.env`. Keep each `APP_KEY` stable per environment across releases; generate it securely (for example with an isolated Laravel CLI) before first deployment. Changing an established key can invalidate sessions and encrypted data.

Load secrets from an appropriate secret manager or encrypted server-side configuration, restrict file permissions, use real SMTP and external gateways only where intended, and avoid public administration UIs. Docker `env_file` is not secret encryption.

## 5. Deploy staging and check readiness

From the root of the **product repository**, on the intended staging host:

```sh
docker compose --env-file deploy/staging.env -f compose.production.yaml config --quiet
docker compose --env-file deploy/staging.env -f compose.production.yaml pull
docker compose --env-file deploy/staging.env -f compose.production.yaml up -d --wait
```

If the release uses database migrations, back up the staging database and deploy a tested compatible migration. The project can run one-off Artisan commands in the **running app**:

```sh
docker compose --env-file deploy/staging.env -f compose.production.yaml exec -T app php artisan migrate --force
docker compose --env-file deploy/staging.env -f compose.production.yaml exec -T app php artisan optimize:clear
docker compose --env-file deploy/staging.env -f compose.production.yaml exec -T app php artisan queue:restart
```

For real deployments schedule migrations **in a controlled release phase**, ideally before switching incompatible application traffic, not blindly after `up`. Decide ordering according to backward compatibility. Check status:

```sh
docker compose --env-file deploy/staging.env -f compose.production.yaml ps
docker compose --env-file deploy/staging.env -f compose.production.yaml logs --tail=100 app web caddy postgres
```

Verify the public URL, login/session flow, migrations, DB writes, file uploads and persistence, scheduled jobs, workers, mail and third-party sandbox integrations. Check `APP_DEBUG=false`, error pages, proxy/TLS headers, PHP/JS build output, performance and access controls. Record the release image digests as the promotion candidate.

**Note:** `--wait` only observes declared Docker healthchecks and service running state. It does not automatically certify database migrations, Laravel business endpoints or integrations. Current production Compose does not include an application-level HTTP healthcheck; supplement with explicit smoke tests.

## 6. Promote staging → production

1. Obtain change approval and a recent, independently stored **production** backup (database and user uploads); check that recovery has been rehearsed.
2. Change only `APP_IMAGE` and `WEB_IMAGE` release references in `deploy/production.env`, using the **same tested digests** from staging.
3. Validate and pull:

```sh
docker compose --env-file deploy/production.env -f compose.production.yaml config --quiet
docker compose --env-file deploy/production.env -f compose.production.yaml pull
```

4. Execute the approved compatibility/deployment plan: migration timing, optional maintenance mode, `up -d`, smoke tests, metrics and worker restart. Avoid `down -v` and never copy staging volumes onto production.
5. For an application-only rollback, restore the **previous image references** and `up -d` again **only if the new migration is backwards-compatible**. For an irreversible schema/data change, use a tested forward fix or recovery plan; a container rollback cannot undo it.

## 7. Local production-parity rehearsal

You can run production images **locally** without publishing ports to your network. Example ignored `deploy/local-parity.env`:

```dotenv
PROJECT_NAME=product-parity
APP_IMAGE=ghcr.io/OWNER/PRODUCT-php:git-REPLACE_WITH_COMMIT
WEB_IMAGE=ghcr.io/OWNER/PRODUCT-web:git-REPLACE_WITH_COMMIT
APP_DOMAIN=product-parity.test
LOCAL_DOMAIN=product-parity.test
CADDY_CONFIG_FILE=./docker/caddy/Caddyfile.local
APP_ENV_FILE=./deploy/local-parity.app.env
DB_ENV_FILE=./deploy/local-parity.db.env
PUBLIC_BIND_IP=127.0.0.1
PUBLIC_HTTP_PORT=8088
PUBLIC_HTTPS_PORT=8444
```

Create `deploy/local-parity.app.env` with `APP_ENV=production`, `APP_DEBUG=false`, `APP_URL=https://product-parity.test:8444`, test-only secrets, PostgreSQL connection and non-delivering mail. Give `deploy/local-parity.db.env` corresponding `POSTGRES_*` test credentials.

```sh
docker compose --env-file deploy/local-parity.env -f compose.production.yaml config --quiet
docker compose --env-file deploy/local-parity.env -f compose.production.yaml up -d --wait
```

Map `127.0.0.1 product-parity.test` in your local hosts file. Caddy `tls internal` needs explicit certificate trust; do **not** trust a CA from unknown sources. Check `https://product-parity.test:8444` and application workflows. This preview uses **separate named volumes** from your normal `compose.yaml` development environment.

When done, stop parity safely, **without** `-v`:

```sh
docker compose --env-file deploy/local-parity.env -f compose.production.yaml down
```

## 8. Keep the environments synchronized over time

- **Each feature PR:** update application code, migrations, tests, frontend manifests/locks, configuration examples and documentation together; run tests with the chosen database engine.
- **Each release:** create immutable PHP/web images from one commit, tag by SHA, inspect artifacts, rehearse locally and deploy to staging, then promote the same digests to production.
- **Each environment:** store only environment-specific configuration/secrets/data outside Git. Align PHP extensions, database versions, service types, timezone and required feature flags; explicitly document intentional differences.
- **Database evolution:** source of truth is version-controlled migration history, not copying a live database back and forth. Use sanitized, consented fixtures or synthetic seeds; never ingest raw personal/production data locally.
- **Queues and jobs:** verify worker/scheduler parity and idempotency. Revisit `QUEUE_CONNECTION` changes explicitly.
- **Routine operations:** test offsite backups, restores, monitoring and disaster recovery; keep image provenance and release/change logs.
- **Security updates:** rebuild and test all environments from pinned base images and lockfiles before a controlled promotion.

### Deployment checklist

- [ ] App source and lockfiles committed in a product repository
- [ ] Same PHP/web image digests validated locally and in staging
- [ ] Matching database engine/major version and migrations reviewed
- [ ] Correct HTTPS domain, APP_URL, trusted TLS and proxy headers
- [ ] `APP_DEBUG=false` and distinct environment-specific keys/secrets
- [ ] Database and uploads persistence proven across container recreation
- [ ] Workers, scheduler, queue, cache and session behavior exercised
- [ ] Staging smoke tests passed and production backup verified
- [ ] Migration compatibility and image rollback strategy approved

**Scope limitation:** this guide documents a robust workflow, but the repository does not currently automate full zero-downtime deployment, secrets management, restore, rollback or per-environment test gates. Those must be implemented and verified for the product before calling it production-ready.
