# voip-lab Makefile: short aliases for common Docker Compose tasks.
# Run `make` or `make help` to list targets.

SHELL := /usr/bin/env bash
COMPOSE := docker compose
# Linux bridge name of the voip_net Docker network (set in docker-compose.yml).
BRIDGE := br-voip_net

.DEFAULT_GOAL := help
.PHONY: help up down build cli reload logs ps sngrep lint test-phase1

help: ## Show this help
	@grep -E '^[a-zA-Z0-9_-]+:.*?## ' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-14s\033[0m %s\n", $$1, $$2}'

up: ## Start the lab in the background
	$(COMPOSE) up -d

down: ## Stop and remove the lab containers (named volumes are kept)
	$(COMPOSE) down

build: ## Build the images (first Asterisk build takes ~5 min)
	$(COMPOSE) build

cli: ## Open the Asterisk CLI (verbose level 3)
	$(COMPOSE) exec asterisk asterisk -rvvv

reload: ## Re-render config from the repo and reload Asterisk (no restart)
	$(COMPOSE) exec asterisk entrypoint.sh render
	$(COMPOSE) exec asterisk asterisk -rx "core reload"

logs: ## Follow the logs of all services
	$(COMPOSE) logs -f --tail=100

ps: ## Show service status and health
	$(COMPOSE) ps

sngrep: ## Capture SIP on the lab bridge (needs sudo, run it yourself)
	sudo sngrep -d $(BRIDGE)

lint: ## Validate compose file and shell scripts
	$(COMPOSE) config --quiet
	@scripts=$$(git ls-files '*.sh'); \
	if [ -n "$$scripts" ]; then shellcheck $$scripts; else echo "no shell scripts yet"; fi

test-phase1: ## Run phase 1 smoke tests (SIPp)
	./tests/phase1/smoke.sh
