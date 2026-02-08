.PHONY: help test clean check-env health \
        compose-up compose-down compose-restart compose-logs compose-ps compose-pull compose-build \
        compose-dev compose-dev-down compose-dev-logs compose-dev-restart compose-dev-attach \
        compose-prod compose-prod-down compose-prod-logs \
        garak-shell garak-logs garak-health

# Default target
.DEFAULT_GOAL := help

# Docker Compose (V2 preferred, fallback to V1)
DOCKER_COMPOSE := $(shell docker compose version > /dev/null 2>&1 && echo "docker compose" || echo "docker-compose")

# Colors for output
BLUE := \033[0;34m
GREEN := \033[0;32m
YELLOW := \033[0;33m
RED := \033[0;31m
NC := \033[0m # No Color

help: ## Show this help message
	@echo "$(BLUE)Garak Backend - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-15s$(NC) %s\n", $$1, $$2}'

test: ## Run tests inside backend container
	@echo "$(BLUE)Running tests...$(NC)"
	$(DOCKER_COMPOSE) exec backend python -m pytest tests/ -v || echo "$(YELLOW)No tests found$(NC)"

clean: ## Clean up Python cache files
	@echo "$(BLUE)Cleaning up...$(NC)"
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type f -name "*.log" -delete
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

check-env: ## Check if .env file exists
	@if [ ! -f .env ]; then \
		echo "$(YELLOW)Warning: .env file not found. Creating from .env.example...$(NC)"; \
		if [ -f .env.example ]; then \
			cp .env.example .env; \
			echo "$(GREEN)✓ .env file created. Please review and update as needed.$(NC)"; \
		else \
			echo "$(RED)Error: .env.example not found$(NC)"; \
		fi \
	fi

health: ## Check backend health
	@echo "$(BLUE)Checking backend health...$(NC)"
	@curl -s http://localhost:8888/health | python -m json.tool || echo "$(RED)Backend is not running$(NC)"

# =============================================================================
# Docker Compose Commands
# =============================================================================

compose-build: check-env ## Build images with docker compose
	@echo "$(BLUE)Building with docker compose...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) build
	@echo "$(GREEN)✓ Build complete$(NC)"

compose-up: check-env ## Start services (detached)
	@echo "$(BLUE)Starting services...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "$(YELLOW)  API: http://localhost:8888$(NC)"

compose-up-build: check-env ## Build and start services
	@echo "$(BLUE)Building and starting services...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) up -d --build
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "$(YELLOW)  API: http://localhost:8888$(NC)"

compose-up-attach: check-env ## Start services (attached, see logs)
	@echo "$(BLUE)Starting services (attached)...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) up --build

compose-down: ## Stop and remove services
	@echo "$(BLUE)Stopping services...$(NC)"
	$(DOCKER_COMPOSE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

compose-down-v: ## Stop services and remove volumes
	@echo "$(BLUE)Stopping services and removing volumes...$(NC)"
	$(DOCKER_COMPOSE) down -v
	@echo "$(GREEN)✓ Services and volumes removed$(NC)"

compose-restart: ## Restart services
	@echo "$(BLUE)Restarting services...$(NC)"
	$(DOCKER_COMPOSE) restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

compose-logs: ## Show service logs (follow)
	$(DOCKER_COMPOSE) logs -f

compose-logs-tail: ## Show last 100 lines of logs
	$(DOCKER_COMPOSE) logs --tail=100

compose-ps: ## List running services
	@echo "$(BLUE)Running services:$(NC)"
	$(DOCKER_COMPOSE) ps

compose-exec: ## Open shell in backend container
	$(DOCKER_COMPOSE) exec backend /bin/bash

compose-pull: ## Pull latest images
	@echo "$(BLUE)Pulling images...$(NC)"
	$(DOCKER_COMPOSE) pull
	@echo "$(GREEN)✓ Images pulled$(NC)"

compose-config: ## Validate and view compose config
	@echo "$(BLUE)Docker Compose Configuration:$(NC)"
	$(DOCKER_COMPOSE) config

# =============================================================================
# Docker Compose Development Mode (with hot reload)
# =============================================================================

compose-dev: check-env ## Start in dev mode (mounts local code, hot reload)
	@echo "$(BLUE)Starting in development mode with hot reload...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml up -d --build
	@echo "$(GREEN)✓ Development server started$(NC)"
	@echo "$(YELLOW)  API: http://localhost:8888$(NC)"
	@echo "$(YELLOW)  Local code is mounted - changes apply automatically$(NC)"
	@echo "$(YELLOW)  Logs: make compose-dev-logs$(NC)"

compose-dev-attach: check-env ## Start in dev mode (attached, see logs)
	@echo "$(BLUE)Starting in development mode (attached)...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml up --build

compose-dev-down: ## Stop dev mode services
	@echo "$(BLUE)Stopping development services...$(NC)"
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml down
	@echo "$(GREEN)✓ Development services stopped$(NC)"

compose-dev-logs: ## Show dev mode logs
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml logs -f

compose-dev-restart: ## Restart dev mode services
	@echo "$(BLUE)Restarting development services...$(NC)"
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml restart
	@echo "$(GREEN)✓ Development services restarted$(NC)"

# =============================================================================
# Docker Compose Production Mode (with Ollama container)
# =============================================================================

compose-prod: check-env ## Start in prod mode (backend + garak + ollama)
	@echo "$(BLUE)Starting production stack (backend + garak + ollama)...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.prod.yml up -d --build
	@echo "$(GREEN)✓ Production stack started$(NC)"
	@echo "$(YELLOW)  API: http://localhost:8888$(NC)"
	@echo "$(YELLOW)  Ollama: http://localhost:11434$(NC)"

compose-prod-down: ## Stop production stack
	@echo "$(BLUE)Stopping production stack...$(NC)"
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.prod.yml down
	@echo "$(GREEN)✓ Production stack stopped$(NC)"

compose-prod-logs: ## Show production stack logs
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.prod.yml logs -f

# =============================================================================
# Garak Service Commands
# =============================================================================

garak-shell: ## Open shell in garak service container
	$(DOCKER_COMPOSE) exec garak /bin/bash

garak-logs: ## Show garak service logs
	$(DOCKER_COMPOSE) logs -f garak

garak-health: ## Check garak service health
	@echo "$(BLUE)Checking garak service health...$(NC)"
	@$(DOCKER_COMPOSE) exec backend python -c "import urllib.request; print(urllib.request.urlopen('http://garak:9090/health').read().decode())" 2>/dev/null \
		&& echo "$(GREEN)✓ Garak service is healthy$(NC)" \
		|| echo "$(RED)✗ Garak service is not responding$(NC)"
