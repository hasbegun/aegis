"""
Garak Backend - FastAPI wrapper for garak CLI
Main entry point for the API server
"""
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from api.routes import scan, plugins, config, system, custom_probes, workflow, models
from config import settings
import logging

# Configure logging
logging.basicConfig(
    level=getattr(logging, settings.log_level.upper()),
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)

logger = logging.getLogger(__name__)
logger.info(f"Starting Garak Backend on {settings.host}:{settings.port}")

# Create FastAPI app
app = FastAPI(
    title="Garak Backend API",
    description="REST API wrapper for the garak LLM vulnerability scanner",
    version="1.0.0",
    docs_url="/api/docs",
    redoc_url="/api/redoc"
)

# Configure CORS
app.add_middleware(
    CORSMiddleware,
    allow_origins=settings.cors_origins_list,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

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
        "name": "Garak Backend API",
        "version": "1.0.0",
        "status": "running",
        "docs": "/api/docs"
    }


@app.get("/health")
async def health_check():
    """Health check endpoint"""
    return {"status": "healthy"}


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
