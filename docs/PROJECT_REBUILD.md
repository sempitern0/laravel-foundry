# Portable project setup and rebuild

After the first `make setup`, Foundry writes `.foundry.json`. Commit this file
**in your product repository**, alongside its application source and Composer/npm
lockfiles. The infrastructure template itself continues to ignore generated
`app/`; a product repository must remove that blanket ignore and use Laravel's
application `.gitignore` to exclude `.env`, vendor, node_modules and runtime files.
Do not copy or commit the two `.env` files.

On another development device:

```sh
git clone <your-product-repository>
cd <your-product-repository>
make build
```

Docker Engine/Desktop with Compose v2 and Make are required. On Windows without
Make, run `powershell -NoProfile -File scripts/setup.ps1`. Internet is needed for
images and dependencies not already cached. HTTPS still requires configuring
local hosts and explicitly trusting the new device's CA using `make https-setup`.

| Command | Behavior |
| --- | --- |
| `make setup` / `make build` | First run asks infrastructure/starter choices. Configured projects restore choices without prompts, retain source, build images, install dependencies, migrate the local database, compile assets and start services. |
| `make rebuild` | Same preparation, then recreates services and waits for readiness. Existing database/storage volumes remain. |
| `make images` | Previous image-only build behavior. Does not start services or migrate. |
| `make reconfigure` | Explicitly opens the infrastructure wizard and saves the resulting shared choices. |
| `make reset-project` | Existing typed confirmation is required. Removes app, local env, portable configuration and project volumes. Backups remain. Commit the manifest deletion if resetting the product in Git is intended. |

The manifest contains only an allowlist of project choices: starter identity,
project name, DB/queue/mail engine, service UI, ports, HTTPS and tenancy blueprint.
It does not contain passwords, SMTP credentials, APP_KEY, UID/GID or runtime data.
Existing configured local `.env` values take precedence over the manifest. A
fresh machine gets new local DB credentials and its own Laravel key. SMTP login
and other product-specific secrets must be provided separately. This restores
**environment configuration and code, not another device's data or secrets**.

A configured clone without `app/artisan` fails rather than silently downloading
a different starter. Source and lockfiles are essential to reproducing a product.
`make build` applies local migrations; use `make images` if you only want images.
For changed root `.env` choices, `make build` recalculates service profiles and
updates managed Laravel settings while retaining APP_KEY and unrelated settings.
No production deployment is performed by these development commands.

## Port from Private NAS PR #2

Compared against `9d2774cc84adac473fcc8892c4706e7c57ba0913`, with Foundry based on
`ed0ba0e`:

- Adapted: preserve existing source without keep/replace prompts; create missing
  Laravel runtime directories; repair ownership only in Docker tooling volumes;
  restore dependencies and compile frontend assets during rebuild.
- Added to close the cross-device gap: versioned, credential-free manifest;
  clone restoration, strict key validation and reset removal on POSIX/PowerShell.
  Private NAS remembered configuration through its ignored `.env` alone.
- Retained Foundry's generic starters and services. No NAS/music/Navidrome files,
  forced Wayfinder command, application auth changes or production overlays copied.
- Existing app dependencies use Composer install and npm ci with lockfiles.
  Starter-specific scripts still run through the application's own package scripts.
