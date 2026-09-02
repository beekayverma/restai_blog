# REST AI blog. Run `make` to see what is available.

.DEFAULT_GOAL := help
.PHONY: help init up down logs build ab ab-stop test style backup restore clean

help:  ## Show this help
	@grep -hE '^[a-z-]+:.*?## ' $(MAKEFILE_LIST) \
	  | awk 'BEGIN{FS=":.*?## "}{printf "  \033[1m%-12s\033[0m %s\n", $$1, $$2}'

init:  ## Generate .env, start the stack, create the subscriber list
	@./scripts/init-env.sh || true
	@$(MAKE) up
	@./scripts/setup-list.sh
	@$(MAKE) build

up:  ## Start postgres, listmonk and caddy
	@docker compose -f compose/docker-compose.yml --env-file .env up -d
	@echo "site:     http://localhost:8080"
	@echo "listmonk: http://localhost:9000  (loopback only, admin is not public)"

down:  ## Stop the stack, keeping data volumes
	@docker compose -f compose/docker-compose.yml --env-file .env down

logs:  ## Follow container logs
	@docker compose -f compose/docker-compose.yml --env-file .env logs -f

build:  ## Build the site with the active theme
	@./scripts/build.sh

ab:  ## Build every candidate theme and serve them side by side
	@./scripts/ab-build.sh

ab-stop:  ## Stop the A/B preview servers
	@./scripts/ab-build.sh --stop

test:  ## Run the full acceptance suite
	@./tests/acceptance.sh

style:  ## Check for em dashes and committed secrets
	@./scripts/check-style.sh

backup:  ## Back up the subscriber database and uploads
	@./scripts/backup.sh

restore:  ## Restore a backup: make restore ARCHIVE=backups/xxx.tar.gz
	@test -n "$(ARCHIVE)" || { echo "usage: make restore ARCHIVE=backups/xxx.tar.gz"; exit 1; }
	@./scripts/restore.sh "$(ARCHIVE)"

clean:  ## Remove build output
	@rm -rf site/public dist
	@echo "removed site/public and dist"
