# AGENTS.md — Laravel Foundry

> Scope: this repository and any Laravel application intentionally generated from it. Infrastructure and application are separate. Follow the more specific AGENTS.md of a product when present. Treat application source, tests and dependency manifests as the source of truth, not guesses from this guide.

## Mission and priority

Build maintainable, secure, idiomatic **PHP + Laravel** applications. Prefer small, well-tested changes that respect the selected starter and the product's existing patterns. Do not introduce a framework, abstraction, package or service solely because it is mentioned here.

1. Follow explicit project/task requirements and safety constraints.
2. Inspect the actual framework and dependency versions before using APIs.
3. Preserve established code conventions, schemas, public interfaces and user data.
4. Make the smallest coherent change, test it, and explain meaningful trade-offs.
5. Never invent execution results. State unrun tests and environment limitations.

## Repository topology and first 90 seconds

Laravel Foundry's root is the **Docker/Compose infrastructure template**; generated applications live in ignored `app/`. This root AGENTS.md is tracked by the template. When making a *separate application repository*, also copy/adapt this guidance there, or provide an `app/AGENTS.md` appropriate to that codebase.

Before writing code, do the minimum relevant reconnaissance:

- Identify task scope: infrastructure root, Laravel app in `app/`, frontend assets, or deployment.
- Read `README.md`, `Makefile`, `compose.yaml` and applicable nested AGENTS.md only as needed.
- For Laravel changes inspect `app/composer.json`, `app/package.json`, `app/routes/`, `app/app/`, `app/database/`, `app/tests/`, and relevant config; never assume Svelte, Inertia, Livewire, React or Vue.
- Locate existing implementations using targeted file searches and references; avoid dumping entire vendor, node_modules, generated output, logs or locks into context.
- Check `git status` / diff and respect concurrent user changes; never reset or overwrite them.
- Create a brief plan for broad tasks. For narrow fixes, proceed directly. Only open files directly related to the behavior being changed.
- Confirm tool availability before invoking host-specific commands. On Windows PowerShell use the native `.ps1` scripts; on Unix use `.sh`. All runtime dependencies are containerized.
- If a starter has not been installed (`app/artisan` absent), do not modify fictitious Laravel application files; update the template/setup logic instead.

## PHP standards and idioms

- Follow **PSR-12** coding style and **PSR-4** namespace/autoloading conventions; additionally honor the project's formatter and Laravel Pint configuration.
- Use strict, clear types for parameters, returns and properties where compatible with the codebase. Declare `strict_types=1` in new standalone PHP modules when it aligns with existing project practices; do not mass-rewrite Laravel-generated files.
- Use modern PHP language features supported by the **actual** runtime, not merely the Docker image tag.
- Apply single responsibility pragmatically, descriptive names, dependency injection and small methods. Prefer Laravel conventions over speculative domain layers.
- Favor framework services (container, validation, authorization, notifications, queues, cache, events, filesystem) instead of custom reimplementations.
- Avoid magic, dynamic class names, hidden global state and overly clever helpers; add interfaces only for meaningful boundaries.
- Do not edit vendor code or commit generated artifacts and secrets.

## Laravel organization and request flow

Use default Laravel structure unless the application already establishes modules:

- `routes/web.php`: browser routes, appropriate sessions/CSRF; `routes/api.php` only when API routing is installed and required.
- Controllers: HTTP orchestration, minimal domain logic. Prefer resourceful routes when appropriate.
- Form Requests: validation + request authorization for nontrivial writes; never trust frontend validation alone.
- Policies/Gates: permission checks at the server boundary; authenticate before authorizing, avoid IDOR.
- Models: Eloquent relationships, casts, scopes and domain behavior naturally owned by the entity. Avoid fat controllers and god-models.
- Services/actions: add for **reusable or complex** domain workflows only. An action class per trivial CRUD method is not a requirement.
- Jobs: slow or retriable work; events/listeners: decoupled domain side effects; notifications/mail: message delivery; observers only for narrowly justified lifecycle behavior.
- API Resources: deliberate API response contracts, avoid leaking internal/sensitive fields.
- Configuration: use `config/*.php` and environment variables through config; never call `env()` arbitrarily in request-time domain code.
- Service providers/container bindings: register integrations via existing conventions; keep bootstrap and provider changes minimal.

