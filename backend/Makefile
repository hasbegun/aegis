.PHONY: help install run dev prod production test clean lint format check-env logs-follow \
        docker-build docker-run docker-up docker-down docker-logs docker-shell docker-clean docker-rebuild \
        compose-up compose-down compose-restart compose-logs compose-ps compose-pull compose-build \
        compose-dev compose-dev-down compose-dev-logs

# Default target
.DEFAULT_GOAL := help

# Python and pip
PYTHON := python
PIP := pip

# Project directories
SRC_DIR := .
VENV_DIR := venv

# Docker configuration
DOCKER_IMAGE := aegis-backend
DOCKER_CONTAINER := aegis-backend
# Use 'docker compose' (V2) if available, fallback to 'docker-compose' (V1)
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

install: ## Install Python dependencies
	@echo "$(BLUE)Installing dependencies...$(NC)"
	$(PIP) install -r requirements.txt
	@echo "$(GREEN)✓ Dependencies installed$(NC)"

run: check-env ## Run the backend server
	@echo "$(BLUE)Starting Garak Backend...$(NC)"
	uvicorn main:app --host 0.0.0.0 --port 8888

dev: check-env ## Run the backend in development mode (with auto-reload)
	@echo "$(BLUE)Starting Garak Backend in development mode...$(NC)"
	uvicorn main:app --host 0.0.0.0 --port 8888 --reload --log-level debug

prod: production ## Alias for production

production: check-env stop ## Run the backend in production mode (background with logging)
	@echo "$(BLUE)Starting Garak Backend in production mode...$(NC)"
	@nohup uvicorn main:app --host 0.0.0.0 --port 8888 --workers 4 --log-level info > backend.log 2>&1 &
	@sleep 2
	@if lsof -ti:8888 > /dev/null 2>&1; then \
		PID=$$(lsof -ti:8888); \
		echo "$(GREEN)✓ Backend started in background with 4 workers (PID: $$PID)$(NC)"; \
		echo "$(YELLOW)  Logs: tail -f backend.log$(NC)"; \
		echo "$(YELLOW)  Stop: make stop$(NC)"; \
	else \
		echo "$(RED)✗ Failed to start backend$(NC)"; \
		echo "$(YELLOW)Check backend.log for errors$(NC)"; \
	fi

test: ## Run tests (if any)
	@echo "$(BLUE)Running tests...$(NC)"
	$(PYTHON) -m pytest tests/ -v || echo "$(YELLOW)No tests found$(NC)"

clean: ## Clean up Python cache files
	@echo "$(BLUE)Cleaning up...$(NC)"
	find . -type d -name "__pycache__" -exec rm -rf {} + 2>/dev/null || true
	find . -type f -name "*.pyc" -delete
	find . -type f -name "*.pyo" -delete
	find . -type f -name "*.log" -delete
	find . -type d -name ".pytest_cache" -exec rm -rf {} + 2>/dev/null || true
	@echo "$(GREEN)✓ Cleanup complete$(NC)"

lint: ## Run linting with flake8
	@echo "$(BLUE)Running linter...$(NC)"
	$(PYTHON) -m flake8 . --exclude=venv,__pycache__,.git --max-line-length=120 || echo "$(YELLOW)flake8 not installed. Run: pip install flake8$(NC)"

format: ## Format code with black
	@echo "$(BLUE)Formatting code...$(NC)"
	$(PYTHON) -m black . --exclude venv || echo "$(YELLOW)black not installed. Run: pip install black$(NC)"

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

venv: ## Create a virtual environment
	@echo "$(BLUE)Creating virtual environment...$(NC)"
	$(PYTHON) -m venv $(VENV_DIR)
	@echo "$(GREEN)✓ Virtual environment created$(NC)"
	@echo "$(YELLOW)Activate it with: source $(VENV_DIR)/bin/activate$(NC)"

health: ## Check backend health
	@echo "$(BLUE)Checking backend health...$(NC)"
	@curl -s http://localhost:8888/health | python -m json.tool || echo "$(RED)Backend is not running$(NC)"

status: ## Show backend status
	@echo "$(BLUE)Backend Status:$(NC)"
	@lsof -ti:8888 > /dev/null 2>&1 && echo "$(GREEN)✓ Backend is running on port 8888$(NC)" || echo "$(YELLOW)✗ Backend is not running$(NC)"

stop: ## Stop the backend server
	@echo "$(BLUE)Stopping backend...$(NC)"
	@lsof -ti:8888 | xargs kill -9 2>/dev/null && echo "$(GREEN)✓ Backend stopped$(NC)" || echo "$(YELLOW)Backend was not running$(NC)"

restart: stop run ## Restart the backend server

logs: ## Show backend logs (if using systemd or similar)
	@echo "$(BLUE)Recent logs:$(NC)"
	@tail -n 50 backend.log 2>/dev/null || echo "$(YELLOW)No log file found$(NC)"

logs-follow: ## Follow backend logs in real-time
	@echo "$(BLUE)Following backend logs (Ctrl+C to stop)...$(NC)"
	@tail -f backend.log 2>/dev/null || echo "$(YELLOW)No log file found$(NC)"

