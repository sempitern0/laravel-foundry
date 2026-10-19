# Native GNU Make on Windows normally runs recipes through cmd.exe, not /bin/sh.
# WSL/Linux/macOS use POSIX shell scripts. Keep host-specific logic out of recipes.
ifeq ($(OS),Windows_NT)
SETUP_SCRIPT := powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/setup.ps1
BACKUP_SCRIPT := powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/backup.ps1
DESTROY_SCRIPT := powershell.exe -NoProfile -ExecutionPolicy Bypass -File scripts/destroy.ps1
else
SHELL := /bin/sh
SETUP_SCRIPT := sh scripts/setup.sh
BACKUP_SCRIPT := sh scripts/backup.sh
DESTROY_SCRIPT := sh scripts/destroy.sh
endif

.DEFAULT_GOAL := help
DC := docker compose
STARTER ?=
.PHONY: help setup up up-detached down down-detached build rebuild restart logs ps shell artisan composer npm migrate test lint worker scheduler redis destroy config backup https-cert

help:
	@echo "Laravel Let's Go - Docker-based, frontend-neutral Laravel template"
	@echo "  make setup                   Interactive starter selector (default: Laravel)"
	@echo "  make setup STARTER=svelte    Svelte + Inertia"
	@echo "  make setup STARTER=vue       Vue + Inertia"
	@echo "  make setup STARTER=react     React + Inertia"
	@echo "  make setup STARTER=livewire  Livewire"
	@echo "  make setup STARTER=laravel   Plain Laravel"
	@echo "  make up / down / ps / logs   Container management""
	@echo "  make rebuild                 Rebuild PHP image after Dockerfile changes
	@echo "  make artisan CMD='route:list' / composer CMD='require ...'"
	@echo "  make npm CMD='run build' / migrate / test / lint"
	@echo "  make worker / scheduler / redis / backup / destroy"

setup:
	$(SETUP_SCRIPT) $(if $(strip $(STARTER)),$(if $(filter Windows_NT,$(OS)),-Starter "$(STARTER)","$(STARTER)"),)

up:
	$(DC) up

up-detached:
	$(DC) up -d

build:
	$(DC) build app

rebuild:
	$(DC) --profile dev up -d --build

down:
	$(DC) --profile dev --profile workers --profile redis --profile scheduler --profile https --profile pgweb --profile adminer --profile mariadb --profile postgres --profile mailpit down --remove-orphans

down-detached: down

restart: down up-detached

ps:
	$(DC) ps

logs:
	$(DC) logs -f --tail=100

shell:
	$(DC) exec app sh

artisan:
	$(DC) exec app php artisan $(CMD)

composer:
	$(DC) exec app composer $(CMD)

npm:
	$(DC) --profile dev run --rm --no-deps --entrypoint npm node $(CMD)

migrate:
	$(DC) exec app php artisan migrate

test:
	$(DC) exec app php artisan test

lint:
	$(DC) exec app composer run lint:check

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
