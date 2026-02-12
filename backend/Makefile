.PHONY: help test test-cli test-cache test-workflow test-logging test-statistics test-templates test-concurrent test-local clean check-env health \
        aegis-up aegis-down aegis-restart aegis-logs aegis-ps aegis-pull aegis-build \
        aegis-dev aegis-dev-down aegis-dev-logs aegis-dev-restart aegis-dev-attach \
        aegis-prod aegis-prod-down aegis-prod-logs \
        aegis-garak-shell aegis-garak-logs aegis-garak-health

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
	@echo "$(BLUE)Aegis - Available Commands$(NC)"
	@echo ""
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | awk 'BEGIN {FS = ":.*?## "}; {printf "  $(GREEN)%-25s$(NC) %s\n", $$1, $$2}'

test: ## Run all tests inside backend container
	@echo "$(BLUE)Running tests in container...$(NC)"
	$(DOCKER_COMPOSE) exec backend python -m pytest tests/test_cli_flags.py tests/test_report_cache.py tests/test_workflow_analyzer.py tests/test_logging_config.py tests/test_scan_statistics.py tests/test_config_templates.py tests/test_concurrent_scans.py -v
	@echo "$(GREEN)✓ All container tests passed$(NC)"

test-cli: ## Run CLI flag tests locally (no container needed)
	@echo "$(BLUE)Running CLI flag tests...$(NC)"
	python3 -m pytest tests/test_cli_flags.py -v
	@echo "$(GREEN)✓ CLI flag tests passed$(NC)"

test-cache: ## Run report cache tests locally (no container needed)
	@echo "$(BLUE)Running report cache tests...$(NC)"
	python3 -m pytest tests/test_report_cache.py -v
	@echo "$(GREEN)✓ Report cache tests passed$(NC)"

test-workflow: ## Run workflow analyzer tests locally (no container needed)
	@echo "$(BLUE)Running workflow analyzer tests...$(NC)"
	python3 -m pytest tests/test_workflow_analyzer.py -v
	@echo "$(GREEN)✓ Workflow analyzer tests passed$(NC)"

test-logging: ## Run logging config tests locally (no container needed)
	@echo "$(BLUE)Running logging config tests...$(NC)"
	python3 -m pytest tests/test_logging_config.py -v
	@echo "$(GREEN)✓ Logging config tests passed$(NC)"

test-statistics: ## Run scan statistics tests locally (no container needed)
	@echo "$(BLUE)Running scan statistics tests...$(NC)"
	python3 -m pytest tests/test_scan_statistics.py -v
	@echo "$(GREEN)✓ Scan statistics tests passed$(NC)"

test-templates: ## Run config template tests locally (no container needed)
	@echo "$(BLUE)Running config template tests...$(NC)"
	python3 -m pytest tests/test_config_templates.py -v
	@echo "$(GREEN)✓ Config template tests passed$(NC)"

test-concurrent: ## Run concurrent scan tests locally (no container needed)
	@echo "$(BLUE)Running concurrent scan tests...$(NC)"
	python3 -m pytest tests/test_concurrent_scans.py -v
	@echo "$(GREEN)✓ Concurrent scan tests passed$(NC)"

test-local: ## Run all local tests (no container needed)
	@echo "$(BLUE)Running all local tests...$(NC)"
	python3 -m pytest tests/test_cli_flags.py tests/test_report_cache.py tests/test_workflow_analyzer.py tests/test_logging_config.py tests/test_scan_statistics.py tests/test_config_templates.py tests/test_concurrent_scans.py -v
	@echo "$(GREEN)✓ All local tests passed$(NC)"

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

aegis-build: check-env ## Build images with docker compose
	@echo "$(BLUE)Building with docker compose...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) build --no-cache
	@echo "$(GREEN)✓ Build complete$(NC)"

aegis-up: check-env ## Start services (detached)
	@echo "$(BLUE)Starting services...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) up -d
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "$(YELLOW)  API: http://localhost:8888$(NC)"

aegis-up-build: check-env ## Build and start services
	@echo "$(BLUE)Building and starting services...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) up -d --build
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "$(YELLOW)  API: http://localhost:8888$(NC)"

aegis-up-attach: check-env ## Start services (attached, see logs)
	@echo "$(BLUE)Starting services (attached)...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) up --build