requirements: ## Generate/update requirements.txt
	@echo "$(BLUE)Generating requirements.txt...$(NC)"
	$(PIP) freeze > requirements.txt
	@echo "$(GREEN)✓ requirements.txt updated$(NC)"

info: ## Show project information
	@echo "$(BLUE)Garak Backend Information$(NC)"
	@echo "  Python version: $$($(PYTHON) --version)"
	@echo "  Pip version: $$($(PIP) --version)"
	@echo "  Server: Uvicorn (ASGI)"
	@echo "  Backend host: 0.0.0.0"
	@echo "  Backend port: 8888"
	@echo "  Production workers: 4"
	@echo "  Config file: .env"

# =============================================================================
# Docker Commands
# =============================================================================

docker-build: check-env ## Build the Docker image
	@echo "$(BLUE)Building Docker image...$(NC)"
	docker build -t $(DOCKER_IMAGE) .
	@echo "$(GREEN)✓ Docker image built: $(DOCKER_IMAGE)$(NC)"

docker-run: check-env docker-build ## Build and run container (standalone)
	@echo "$(BLUE)Running Docker container...$(NC)"
	@mkdir -p garak_reports
	docker run -d \
		--name $(DOCKER_CONTAINER) \
		-p 8888:8888 \
		-v "$$(pwd)/garak_reports:/data/garak_reports" \
		--env-file .env \
		$(DOCKER_IMAGE)
	@echo "$(GREEN)✓ Container started: $(DOCKER_CONTAINER)$(NC)"
	@echo "$(YELLOW)  API: http://localhost:8888$(NC)"
	@echo "$(YELLOW)  Logs: make docker-logs$(NC)"
	@echo "$(YELLOW)  Stop: make docker-stop$(NC)"

docker-up: check-env ## Start services with docker-compose
	@echo "$(BLUE)Starting services with docker-compose...$(NC)"
	@mkdir -p garak_reports
	$(DOCKER_COMPOSE) up -d --build
	@echo "$(GREEN)✓ Services started$(NC)"
	@echo "$(YELLOW)  API: http://localhost:8888$(NC)"
	@echo "$(YELLOW)  Logs: make docker-logs$(NC)"
	@echo "$(YELLOW)  Stop: make docker-down$(NC)"

docker-down: ## Stop and remove docker-compose services
	@echo "$(BLUE)Stopping docker-compose services...$(NC)"
	$(DOCKER_COMPOSE) down
	@echo "$(GREEN)✓ Services stopped$(NC)"

docker-stop: ## Stop the standalone Docker container
	@echo "$(BLUE)Stopping Docker container...$(NC)"
	@docker stop $(DOCKER_CONTAINER) 2>/dev/null && docker rm $(DOCKER_CONTAINER) 2>/dev/null \
		&& echo "$(GREEN)✓ Container stopped and removed$(NC)" \
		|| echo "$(YELLOW)Container was not running$(NC)"

docker-logs: ## Show Docker container logs
	@echo "$(BLUE)Docker container logs:$(NC)"
	@$(DOCKER_COMPOSE) logs -f 2>/dev/null || docker logs -f $(DOCKER_CONTAINER) 2>/dev/null || echo "$(YELLOW)No running container found$(NC)"

docker-shell: ## Open a shell in the running container
	@echo "$(BLUE)Opening shell in container...$(NC)"
	@docker exec -it $(DOCKER_CONTAINER) /bin/bash 2>/dev/null || $(DOCKER_COMPOSE) exec backend /bin/bash 2>/dev/null || echo "$(RED)No running container found$(NC)"

docker-status: ## Show Docker container status
	@echo "$(BLUE)Docker Status:$(NC)"
	@docker ps --filter "name=$(DOCKER_CONTAINER)" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" 2>/dev/null || echo "$(YELLOW)No containers found$(NC)"
	@echo ""
	@echo "$(BLUE)Docker Compose Status:$(NC)"
	@$(DOCKER_COMPOSE) ps 2>/dev/null || echo "$(YELLOW)No compose services found$(NC)"

docker-clean: ## Remove Docker image and containers
	@echo "$(BLUE)Cleaning Docker resources...$(NC)"
	@docker stop $(DOCKER_CONTAINER) 2>/dev/null || true
	@docker rm $(DOCKER_CONTAINER) 2>/dev/null || true
	@docker rmi $(DOCKER_IMAGE) 2>/dev/null || true
	@$(DOCKER_COMPOSE) down --rmi local 2>/dev/null || true
	@echo "$(GREEN)✓ Docker resources cleaned$(NC)"

docker-rebuild: docker-clean docker-up ## Clean and rebuild everything

docker-health: ## Check Docker container health
	@echo "$(BLUE)Checking container health...$(NC)"
	@curl -s http://localhost:8888/health | python -m json.tool 2>/dev/null \
		&& echo "$(GREEN)✓ Backend is healthy$(NC)" \
		|| echo "$(RED)✗ Backend is not responding$(NC)"

# =============================================================================
# Docker Compose Commands (Aliases)
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
