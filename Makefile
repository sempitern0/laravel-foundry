SHELL := /bin/sh
.DEFAULT_GOAL := help
DC := docker compose
STARTER ?=
.PHONY: help setup up down restart logs ps shell artisan composer npm migrate test lint worker scheduler redis destroy config backup
help:
	@echo "Laravel Let's Go — any official Laravel starter, Docker only"
	@echo "  make setup                   Choose a starter interactively (plain Laravel by default)"
	@echo "  make setup STARTER=laravel   Laravel only"
	@echo "  make setup STARTER=svelte    Svelte + Inertia"
	@echo "  make setup STARTER=vue       Vue + Inertia"
	@echo "  make setup STARTER=react     React + Inertia"
	@echo "  make setup STARTER=livewire  Livewire"
	@echo "  make up / down / logs / ps   Container management"
	@echo "  make artisan CMD='route:list' / composer CMD='require ...'"
	@echo "  make npm CMD='run build' / migrate / test / lint"
	@echo "  make worker / scheduler / redis / backup / destroy"
setup:
	sh scripts/bootstrap.sh "$(STARTER)"
	sh scripts/configure-app.sh
	$(DC) up -d --build postgres mailpit app web
	@if ! grep -Eq '^APP_KEY=base64:.+' app/.env; then $(DC) exec -T app php artisan key:generate --force; fi
	$(DC) exec -T app php artisan migrate --force
	$(DC) --profile dev run --rm --no-deps --entrypoint npm node install
	$(DC) --profile dev up -d node
	@echo "App: http://localhost:$$(sed -n 's/^HTTP_PORT=//p' .env) | Mailpit: http://localhost:$$(sed -n 's/^MAILPIT_PORT=//p' .env)"
up:
	@test -f app/artisan || { echo "First run: make setup"; exit 1; }
	$(DC) --profile dev up -d --build
down:
	$(DC) --profile dev --profile workers --profile redis down --remove-orphans
restart: down up
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
	@mkdir -p backups
	$(DC) exec -T postgres sh -c 'pg_dump -U "$$POSTGRES_USER" "$$POSTGRES_DB"' > backups/pg-$$(date +%Y%m%d-%H%M%S).sql
destroy:
	@printf "Delete all local volumes? Type DELETE: "; read confirm; [ "$$confirm" = DELETE ]
	$(DC) --profile dev --profile workers --profile redis down --volumes --remove-orphans
