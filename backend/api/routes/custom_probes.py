"""
Custom probe management endpoints
"""
from fastapi import APIRouter, HTTPException, Path
from models.schemas import (
    CustomProbeCreateRequest,
    CustomProbeValidateRequest,
    CustomProbeValidationResponse,
    CustomProbe,
    CustomProbeListResponse,
    CustomProbeGetResponse,
)
from services.custom_probe_service import CustomProbeService
import logging

logger = logging.getLogger(__name__)

router = APIRouter()
custom_probe_service = CustomProbeService()


@router.post("/validate", response_model=CustomProbeValidationResponse)
async def validate_probe_code(request: CustomProbeValidateRequest):
    """
    Validate probe code syntax and structure

    Args:
        request: Probe code to validate

    Returns:
        Validation result with errors and warnings
    """
    try:
        return custom_probe_service.validate_code(request)
    except Exception as e:
        logger.error(f"Error validating probe code: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/templates/{template_type}")
async def get_probe_template(template_type: str = Path(..., pattern="^(minimal|basic|advanced)$")):
    """
    Get a probe code template

    Args:
        template_type: Type of template (minimal, basic, advanced)

    Returns:
        Template code as string
    """
    try:
        template = custom_probe_service.get_template(template_type)
        return {"template": template, "template_type": template_type}
    except Exception as e:
        logger.error(f"Error getting template: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("", response_model=CustomProbe, status_code=201)
async def create_custom_probe(request: CustomProbeCreateRequest):
    """
    Create a new custom probe

    Args:
        request: Probe creation request with name and code

    Returns:
        Created probe metadata
    """
    try:
        return custom_probe_service.create_probe(request)
    except ValueError as e:
        logger.warning(f"Invalid probe creation request: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Error creating custom probe: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("", response_model=CustomProbeListResponse)
async def list_custom_probes():
    """
    List all custom probes

    Returns:
        List of custom probe metadata
    """
    try:
        return custom_probe_service.list_probes()
    except Exception as e:
        logger.error(f"Error listing custom probes: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{name}", response_model=CustomProbeGetResponse)
async def get_custom_probe(name: str):
    """
    Get a specific custom probe

    Args:
        name: Probe class name

    Returns:
        Probe metadata and source code
    """
    try:
        return custom_probe_service.get_probe(name)
    except ValueError as e:
        logger.warning(f"Probe not found: {e}")
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Error getting custom probe: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.put("/{name}", response_model=CustomProbe)
async def update_custom_probe(name: str, request: CustomProbeCreateRequest):
    """
    Update an existing custom probe

    Args:
        name: Probe class name
        request: Updated probe code

    Returns:
        Updated probe metadata
    """
    try:
        return custom_probe_service.update_probe(name, request)
    except ValueError as e:
        logger.warning(f"Invalid probe update: {e}")
        raise HTTPException(status_code=400, detail=str(e))
    except Exception as e:
        logger.error(f"Error updating custom probe: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.delete("/{name}", status_code=204)
async def delete_custom_probe(name: str):
    """
    Delete a custom probe

    Args:
        name: Probe class name

    Returns:
        No content
    """
    try:
        custom_probe_service.delete_probe(name)
    except ValueError as e:
        logger.warning(f"Probe not found: {e}")
        raise HTTPException(status_code=404, detail=str(e))
    except Exception as e:
        logger.error(f"Error deleting custom probe: {e}")
        raise HTTPException(status_code=500, detail=str(e))
