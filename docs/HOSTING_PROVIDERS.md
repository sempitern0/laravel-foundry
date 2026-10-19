# Hosting providers and deployment models for Laravel Foundry

> **Scope:** vendor-neutral reference, verified against providers' public documentation in October 2026. This guide helps a product team **choose and adapt a deployment**, not provision accounts, guarantee provider pricing or change the local Foundry setup. Review [DEPLOYMENT.md](DEPLOYMENT.md) first for immutable releases, staging, production secrets, migrations and recovery.

## 1. Decide who operates the infrastructure

Laravel Foundry is a **Docker Compose-first development and self-hosted production reference**, not a hosting provider, a universal PaaS deployment spec, or a substitute for production operations.

| Model | Examples | Keep current `compose.production.yaml`? | Operator responsible for |
| --- | --- | --- | --- |
| Self-managed VPS/IaaS | DigitalOcean Droplets, Hetzner Cloud, Vultr Cloud Compute, Akamai/Linode, AWS EC2/Lightsail | **Usually yes**, once reviewed and provisioned | OS updates, Docker, firewalls, backups, TLS, deployments, metrics, incidents |
| Managed server administration | **Laravel Forge** on supported providers, or Laravel VPS | **Normally no, not unchanged**: choose either Forge-managed PHP/Nginx or a separately managed Docker stack | Forge handles much provisioning/site deployment; developer still owns app, data, costs and recovery |
| Managed Laravel PaaS | **Laravel Cloud** | **No direct Compose deployment**; configure the Laravel app and managed resources | Platform runs compute/deploys; developer still owns app design, configuration, migrations, data protection |
| General-purpose PaaS | **DigitalOcean App Platform** | **No direct Compose deployment**; define platform components / a suitable HTTP-serving container | Platform manages infrastructure; developer configures services, workers, secrets, durable storage |

**Portability has two levels:** (1) portable application source + migrations + tested configuration, and (2) portable **container runtime topology**. All options can host a suitable Laravel application. Only a general Linux VPS is intended to run this Compose layout with minimal conceptual changes. There is no automatic migration of the `docker compose` network, volumes, worker containers, CA or Caddy when switching to a PaaS.

### Selection by priority

- **Maximum self-hosting control / closest local-to-production topology:** a Linux VPS with Docker Engine and Compose.
- **Prefer Laravel-oriented server management but retain SSH/root control:** Forge or Laravel VPS; adapt away from Foundry's Docker-managed production web stack.
- **Prefer managed application infrastructure and integrated Laravel services:** Laravel Cloud; treat Docker Compose as the local environment rather than the production deployment specification.
- **Prefer a provider-managed container PaaS:** DigitalOcean App Platform; explicitly adapt web serving, background workers, schedules, database and file persistence.
- **Data residency and network proximity:** select a real available region close to users and satisfy compliance requirements. Verify provider-specific regions, egress/bandwidth billing, backups, SLA and support **at purchase time**. This file intentionally avoids transient pricing figures or unsupported “cheapest/best” rankings.

## 2. VPS providers compatible with the current Docker stack

