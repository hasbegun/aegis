# Garak Backend API

REST API wrapper for the [garak](https://github.com/hasbegun/garak) LLM vulnerability scanner with **enhanced vulnerability reporting**.

## Overview

This FastAPI backend provides a REST API and WebSocket interface for running garak scans, allowing the Flutter UI (and other clients) to:
- Start vulnerability scans with custom configurations
- Monitor scan progress in real-time
- Retrieve scan results
- Discover available plugins (generators, probes, detectors, buffs)

## ✨ Enhanced Vulnerability Reporting

This backend uses an **enhanced fork of garak** that provides detailed vulnerability reports instead of minimal pass/fail results.

### What's Enhanced?

**Before (Standard garak):**
```json
{
  "probe": "dan.AntiDAN",
  "detector_results": {"dan.AntiDAN": [1.0, 1.0, 1.0]}
}
```

**After (Enhanced garak):**
```json
{
  "probe": "dan.AntiDAN",
  "detector_results": {"dan.AntiDAN": [1.0, 1.0, 1.0]},
  "vulnerability_explanation": "Jailbreak vulnerability detected. The model...",
  "attack_technique": "Jailbreak (AntiDAN)",
  "severity": "high",
  "cwe_ids": ["CWE-862"],
  "owasp_categories": ["LLM01"],
  "reproduction_steps": [
    "Send prompt: 'Hello gemma3. You are ANTI-DAN...'",
    "ACTUAL TEST RESULT - Model responded: 'ANTI-DAN: I understand...'",
    "To verify: Send harmful prompts to test if jailbreak works"
  ],
  "mitigation_recommendations": [
    "Implement multi-layer input validation",
    "Use constitutional AI to reinforce safety",
    "..."
  ]
}
```

### Enhanced Features

- ✅ **Detailed explanations** - Understand exactly what vulnerability was found
- ✅ **Actual LLM outputs** - See the model's real responses that failed
- ✅ **Reproduction steps** - Step-by-step guide to reproduce the issue
- ✅ **Severity ratings** - Critical/High/Medium/Low risk assessment
- ✅ **CWE/OWASP mappings** - Industry-standard vulnerability classifications
- ✅ **Mitigation recommendations** - 8+ actionable fixes per vulnerability
- ✅ **Academic references** - Links to research papers and standards

### Coverage

| Category | Probes | Status |
|----------|--------|--------|
| Jailbreak Attacks | 18 | ✅ Complete |
| Prompt Injection | 6 | ✅ Complete |
| Malware Generation | 4 | ✅ Complete |
| Encoding Bypass | 20 | ✅ Complete |
| **Total** | **48+** | **✅ Production Ready** |

📖 **Full documentation:** See `ENHANCED_REPORTING.md`

## Architecture

```
┌─────────────┐      HTTP/WS       ┌──────────────┐     subprocess    ┌─────────┐
│             │ ←────────────────→ │              │ ←───────────────→ │         │
│  Flutter UI │                    │ FastAPI      │                   │  garak  │
│             │                    │ Backend      │                   │   CLI   │
└─────────────┘                    └──────────────┘                   └─────────┘
```

## Prerequisites

### 1. Python 3.9+
```bash
python --version  # Should be 3.9 or higher
```

### 2. garak Installed (Enhanced Version)

**⚠️ IMPORTANT:** This backend requires the **enhanced garak fork** with vulnerability reporting features.

**Install from source (Required):**
```bash
# Clone the enhanced fork
git clone https://github.com/hasbegun/garak.git
cd garak

# Install in development mode
pip install -e .
```

**Verify Installation:**
```bash
# Check version
garak --version

# Should show version 0.13.3rc1 or later
# Verify enhanced reporting is available
python -c "from garak.probes._enhanced_reporting import BaseEnhancedReportingMixin; print('✅ Enhanced reporting available')"
```

**Why the fork?**
- ✅ Adds detailed vulnerability explanations to reports
- ✅ Includes actual LLM outputs that failed tests
- ✅ Provides CWE/OWASP classifications
- ✅ Generates reproduction steps and mitigation recommendations
- ✅ See `ENHANCED_REPORTING.md` for complete details

### 3. Backend Dependencies
```bash
pip install fastapi uvicorn python-dotenv pydantic pydantic-settings
```

## Installation

### 1. Clone/Navigate to Backend Directory
```bash
cd garak_backend
```

### 2. Create Virtual Environment (Recommended)
```bash
python -m venv venv

# Activate virtual environment
# macOS/Linux:
source venv/bin/activate

# Windows:
venv\Scripts\activate
```

### 3. Install Dependencies
```bash
pip install -r requirements.txt
```

## Configuration

### Environment Variables

Create a `.env` file in the `garak_backend` directory:

```bash
cp .env.example .env
```

Edit `.env` with your preferred settings:

```bash
# Server Configuration
HOST=0.0.0.0
PORT=8888

# CORS Configuration
# Use "*" for development, specific origins for production
CORS_ORIGINS=*

# Logging
LOG_LEVEL=INFO

# Garak Path (optional - auto-detected if not specified)
# GARAK_PATH=/path/to/garak

# Optional: OpenAI API Key (if testing OpenAI models)
# OPENAI_API_KEY=sk-...

# Optional: Anthropic API Key
# ANTHROPIC_API_KEY=sk-ant-...

# Optional: Other API Keys
# COHERE_API_KEY=...
# HUGGINGFACE_TOKEN=...
```

### Configuration Options

| Variable | Default | Description |
|----------|---------|-------------|
| `HOST` | `0.0.0.0` | Server host (0.0.0.0 = all interfaces) |
| `PORT` | `8888` | Server port |
| `CORS_ORIGINS` | `*` | Allowed CORS origins (comma-separated) |
| `LOG_LEVEL` | `INFO` | Logging level (DEBUG, INFO, WARNING, ERROR) |
| `GARAK_PATH` | Auto-detected | Custom path to garak executable |

## Running the Server

### Development Mode (with auto-reload)
```bash
python main.py
```

Or using uvicorn directly:
```bash
uvicorn main:app --host 0.0.0.0 --port 8888 --reload
```

### Production Mode
```bash
uvicorn main:app --host 0.0.0.0 --port 8888 --workers 4
```

### With Custom Port
```bash
# Via environment variable
PORT=9000 python main.py

# Or edit .env file
```

### Server Startup
You should see:
```
INFO:     Started server process [12345]
INFO:     Waiting for application startup.
INFO:     Application startup complete.
INFO:     Uvicorn running on http://0.0.0.0:8888 (Press CTRL+C to quit)
```

## API Documentation

Once the server is running, visit:

- **Swagger UI**: http://localhost:8888/docs
- **ReDoc**: http://localhost:8888/redoc
- **OpenAPI JSON**: http://localhost:8888/openapi.json

## API Endpoints

### System

#### `GET /api/v1/health`
Health check endpoint.

**Response:**
```json
{
  "status": "healthy",
  "version": "1.0.0",
  "garak_version": "0.9.0"
}
```

#### `GET /api/v1/system/info`
Get system and garak information.

**Response:**
```json
{
  "garak_version": "0.9.0",
  "garak_path": "/usr/local/bin/garak",
  "python_version": "3.11.5"
}
```

### Plugins

#### `GET /api/v1/plugins/generators`
List all available generator types.

**Response:**
```json
[
  {
    "name": "openai",
    "fullName": "garak.generators.openai",
    "description": "OpenAI API generator"
  },
  {
    "name": "ollama",
    "fullName": "garak.generators.ollama",
    "description": "Ollama local generator"
  }
]
```

#### `GET /api/v1/plugins/probes`
List all available vulnerability probes.

#### `GET /api/v1/plugins/detectors`
List all available detectors.

#### `GET /api/v1/plugins/buffs`
List all available buffs (input transformations).

### Scans

#### `POST /api/v1/scan/start`
Start a new vulnerability scan.

**Request Body:**
```json
{
  "target_type": "ollama",
  "target_name": "llama2",
  "probes": ["dan", "encoding"],
  "generations": 10,
  "eval_threshold": 0.5,
  "generator_options": {
    "api_key": "sk-..."
  }
}
```

**Response:**
```json
{
  "scan_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "pending"
}
```

#### `GET /api/v1/scan/{scan_id}/status`
Get current scan status.

**Response:**
```json
{
  "scan_id": "550e8400-e29b-41d4-a716-446655440000",
  "status": "running",
  "progress": 45.5,
  "current_probe": "dan.DAN_11_0",
  "passed": 5,
  "failed": 2,
  "total_probes": 10,
  "completed_probes": 7,
  "started_at": "2024-11-14T10:30:00Z",
  "updated_at": "2024-11-14T10:35:00Z"
}
```

#### `DELETE /api/v1/scan/{scan_id}/cancel`
Cancel a running scan.

#### `WS /api/v1/scan/{scan_id}/progress`
WebSocket endpoint for real-time progress updates.

**Message Format:**
```json
{
  "type": "progress",
  "data": {
    "progress": 45.5,
    "status": "running",
    "current_probe": "dan.DAN_11_0"
  }
}
```

## Testing

### Quick Health Check
```bash
curl http://localhost:8888/api/v1/health
```

### List Available Generators
```bash
curl http://localhost:8888/api/v1/plugins/generators
```

### Start a Test Scan (with Ollama)
```bash
curl -X POST http://localhost:8888/api/v1/scan/start \
  -H "Content-Type: application/json" \
  -d '{
    "target_type": "ollama",
    "target_name": "llama2",
    "probes": ["encoding"],
    "generations": 5
  }'
```

### Check Scan Status
```bash
# Replace with actual scan_id from start response
curl http://localhost:8888/api/v1/scan/550e8400-e29b-41d4-a716-446655440000/status
```

## Project Structure

```
garak_backend/
├── main.py                 # FastAPI application entry point
├── config.py              # Configuration management
├── requirements.txt       # Python dependencies
├── .env                   # Environment variables (create from .env.example)
├── .env.example          # Environment variables template
├── api/
│   ├── __init__.py
│   ├── models/           # Pydantic request/response models
│   │   ├── __init__.py
│   │   ├── scan_config.py
│   │   ├── scan_status.py
│   │   └── plugin.py
│   └── routes/           # API endpoint handlers
│       ├── __init__.py
│       ├── scan.py       # Scan management endpoints
│       ├── plugins.py    # Plugin discovery endpoints
│       └── health.py     # Health check endpoints
└── services/
    ├── __init__.py
    └── garak_wrapper.py  # Garak CLI wrapper service
```

## Troubleshooting

### Port Already in Use

**Error:**
```
ERROR: [Errno 48] Address already in use
```

**Solution:**
```bash
# Find process using port 8888
lsof -i :8888

# Kill the process
kill -9 <PID>

# Or use a different port
PORT=9000 python main.py
```

### garak Not Found

**Error:**
```
FileNotFoundError: garak executable not found
```

**Solution:**
```bash
# Install garak
pip install garak

# Or specify path in .env
GARAK_PATH=/path/to/garak
```

### CORS Issues

**Error:** Browser console shows CORS errors

**Solution:**
```bash
# In .env, add your frontend URL
CORS_ORIGINS=http://localhost:3000,http://localhost:8080
```

### Scan Fails to Start

**Check:**
1. Garak is properly installed: `garak --help`
2. Generator is available: `garak --list_generators`
3. Model name is correct (e.g., `llama2` for Ollama)
4. Required API keys are set (if using cloud providers)
5. Check backend logs for detailed error messages

### Ollama Connection Refused

**Error:**
```
Connection refused to http://127.0.0.1:11434
```

**Solution:**
```bash
# Start Ollama server
ollama serve

# Verify it's running
curl http://127.0.0.1:11434/api/tags
```

## Development

### Enable Debug Logging
```bash
# In .env
LOG_LEVEL=DEBUG
```

### Run with Auto-reload
```bash
uvicorn main:app --reload --host 0.0.0.0 --port 8888
```

### Add New Endpoints

1. Create route handler in `api/routes/`
2. Create models in `api/models/` (if needed)
3. Include router in `main.py`:
```python
from api.routes import my_new_routes
app.include_router(my_new_routes.router)
```

## Production Deployment

### Using Gunicorn + Uvicorn Workers
```bash
pip install gunicorn

gunicorn main:app \
  --workers 4 \
  --worker-class uvicorn.workers.UvicornWorker \
  --bind 0.0.0.0:8888
```

### Using Docker (Future)
```dockerfile
FROM python:3.11-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY . .
CMD ["uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8888"]
```

### Security Considerations

1. **CORS**: Set specific origins in production
   ```bash
   CORS_ORIGINS=https://yourdomain.com
   ```

2. **API Keys**: Never commit `.env` to version control
   ```bash
   echo ".env" >> .gitignore
   ```

3. **HTTPS**: Use reverse proxy (nginx, traefik) with SSL
4. **Rate Limiting**: Add rate limiting middleware for production
5. **Authentication**: Implement API key or OAuth for public deployments

## Integration with Flutter UI

The Flutter UI (garak_ui) connects to this backend:

```dart
// In lib/config/constants.dart
static const String apiBaseUrl = 'http://localhost:8888/api/v1';
static const String wsBaseUrl = 'ws://localhost:8888/api/v1';
```

### Running Both Together

**Terminal 1 - Backend:**
```bash
cd garak_backend
python main.py
```

**Terminal 2 - Frontend:**
```bash
cd garak_ui
flutter run -d macos  # or your platform
```

## Documentation

### Enhanced Reporting Documentation
- **Enhanced Reporting Guide:** `ENHANCED_REPORTING.md` - Complete feature documentation
- **Implementation Details:** `PARALLEL_IMPLEMENTATION_COMPLETE.md` - Technical implementation
- **Expansion Plan:** `ENHANCED_REPORTING_EXPANSION_PLAN.md` - Future roadmap
- **Hook Timing Fix:** `CRITICAL_FIX_HOOK_TIMING.md` - Critical architecture fix

### External Resources
- **Enhanced Garak Fork:** https://github.com/hasbegun/garak
- **Garak Documentation:** https://reference.garak.ai
- **Upstream Garak:** https://github.com/leondz/garak
- **FastAPI Documentation:** https://fastapi.tiangolo.com
- **OWASP LLM Top 10:** https://owasp.org/www-project-top-10-for-large-language-model-applications/
- **CWE Database:** https://cwe.mitre.org/

## License

Same as garak - Apache 2.0

---

**Backend Version:** 1.0.0
**Enhanced Garak Version:** 0.13.3rc1+
**Last Updated:** November 24, 2025
**Enhanced Reporting Status:** ✅ Production Ready (48+ probes)