## Database, migrations and query performance

- Detect configured database engine first: PostgreSQL, MariaDB, MySQL and SQLite differ in syntax and capabilities. Use portable Schema Builder when practicable.
- Create migrations for schema changes; do not edit already-applied migrations in shared environments. Include compatible forward changes and avoid destructive changes without an explicit migration strategy.
- Foreign keys, indexes, unique constraints and nullable behavior must reflect real invariants. Think about soft deletes, timestamps, timezone/UTC, decimals for money and transactional integrity.
- Name models/relationships idiomatically; declare `fillable` / `guarded` deliberately and never mass assign privileged fields from raw request data.
- Scope queries to the authenticated user/tenant when applicable; do not assume authorization from an opaque ID.
- Inspect query plans when needed; prevent N+1 access via `with()`, `load()`, explicit column selections and pagination. Do not eager-load everything indiscriminately.
- Use `DB::transaction()` for multi-write invariants; place irreversible external side effects after commit when appropriate.
- Add or update model factories, seeders for safe development data and database tests. Seeders must be idempotent when expected and never replace production data.
- Avoid unbounded queries, raw SQL concatenated with user input and migrations that silently discard data.
- For production changes, consider expand/contract migrations and deployment ordering; rolling back an image does not reverse a migration.

## Starter-specific frontend rules — detect, do not assume

Inspect `app/package.json`, `app/vite.config.*`, routes and actual source before selecting conventions.

- **Blade**: server-rendered HTML, escaped output by default; use components for reused UI.
- **Livewire**: respect its state/hydration and validation lifecycle; use Alpine only where appropriate to the installed stack.
- **Inertia + Svelte / Vue / React**: Laravel owns routes, authorization and server validation. Keep pages/layouts/components idiomatic for the selected framework. Do not introduce parallel SPA routing or duplicate authorization in JavaScript.
- **Svelte**: use Svelte component conventions and the installed major version; do not assume legacy syntax if the starter uses runes.
- **Vue**: follow the app's Composition API / TypeScript conventions when present.
- **React**: functional components/hooks, stable effect dependencies and existing form/state conventions; do not introduce new state libraries without a need.
- **Plain JS/TS and CSS**: use the existing bundler, import aliases, design tokens and UI library; maintain accessible semantics, keyboard support and responsive behavior.
- **SvelteKit / Astro** are not assumed Laravel starters. If they exist as separate services, respect their distinct build/runtime architecture.
- Vite/Wayfinder may invoke `php artisan` during frontend builds. Run Node commands through the provided PHP-capable `node` container.
- Add JS packages only when clearly necessary, check installed versions and licenses, prefer existing utilities and commit lockfiles **in an actual app repository**.

## Security and reliability requirements

- Validate all external inputs and authorize every sensitive resource/action on the server.
- Preserve CSRF/session protection for web routes; configure authentication and password handling via supported Laravel facilities.
- Escape untrusted HTML and avoid `{!! !!}` unless content is independently sanitized for its context.
- Use parameterized queries/Eloquent; never construct SQL or shell commands from unsanitized values.
- Handle uploads using validation, size/type constraints, randomized storage names, controlled disks and safe download authorization.
- Never log, commit, print or return passwords, tokens, mail credentials, raw .env content, personal data or production database dumps.
- Keep `APP_DEBUG=false` in production; use structured logs with meaningful context while redacting secrets.
- Carefully handle third-party HTTP timeouts, retries, idempotency, failures and rate limits.
- Queue handlers must tolerate retries and duplicate delivery; set appropriate timeouts and retry policies.
- Prefer minimal permissions, least-exposed ports and no public database admin UI. Local HTTPS certificate trust requires explicit approval.

