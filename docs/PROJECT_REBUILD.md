# Portable project setup and rebuild

After the first `make setup`, Foundry writes `.foundry.json`. Commit this file
**in your product repository**, alongside its application source and Composer/npm
lockfiles. The template now tracks generated `app/` source by default. Runtime directories,
local `.env` files, dependencies, SQLite databases and compiled assets remain
ignored at the root; no manual change to `.gitignore` is needed after cloning.
The pristine template does not contain Laravel source, so there is nothing to
commit until a starter is installed.
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

## Generic reliability fixes from Private NAS

- PHP Redis extension is installed in the shared base image and available to the app, CLI workers and tools when Redis queues are selected. Merely starting a Redis container is not sufficient without the client extension.
- Nginx uses Docker DNS to refresh the PHP-FPM upstream after replacing the app container (prevents stale-address 502 errors).
- `make test` sets an isolated Laravel application environment and an independent testing configuration cache. The app itself must still ship a safe `phpunit.xml` (e.g. SQLite in-memory, array cache/sessions and sync queue); the template does not overwrite the chosen starter's test configuration.
- CI validates that application source is not ignored and that environment secrets and runtime files remain excluded.

These are framework infrastructure conventions; music-specific catalog adapters, acoustic fingerprints, scan workers and private dashboards are deliberately **not** part of Foundry.

## Docker Desktop cerrado durante setup (Windows)

`make setup` y `make build` comprueban primero si Docker CLI,
Compose v2 y el motor Docker están disponibles. Si Docker Desktop está
instalado pero detenido, se muestra un mensaje sencillo para abrirlo,
esperar a que inicie el motor Linux y volver a ejecutar el comando.
La comprobación se realiza antes de crear o modificar `.env` y antes
de construir cualquier imagen; no se inicia Docker Desktop automáticamente.

La prueba independiente `tests/docker-preflight.ps1` simula cuatro estados
(cliente ausente, Compose ausente, motor parado y entorno listo) sin
necesitar Docker en ejecución.

## Composer lento en el primer setup (Docker Desktop / Windows)

En desarrollo, `composer_vendor` es un volumen Linux de Docker compartido
por PHP-FPM, workers, Composer y el frontend. Esto evita construir miles de
archivos de `vendor/` en un bind mount del sistema de archivos de Windows.
`node_modules` continúa en su propio volumen Docker.

La primera instalación de Composer puede seguir tardando mientras resuelve,
descarga, genera autoload y ejecuta scripts del starter. Si permanece en
`Generating optimized autoload files`, no significa necesariamente que se
haya bloqueado: Laravel puede estar ejecutando descubrimiento de paquetes
posteriormente. El proceso conserva logs visibles y una nueva ejecución de
`make build` reutiliza las dependencias ya instaladas.

La carpeta `app/vendor/` del host ya no es la fuente de dependencias para
contenedores de desarrollo. El volumen se crea automáticamente, sin borrar
código fuente ni datos. Nunca utilices `docker compose down -v` como remedio
para una instalación lenta.

## Diferenciar una instalación nueva de un proyecto existente

Antes del primer comando Docker, `make setup` diferencia estos escenarios:

- Checkout nuevo sin `app/artisan` ni `.foundry.json`: inicializa `.env` desde
  `.env.example`, asigna un `PROJECT_NAME` único y vuelve a mostrar el wizard.
  Si había un `.env` antiguo, lo copia a `app-backups/` antes de sustituirlo.
- Proyecto existente con `app/artisan`: conserva configuración, código y datos.
  Utiliza `make build` para reanudarlo.
- `.foundry.json` presente pero sin `app/artisan`, o `app/` con archivos
  inesperados: detiene la instalación. Debes recuperar la aplicación o crear
  un checkout limpio; no se borran esos archivos ni los volúmenes antiguos.

El identificador Compose se genera antes de levantar cualquier contenedor, para
impedir que dos proyectos nuevos compartan por accidente los volúmenes de
PostgreSQL, Redis o las dependencias. No se ejecuta `docker compose down -v`
ni se eliminan recursos de otros proyectos.

## Resumen al iniciar los servicios

`make setup`, `make up`, `make up-wait` y `make start` muestran un
informe de la configuración y de los servicios detectados. Puedes consultarlo
sin reiniciar ni modificar nada con:

```sh
make status
```

El informe incluye proyecto, starter, base de datos, nombre de la base,
motor de colas, correo, panel de administración de BD, HTTPS, tenancy
(únicamente blueprint), perfiles y estado *running* de los servicios.
Muestra URLs solo cuando el servicio correspondiente está funcionando:

- Laravel HTTP: `http://localhost:HTTP_PORT`; HTTPS con Caddy:
  `https://LOCAL_DOMAIN[:HTTPS_PORT]`.
- Mailpit: `http://localhost:MAILPIT_PORT` cuando se utiliza Mailpit.
- pgweb, phpMyAdmin o Adminer: `http://localhost:DB_UI_PORT`,
  según el panel elegido.
- Vite/HMR aparece únicamente como herramienta de desarrollo si su
  contenedor está en marcha y el proyecto no usa HTTPS.

Los workers, Redis y la base de datos figuran como servicios, pero no se
inventan GUIs que no existen. Tampoco se muestran las contraseñas, claves
de Laravel, secretos SMTP ni credenciales de la base de datos. Un contenedor
running **no garantiza** que la aplicación web responda; para comprobar la
disponibilidad real utiliza `make up-wait` y las pruebas HTTP.
La primera configuración local HTTPS puede requerir `make https-setup`
para registrar el hostname y confiar en la CA local.