aegis-down: ## Stop and remove services
	@echo "$(BLUE)Stopping services...$(NC)"
	$(DOCKER_COMPOSE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

aegis-down-v: ## Stop services and remove volumes
	@echo "$(BLUE)Stopping services and removing volumes...$(NC)"
	$(DOCKER_COMPOSE) down -v
	@echo "$(GREEN)✓ Services and volumes removed$(NC)"

aegis-restart: ## Restart services
	@echo "$(BLUE)Restarting services...$(NC)"
	$(DOCKER_COMPOSE) restart
	@echo "$(GREEN)✓ Services restarted$(NC)"

aegis-logs: ## Show service logs (follow)
	$(DOCKER_COMPOSE) logs -f

aegis-logs-tail: ## Show last 100 lines of logs
	$(DOCKER_COMPOSE) logs --tail=100

aegis-ps: ## List running services
	@echo "$(BLUE)Running services:$(NC)"
	$(DOCKER_COMPOSE) ps

aegis-exec: ## Open shell in backend container
	$(DOCKER_COMPOSE) exec backend /bin/bash

aegis-pull: ## Pull latest images
	@echo "$(BLUE)Pulling images...$(NC)"
	$(DOCKER_COMPOSE) pull
	@echo "$(GREEN)✓ Images pulled$(NC)"

aegis-config: ## Validate and view compose config
	@echo "$(BLUE)Docker Compose Configuration:$(NC)"
	$(DOCKER_COMPOSE) config

# =============================================================================
# Docker Compose Development Mode (with hot reload)
# =============================================================================

aegis-dev: check-env ## Start in dev mode (mounts local code, hot reload)
	@echo "$(BLUE)Starting in development mode with hot reload...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml up -d --build
	@echo "$(GREEN)✓ Development server started$(NC)"
	@echo "$(YELLOW)  API: http://localhost:8888$(NC)"
	@echo "$(YELLOW)  Local code is mounted - changes apply automatically$(NC)"
	@echo "$(YELLOW)  Logs: make aegis-dev-logs$(NC)"

aegis-dev-attach: check-env ## Start in dev mode (attached, see logs)
	@echo "$(BLUE)Starting in development mode (attached)...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml up --build

aegis-dev-down: ## Stop dev mode services
	@echo "$(BLUE)Stopping development services...$(NC)"
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml down
	@echo "$(GREEN)✓ Development services stopped$(NC)"

aegis-dev-logs: ## Show dev mode logs
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml logs -f

aegis-dev-restart: ## Restart dev mode services
	@echo "$(BLUE)Restarting development services...$(NC)"
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.dev.yml restart
	@echo "$(GREEN)✓ Development services restarted$(NC)"

# =============================================================================
# Docker Compose Production Mode (with Ollama container)
# =============================================================================

aegis-prod: check-env ## Start in prod mode (backend + garak + ollama)
	@echo "$(BLUE)Starting production stack (backend + garak + ollama)...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.prod.yml up -d --build
	@echo "$(GREEN)✓ Production stack started$(NC)"
	@echo "$(YELLOW)  API: http://localhost:8888$(NC)"
	@echo "$(YELLOW)  Ollama: http://localhost:11434$(NC)"

aegis-prod-down: ## Stop production stack
	@echo "$(BLUE)Stopping production stack...$(NC)"
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.prod.yml down
	@echo "$(GREEN)✓ Production stack stopped$(NC)"

aegis-prod-logs: ## Show production stack logs
	$(DOCKER_COMPOSE) -f docker-compose.yml -f docker-compose.prod.yml logs -f

# =============================================================================
# Garak Service Commands
# =============================================================================

aegis-garak-shell: ## Open shell in garak service container
	$(DOCKER_COMPOSE) exec garak /bin/bash

aegis-garak-logs: ## Show garak service logs
	$(DOCKER_COMPOSE) logs -f garak

aegis-garak-health: ## Check garak service health
	@echo "$(BLUE)Checking garak service health...$(NC)"
	@$(DOCKER_COMPOSE) exec backend python -c "import urllib.request; print(urllib.request.urlopen('http://garak:9090/health').read().decode())" 2>/dev/null \
		&& echo "$(GREEN)✓ Garak service is healthy$(NC)" \
		|| echo "$(RED)✗ Garak service is not responding$(NC)"
