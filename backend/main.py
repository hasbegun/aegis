"""
Garak Backend - FastAPI wrapper for garak CLI
Main entry point for the API server
"""
from contextlib import asynccontextmanager
import time
from fastapi import FastAPI, Request
from fastapi.middleware.cors import CORSMiddleware
from starlette.middleware.gzip import GZipMiddleware
from starlette.middleware.base import BaseHTTPMiddleware
from api.routes import scan, plugins, config, system, custom_probes, workflow, models
from config import settings
from services.model_discovery import initialize_model_discovery
import logging

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper()),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)


class RequestLoggingMiddleware(BaseHTTPMiddleware):
    """Middleware to log requests with timing information."""

    async def dispatch(self, request: Request, call_next):
        start_time = time.time()

        # Process request
        response = await call_next(request)

        # Calculate duration
        duration_ms = (time.time() - start_time) * 1000

        # Log request details (skip health checks to reduce noise)
        if request.url.path not in ["/health", "/"]:
            logger.info(
                f"{request.method} {request.url.path} - "
                f"Status: {response.status_code} - "
                f"Duration: {duration_ms:.2f}ms"
            )

        # Add timing header to response
        response.headers["X-Response-Time"] = f"{duration_ms:.2f}ms"

        return response


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Application lifespan handler for startup and shutdown events."""
    # Startup
    logger.info(f"Starting Garak Backend on {settings.host}:{settings.port}")

    # Initialize model discovery (fetches Ollama models)
    logger.info("Initializing model discovery...")
    await initialize_model_discovery()

    yield

    # Shutdown
    logger.info("Shutting down Garak Backend...")

# Create FastAPI app
app = FastAPI(
    title="Garak Backend API",
    description="REST API wrapper for the garak LLM vulnerability scanner",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc",
    lifespan=lifespan
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Configure GZip compression for responses > 500 bytes
app.add_middleware(GZipMiddleware, minimum_size=500)

# Add request logging middleware with timing
app.add_middleware(RequestLoggingMiddleware)

# Include routers
app.include_router(scan.router, prefix="/api/v1/scan", tags=["Scan"])
app.include_router(plugins.router, prefix="/api/v1/plugins", tags=["Plugins"])
app.include_router(config.router, prefix="/api/v1/config", tags=["Configuration"])
app.include_router(system.router, prefix="/api/v1/system", tags=["System"])
app.include_router(custom_probes.router, prefix="/api/v1/probes/custom", tags=["Custom Probes"])
app.include_router(workflow.router, tags=["Workflow"])
app.include_router(models.router, prefix="/api/v1/generators", tags=["Models"])


@app.get("/")
async def root():
    """Root endpoint - API health check"""
    return {
        "name": "Aegis Backend API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/api/docs"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


@app.get("/version")
async def version_info():
    """Version information endpoint"""
    import sys
    import subprocess

    # Get garak version
    garak_version = None
    try:
        result = subprocess.run(
            ["python", "-m", "garak", "--version"],
            capture_output=True,
            text=True,
            timeout=5
        )
        if result.returncode == 0:
            garak_version = result.stdout.strip()
    except Exception:
        pass

    return {
        "backend_version": "1.0.0",
        "api_version": "v1",
        "python_version": sys.version.split()[0],
        "garak_version": garak_version,
    }


if __name__ == "__main__":
    import uvicorn
    logger.info(f"Server configuration:")
    logger.info(f"  Host: {settings.host}")
    logger.info(f"  Port: {settings.port}")
    logger.info(f"  CORS Origins: {settings.cors_origins_list}")
    logger.info(f"  Log Level: {settings.log_level}")

    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=True,
        log_level=settings.log_level.lower()
    )