| Provider | Official entry point | Foundry adaptation / notes |
| --- | --- | --- |
| [DigitalOcean Droplets](https://docs.digitalocean.com/products/droplets/) | Linux VPS (“Droplet”) with cloud firewalls, backups and volumes | A direct fit for `compose.production.yaml`. Run the **published release images**, configure SSH/firewall, and verify database/storage persistence and off-site restore |
| [Hetzner Cloud](https://docs.hetzner.com/cloud/servers/overview/) | Cloud servers, private networks, firewall, backups and volumes | Direct Compose fit. **Server backups/snapshots do not include attached Volumes**; arrange separate application/database/Volume backups |
| [Vultr Cloud Compute](https://docs.vultr.com/products/compute/instances/cloud-compute) | Linux VPS with firewall groups, startup automation and optional backups | Direct Compose fit. Check selected VM resources, region, backup and access settings |
| [Akamai / Linode Compute](https://techdocs.akamai.com/cloud-computing/docs/getting-started) | Linux instances with networking and attached services | Direct Compose fit on a supported Linux VM; verify current product/region/service availability |
| [AWS EC2](https://docs.aws.amazon.com/AWSEC2/latest/UserGuide/concepts.html) / [Lightsail](https://docs.aws.amazon.com/lightsail/) | General-purpose Linux compute | Compose can run, but review IAM, VPC/security groups, disks, networking, TLS, monitoring and backup costs |

For the same Foundry application, **provider changes need not require changing PHP code** if the target Linux OS and supported services are equivalent. But moving persistent database/files between hosts is a migration, not just changing DNS. Treat provider VM snapshots as *supplements*, not proof that a database has a consistent, restorable backup.

### Minimum self-managed VPS checklist

1. Choose supported Ubuntu/Debian or another Docker-supported Linux distribution, create a **non-root SSH operator** and restrict SSH access; enable provider + host firewall.
2. Install **Docker Engine + Compose v2 from trusted packages** and set up private access to the registry (GHCR or another registry) with minimal token scope.
3. Configure DNS; open only the necessary public **80/443** and restricted **SSH**. Keep DB, Redis, phpMyAdmin, Adminer, Pgweb and other internal ports off the public network.
4. Provision independent **staging and production** secrets, `APP_KEY`, database volumes and storage with explicit retention/backup policies.
5. Pull the **same immutable PHP/Nginx image digests** tested locally and in staging; validate production Compose before deployment.
6. Set up managed or self-hosted PostgreSQL matching the Compose topology (or adapt it deliberately to MySQL/MariaDB), plus queue, cache, scheduler, email and object storage integrations as required.
7. Configure public Caddy TLS (DNS must resolve to the server; 80/443 must be reachable for automatic certificates), metrics, health probes, offsite encrypted backups and restore drills.
8. Release with migrations and smoke tests using [DEPLOYMENT.md](DEPLOYMENT.md). **Never** run `make setup` or `make reset-project` on a production host and never deploy the local `compose.yaml` as a public production configuration.

**Illustrative remote deployment on a dedicated staging VPS** (requires an existing product repository, pre-provisioned host, verified images and secret files):

```sh
docker compose --env-file deploy/staging.env -f compose.production.yaml config -q
docker compose --env-file deploy/staging.env -f compose.production.yaml pull
docker compose --env-file deploy/staging.env -f compose.production.yaml up -d --wait
docker compose --env-file deploy/staging.env -f compose.production.yaml ps
```

This only validates Compose/container startup. Execute controlled schema migrations and smoke tests separately. Default production Compose **uses PostgreSQL**, irrespective of the DB selected by the local wizard.

## 3. Laravel Forge — VPS management rather than a Compose host

**Official:** [Laravel Forge](https://laravel.com/forge) · [Forge vs Cloud](https://laravel.com/forge/forge-vs-cloud) · [Forge API/server providers](https://forge.laravel.com/api-documentation)

Forge can provision/manage server stacks at supported providers such as **DigitalOcean, Hetzner, Vultr, AWS and Akamai/Linode**, and also offers **Laravel VPS** provisioning through Forge. Forge installs/manages Nginx, PHP and common services on the **server operating system** and supports source-based deploy scripts.

### Two valid but distinct approaches

**A. Forge-native app deployment (usual choice).** Keep the Laravel app source, PSR conventions, tests, migrations and frontend build. Let Forge manage host PHP/Nginx, site config, TLS and worker/scheduler processes; supply environment variables/secrets in Forge. **Do not also launch Foundry's Caddy/Nginx/PHP-FPM stack on the same public ports.** Match PHP versions, extensions and database/queue behavior explicitly. Your local Docker runtime is a parity approximation, not the production runtime itself.

**B. Docker Compose on a Forge-provisioned server (advanced, separately maintained).** It may be possible to manage your own Docker daemon and applications on a server you control; this **is not the same thing as Forge automatically deploying `compose.production.yaml`**. If choosing this, consciously own Docker deployments, registry credentials, container networking, web-server/port conflicts, workers and backups. Avoid redundant Forge-managed and Caddy-managed reverse proxies competing on 80/443.

Forge has an additional subscription cost **on top of VPS/cloud server costs**, except where its own Laravel VPS product bundles billing differently. Compare current contracts and capabilities before deciding.

## 4. Laravel Cloud — managed Laravel deployment, not a Compose provider

**Official:** [Laravel Cloud](https://laravel.com/cloud) · [Deploy a Laravel app](https://laravel.com/cloud/deploy-a-laravel-app) · [Plans](https://laravel.com/cloud/pricing)

Cloud connects to a Git repository, builds and deploys Laravel with a **managed application runtime**. Available platform resources include database options, caching/storage, managed queues and scheduling, according to the current account/plan. The official onboarding does **not require** a Dockerfile, Procfile or separate TLS setup.

**Keep from Foundry:** Laravel application source, controllers, Eloquent migrations, auth, tests, `composer.lock`, `package-lock.json`, code-level configuration contracts, `AGENTS.md`, branch/PR practices and staging smoke tests.

**Replace or reconfigure:**

- The production `compose.production.yaml` **does not get uploaded and orchestrated** as-is by Laravel Cloud.
- Configure Cloud application environments for staging and production, linked Git repository/branch and release policy. Use Cloud's build/deploy pipeline, documented PHP version and environment variables.
- Replace Docker service names such as `postgres`, `redis` or `mailpit` with Cloud-managed/external endpoints; configure database connection, queues, cache, session driver, scheduler and email accordingly.
- Use durable managed/object storage for uploads and other persistent files rather than assuming the template's Docker volume `app-storage` exists.
- Configure public domains, trusted TLS, secret handling, scaling, migration hooks, health checks, logs/observability, backups and recovery in the platform.
- **Plan database migration** if moving from Compose PostgreSQL to Cloud MySQL or Serverless Postgres. Engine choice, SQL semantics, backup/restore and data cutover must be tested; migrations alone do not transfer existing rows.

Cloud supports multiple environments; preview environments and some scaling/worker features can be plan-dependent. **Recheck official Cloud documentation and plan limits**; do not hardcode currently advertised prices/entitlements in an application template.

**Recommended process:** keep development on Foundry Compose → run app tests → deploy a *staging environment in Laravel Cloud* → validate migrations, queues, persistent storage and external services → promote the approved Git revision using Cloud's workflow. Rebuilding in the platform means you must verify app version, resolved dependencies and built asset equivalence. **Do not claim binary-identical Docker images across Forge/Cloud and self-hosted Compose.**

## 5. DigitalOcean App Platform — general-purpose managed app hosting

**Official:** [App Platform](https://docs.digitalocean.com/products/app-platform/) · [Deploy container images](https://docs.digitalocean.com/products/app-platform/how-to/deploy-from-container-images/) · [Workers](https://docs.digitalocean.com/products/app-platform/how-to/manage-workers/) · [Data storage](https://docs.digitalocean.com/products/app-platform/how-to/store-data/)

App Platform can deploy from source or supported container registries, including GHCR, and provides separate components for web services, background workers and jobs. It is **not** a Docker Compose control plane.

To migrate, define its own app specification, deployment/build procedure, **HTTP-serving web component**, background worker(s), database binding, application secret variables, health checks and storage. The current **PHP-FPM image alone does not serve HTTP** and the Foundry Nginx image expects a network-accessible PHP-FPM host named `app`; therefore uploading either one as a single standalone web service is **not guaranteed to work**. Create and validate an appropriate platform-specific HTTP entrypoint/component topology.

For persistent user uploads, use an appropriate provider-supported durable/object storage solution; **do not treat the container filesystem as persistent** through redeploys or scaling. Plan scheduler equivalence (not all deployment jobs are recurring cron jobs).

## 6. Moving between providers without drift

### Keep source and release provenance in Git

- **Source of truth:** the *product* repository and lockfiles, not a server copy of `vendor/` or hand-edited production code.
- **For Compose-on-VPS targets:** build once, publish images by digest, deploy the same digests to staging/production when practical.
- **For Forge/Cloud/App Platform:** deploy the same application commit and frozen dependency versions; verify build differences. Do not claim identical images if a different build system produced them.
- Keep database migration history, external service contract tests and environment examples in version control.
- Keep environment secrets and data outside Git, unique by environment. Never copy raw production customer data to local/staging.

### Provider migration checklist

1. Inventory PHP/extensions, DB **engine and major version**, collation, uploads, queues, schedules, cache/session, mail, WebSockets, third-party connections and DNS.
2. Set up the destination's networking, environment secrets, backups, database/storage/queue resources, TLS, probes and observability; do not publicly expose admin tools.
3. Export/migrate the **actual data and files** with a tested, security-reviewed process; sanitize staging datasets. Confirm backups can restore.
4. Deploy a compatible release to **destination staging**, run migrations deliberately and verify read/write/session/worker/upload flows.
5. Plan data replication or a maintenance window for cutover, DNS TTL and rollback; maintain the previous environment until validation is complete.
6. Document service differences as explicit deployment overlays/config, never as undocumented manual changes to the application.
7. Verify the complete invoice: VM/compute, DB, storage, outbound transfer, load balancer, monitoring, backups and any Forge/managed platform subscription.

## 7. Keep the template vendor-neutral

**Do not add provider API credentials or Terraform/cloud CLI tools to the default Foundry setup.** A provider-specific implementation belongs in an **optional deployment guide/adapter** with its own documentation, tests and permissions. The `Makefile` remains focused on local development; no target in it should deploy to a live cloud account implicitly.

### Source links (official)

- [Laravel Framework deployment](https://laravel.com/framework/docs/deployment)
- [Laravel Cloud deployment](https://laravel.com/cloud/deploy-a-laravel-app) / [Laravel Forge](https://laravel.com/forge)
- [Forge supported provisioning providers](https://forge.laravel.com/api-documentation)
- [DigitalOcean Droplet production setup](https://docs.digitalocean.com/products/droplets/getting-started/recommended-droplet-setup/)
- [DigitalOcean App Platform storage](https://docs.digitalocean.com/products/app-platform/how-to/store-data/)
- [Hetzner server backup / Volume caveat](https://docs.hetzner.com/cloud/servers/backups-snapshots/overview/)
- [Vultr Cloud Compute provisioning](https://docs.vultr.com/products/compute/instances/cloud-compute/provisioning)
