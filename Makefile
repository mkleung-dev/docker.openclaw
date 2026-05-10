.PHONY: help setup onboard onboard1 onboard2 run stop restart update logs status cli delete

BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[1;33m
RED := \033[0;31m
NC := \033[0m

help:
	@echo "$(BLUE)OpenClaw commands$(NC)"
	@echo ""
	@echo "$(GREEN)Setup:$(NC)"
	@echo "  make setup    - Validate docker and required env vars"
	@echo "  make onboard  - Full setup (onboard1 + onboard2)"
	@echo "  make onboard1 - Fix volume ownership and local onboarding"
	@echo "  make onboard2 - Configure gateway and list models"
	@echo ""
	@echo "$(GREEN)Lifecycle:$(NC)"
	@echo "  make run      - Start gateway service in detached mode"
	@echo "  make stop     - Stop gateway service"
	@echo "  make restart  - Restart gateway service"
	@echo "  make update   - Pull latest image and recreate services"
	@echo ""
	@echo "$(GREEN)Operations:$(NC)"
	@echo "  make logs     - Follow service logs"
	@echo "  make status   - Show service status"
	@echo "  make cli      - Attach to interactive CLI service"
	@echo "  make delete   - Remove services and volumes (destructive)"

setup:
	@echo "$(BLUE)Checking Docker availability...$(NC)"
	@docker --version >/dev/null
	@docker compose version >/dev/null
	@if [ ! -f .env ]; then \
		echo "$(RED).env not found. Create / update .env first.$(NC)"; \
		exit 1; \
	fi
	@if ! grep -q '^OPENCLAW_GATEWAY_TOKEN=' .env; then \
		echo "$(YELLOW)Warning: OPENCLAW_GATEWAY_TOKEN is not set in .env$(NC)"; \
	fi
	@echo "$(GREEN)Setup check completed$(NC)"

onboard1:
	@echo "$(BLUE)Running OpenClaw onboarding step 1 (volume + local setup)...$(NC)"
	@docker compose run --rm --no-deps --user root --entrypoint sh openclaw-gateway \
		-c "chown -R node:node /home/node/.openclaw"
	@docker compose run --rm --no-deps --entrypoint node openclaw-gateway \
		dist/index.js onboard --mode local --no-install-daemon
	@echo "$(GREEN)Onboarding step 1 complete$(NC)"

onboard2:
	@echo "$(BLUE)Running OpenClaw onboarding step 2 (config)...$(NC)"
	@docker compose run --rm --no-deps --entrypoint node openclaw-gateway \
		dist/index.js config set --batch-json '[{"path":"gateway.mode","value":"local"},{"path":"gateway.bind","value":"lan"},{"path":"gateway.controlUi.allowedOrigins","value":["http://localhost:18789","http://127.0.0.1:18789"]}]'
	@docker compose run --rm --no-deps --entrypoint node openclaw-gateway \
		dist/index.js config get models.providers
	@echo "$(GREEN)Onboarding step 2 complete$(NC)"

onboard: onboard1 onboard2
	@echo "$(GREEN)Full onboarding complete$(NC)"

run:
	@echo "$(BLUE)Starting OpenClaw gateway...$(NC)"
	@docker compose up -d openclaw-gateway
	@echo "$(GREEN)Gateway started$(NC)"
	@echo "Access: http://localhost:18789"

stop:
	@echo "$(YELLOW)Stopping OpenClaw services...$(NC)"
	@docker compose stop
	@echo "$(GREEN)Services stopped$(NC)"

restart:
	@echo "$(YELLOW)Restarting OpenClaw services...$(NC)"
	@docker compose restart
	@echo "$(GREEN)Services restarted$(NC)"

update:
	@echo "$(BLUE)Updating OpenClaw image...$(NC)"
	@docker compose pull
	@docker compose up -d openclaw-gateway
	@echo "$(GREEN)Update complete$(NC)"

logs:
	@docker compose logs -f

status:
	@docker compose ps

cli:
	@echo "$(BLUE)Attaching to OpenClaw CLI...$(NC)"
	@docker compose run --rm openclaw-cli

delete:
	@echo "$(RED)WARNING: This will remove OpenClaw services and volumes.$(NC)"
	@read -p "Type 'yes' to continue: " confirm; \
	if [ "$$confirm" = "yes" ]; then \
		docker compose down -v; \
		echo "$(GREEN)OpenClaw removed (including volume data).$(NC)"; \
	else \
		echo "$(YELLOW)Cancelled.$(NC)"; \
	fi

.DEFAULT_GOAL := help