## Docker Compose and infrastructure changes

- Preserve the runtime/tooling boundary: PHP-FPM is lean; Composer is an **on-demand** toolbox (also supports npm invoked by Laravel Composer hooks); Node/Vite has PHP CLI for Wayfinder.
- Add a service only with a real requirement. Use optional Compose `profiles`, isolated volumes, and explicit dependencies/healthchecks where justified.
- Keep public ports bound to `127.0.0.1` for local services; do not expose databases, Redis, phpMyAdmin, Pgweb or Adminer on `0.0.0.0`.
- Update **together** when adding/removing a service: `compose.yaml`, setup wizard, both setup scripts if necessary, environment examples, app configurator, reset profiles, Makefile, CI and README.
- Treat MySQL and MariaDB as separate services with separate data volumes. Do not assume a container rename migrates data.
- Keep `app/` ignored in this **template**. A product repo must version app source and lockfiles while ignoring credentials and dependencies.
- Do not auto-install OS packages, edit `hosts` or trust a CA without explicit user confirmation.
- `make reset-project` and removal of volumes are destructive and require the current confirmation policy. Do not use them as a debugging shortcut.

## Useful commands (from repository root)

```sh
make help
make setup STARTER=laravel  # or svelte|vue|react|livewire
make up                    # detached, fast
make up-wait               # wait for container readiness
make ps
make logs
make artisan CMD="route:list"
make composer CMD="install"
make npm CMD="run build"
make migrate
make test
make lint                  # only if selected starter defines lint:check
make config
make env-sync
```

- Windows without Make: `powershell -NoProfile -File scripts/setup.ps1 -Starter svelte`.
- Windows prerequisites: `powershell -NoProfile -File scripts/prerequisites.ps1` checks; `-InstallMissing` asks permission before installation.
- Use `docker compose exec app php artisan ...` for commands in a running app container.
- Use `docker compose run --rm --no-deps composer composer ...` for Composer.
- Use `docker compose --profile dev run --rm --no-deps --entrypoint npm node ...` for JS builds.
- For application-specific PHPUnit/Pest, Pint, PHPStan/Larastan, ESLint, TypeScript, Vitest or Playwright commands, detect installed tools/scripts first; do not assert they exist.

## Definition of done and agent output

1. Requirements implemented with the selected starter and current dependencies.
2. Validation, authorization, error behavior and migration impact considered.
3. Appropriate tests added or updated: unit, feature, database, browser/component as applicable.
4. Run targeted tests first, then broader applicable checks; use formatters already installed.
5. If changing Compose: validate `docker compose config -q`, run relevant shell/PowerShell lint and inspect profiles.
6. No unrelated refactors, added dependencies without rationale, accidental secrets, generated source in template Git, or destructive cleanup.
7. Report concise summary, files touched, behavior changed, tests actually run, unverified areas and any migration/deployment instructions.

## Environment parity and releases

- Read [docs/DEPLOYMENT.md](docs/DEPLOYMENT.md) before changing staging/production workflows.
- Do not claim local dev is *identical* to production when using Vite HMR, debug mode, a different database engine or different queue/cache services. Verify a **production-parity run with release images**.
- Commit migration history and Composer/npm lockfiles in the separate product repository. Do not version runtime secrets or generated `app/` in the infrastructure template.
- Build once per commit; publish immutable PHP and web image tags/digests and promote **those exact artifacts** from staging to production.
- Do not copy live production secrets, raw data or persisted volumes into local/staging. Use safe synthetic or appropriately sanitized fixtures.
- Give staging and production unique project names, env files, APP_KEY and independent database/storage volumes; never run `down -v` against either during routine deployments.
- Ensure staging and production use compatible PHP/DB major versions, extensions, schemas, queues, cache/session behavior, storage and trusted TLS.
- Plan migrations for forwards/backwards compatibility. A code/image rollback does not automatically restore schema or data.
- Preserve external backup/restore procedures and require explicit authorization for production migrations, disruptive actions and secret changes.
