# Native GNU Make on Windows normally runs recipes through cmd.exe, not /bin/sh.
# WSL/Linux/macOS use POSIX shell scripts. Keep host-specific logic out of recipes.
ifeq ($(OS),Windows_NT)
SETUP_SCRIPT := powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/setup.ps1
BACKUP_SCRIPT := powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/backup.ps1
DESTROY_SCRIPT := powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/destroy.ps1
RESET_SCRIPT := powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/reset-project.ps1
HTTPS_SETUP_SCRIPT := powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/https-setup.ps1
else
SHELL := /bin/sh
SETUP_SCRIPT := sh scripts/setup.sh
BACKUP_SCRIPT := sh scripts/backup.sh
DESTROY_SCRIPT := sh scripts/destroy.sh
RESET_SCRIPT := sh scripts/reset-project.sh
HTTPS_SETUP_SCRIPT := sh scripts/https-setup.sh
endif

.DEFAULT_GOAL := help
DC := docker compose
STARTER ?=
.PHONY: help setup up up-detached up-wait up-logs start stop down down-detached build rebuild restart logs ps shell artisan composer npm migrate test lint worker scheduler redis destroy config backup https-cert https-setup env-sync reset-project

help:
	@echo "Laravel Let's Go - Docker Compose Laravel project template"
	@echo "  make setup [STARTER=svelte]   Interactive first-time installation"
	@echo "  make up                     Fast, detached start / create"
	@echo "  make up-wait                Wait for container healthchecks"
	@echo "  make up-logs                Foreground compose session"
	@echo "  make stop / start           Quick pause and resume (keep containers)"
	@echo "  make down                   Remove containers/networks, keep volumes"
	@echo "  make rebuild                Rebuild dev images explicitly"
	@echo "  make logs / ps              Inspect application services"
	@echo "  make artisan CMD='route:list'"
	@echo "  make composer CMD='install' / npm CMD='run build'"
	@echo "  make migrate / test / lint"
	@echo "  make backup / env-sync / https-setup"
	@echo "  make reset-project          Destructive: remove generated app and volumes"

setup:
	$(SETUP_SCRIPT) $(if $(strip $(STARTER)),$(if $(filter Windows_NT,$(OS)),-Starter "$(STARTER)","$(STARTER)"),)

# Fast path: return when containers are started, not when every proxy passes
# a chained healthcheck. Use up-wait for deployment smoke tests.
up:
	$(DC) up -d

up-detached: up

up-wait:
	$(DC) up -d --wait --wait-timeout 120

up-logs:
	$(DC) up

# Daily pause/resume: unlike "down" these retain containers and networks.
stop:
	$(DC) stop

start:
	$(DC) start

build:
	$(DC) build app composer

rebuild:
	$(DC) --profile dev up -d --build

down:
	$(DC) --profile dev --profile workers --profile redis --profile scheduler --profile https --profile pgweb --profile adminer --profile mariadb --profile postgres --profile mailpit down --remove-orphans

down-detached: down

restart: stop start

ps:
	$(DC) ps

logs:
	$(DC) logs -f --tail=100

shell:
	$(DC) exec app sh

artisan:
	$(DC) exec app php artisan $(CMD)

composer:
	$(DC) run --rm --no-deps composer composer $(CMD)

npm:
	$(DC) --profile dev run --rm --no-deps --entrypoint npm node $(CMD)

migrate:
	$(DC) exec app php artisan migrate

test:
	$(DC) exec app php artisan test

lint:
	$(DC) run --rm --no-deps composer composer run lint:check

worker:
	$(DC) --profile workers up -d worker

scheduler:
	$(DC) --profile workers up -d scheduler

redis:
	$(DC) --profile redis up -d redis

config:
	$(DC) config -q

backup:
	$(BACKUP_SCRIPT)

destroy:
	$(DESTROY_SCRIPT)

https-cert:
	$(DC) --profile https cp caddy-local:/data/caddy/pki/authorities/local/root.crt ./caddy-local-root.crt
	@echo "Inspect the certificate before trusting it. See README HTTPS section."

https-setup:
	$(HTTPS_SETUP_SCRIPT)

env-sync:
	$(DC) run --rm --no-deps composer php /opt/letsgo/env-sync.php --root-only

reset-project:
	$(RESET_SCRIPT)
