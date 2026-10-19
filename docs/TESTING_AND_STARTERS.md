# Testing and customizing starters

## Test environment inside Docker

Development Compose deliberately does not inject `APP_ENV=local` into PHP, Composer or Node containers. Laravel reads the generated application's `.env` during development; PHPUnit/Pest can then select `testing` through `phpunit.xml`. An externally pinned `APP_ENV` can override PHPUnit's default `<env>` declaration and prevent Laravel from recognizing a test run, producing CSRF 419 responses on POST/PATCH/DELETE requests.

`make test` explicitly sets `APP_ENV=testing` for that command only and accepts filters:

```sh
make test
make test CMD="--filter=AuthenticationTest"
```

Without Make (also works in PowerShell):

```sh
docker compose exec -e APP_ENV=testing app php artisan test
```

After updating Compose, recreate existing development containers to remove old environment values (`make up` reconciles configuration; `make start` only resumes existing containers). For cached Laravel configuration, run `make artisan CMD="config:clear"` before tests. Neither command removes database volumes.

Keep test database configuration in the product's `phpunit.xml` or `.env.testing`: use SQLite `:memory:` for supported tests or a dedicated disposable test database. Review that configuration before running tests that refresh the schema. Do not point tests at your development or production data. If another orchestrator deliberately injects `APP_ENV`, the product can use `<env name="APP_ENV" value="testing" force="true"/>` in PHPUnit as well.

Do not disable CSRF globally to fix 419 test failures. A 403 can instead be a legitimate authorization failure: when adding an owner/admin gate, update authorized test fixtures to create that role and retain negative tests for ordinary users. Likewise, if the product changes `/` from a welcome page to a redirect, update its homepage test to assert the intended redirect. These product decisions cannot be fixed generically by the template.

## Fortify features and Wayfinder builds

Removing `Features::registration()` from `config/fortify.php` removes its server routes. Wayfinder consequently stops generating registration helpers. A retained `Register.svelte` importing `@/routes/register` can still be included by the page resolver and fail the build even when no visible link points to it.

When disabling a feature in your product:

1. Remove or adapt its page, imports, navigation links and related generated-action consumers. For disabled registration this includes `Register.svelte` and registration links in login/welcome pages. Keep registration enabled for a normal public-registration starter.
2. Clear stale route/config caches using `php artisan route:clear` and `php artisan config:clear` through the app container.
3. Rebuild using `make npm CMD="run build"`, which runs PHP-capable Node tooling and Wayfinder generation.
4. Update feature tests to assert the disabled routes and intended authorization behavior.

Do not create fake generated route files or re-enable public registration just to make a private application's bundle compile. Foundry does not automatically delete application pages or change Fortify features.

## Svelte and font warnings

`$state(settings.name)` captures an initial prop value; it does not track later Inertia prop replacements. For read-only computed data use `$derived`. For an editable form, decide whether incoming server props should reset the draft (with a narrowly scoped effect) or whether an intentional initial snapshot is appropriate. Preserve unsaved edits deliberately; do not silence warnings indiscriminately.

The optional `fontaine` message is separate from a missing Wayfinder module. Either install the optional dependency in the product and commit its lockfile, or configure `optimizedFallbacks: false` on the relevant font declaration if optimized fallbacks are not wanted. It is not necessary to add this package to every Foundry starter.

References: [Laravel testing](https://laravel.com/docs/testing), [starter feature customization](https://laravel.com/docs/starter-kits), [Svelte compiler warnings](https://svelte.dev/docs/svelte/compiler-warnings#state_referenced_locally).
