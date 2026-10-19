SHELL := /bin/sh
.DEFAULT_GOAL := help
DC := docker compose
.PHONY: help setup up down restart logs ps shell artisan composer npm migrate test lint worker scheduler redis clean destroy config backup
help:
	@echo "Letsgo — Docker only (no Sail, no paid tooling)"
	@echo "  make setup       Bootstrap Laravel + Svelte starter, deps, DB, migration"
	@echo "  make up          Start app, PostgreSQL, Mailpit, Vite"
	@echo "  make down        Stop containers (keep data)"
	@echo "  make artisan CMD='route:list'    Run artisan"
	@echo "  make composer CMD='require ...'  Run Composer"
	@echo "  make npm CMD='run check'         Run npm"
	@echo "  make migrate / test / lint / logs / ps / shell"
	@echo "  make worker / scheduler / redis  Start optional services"
	@echo "  make backup      Dump local PostgreSQL to backups/"
	@echo "  make destroy     DELETE local volumes (confirmation required)"
setup:
	sh scripts/bootstrap.sh
	sh scripts/configure-app.sh
	$(DC) up -d --build postgres mailpit app web
	$(DC) exec -T app php artisan migrate --force
	$(DC) --profile dev up -d node
	@echo "App: http://localhost:$${HTTP_PORT:-8080} | Mailpit: http://localhost:$${MAILPIT_PORT:-8025}"
up:
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
	$(DC) run --rm --no-deps node npm $(CMD)
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
