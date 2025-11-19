"""
System information endpoints
"""
from fastapi import APIRouter
from models.schemas import SystemInfoResponse
from services.garak_wrapper import garak_wrapper
import sys
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/info", response_model=SystemInfoResponse)
async def get_system_info():
    """
    Get system and garak installation information

    Returns:
        System information including garak version
    """
    garak_version = garak_wrapper.get_garak_version() or "Unknown"
    garak_installed = garak_wrapper.check_garak_installed()

    # Get available generators
    generators = garak_wrapper.list_plugins('generators') if garak_installed else []

    return SystemInfoResponse(
        garak_version=garak_version,
        python_version=f"{sys.version_info.major}.{sys.version_info.minor}.{sys.version_info.micro}",
        backend_version="1.0.0",
        garak_installed=garak_installed,
        available_generators=generators
    )


@router.get("/health")
async def health_check():
    """
    Health check endpoint

    Returns:
        Health status
    """
    garak_installed = garak_wrapper.check_garak_installed()

    return {
        "status": "healthy" if garak_installed else "degraded",
        "garak_available": garak_installed,
        "message": "OK" if garak_installed else "Garak not installed or not accessible"
    }
