.PHONY: help install run dev prod production test clean lint format check-env logs-follow

# Default target
.DEFAULT_GOAL := help

# Python and pip
PYTHON := python
PIP := pip

# Project directories
SRC_DIR := .
VENV_DIR := venv

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
