"""
Configuration management endpoints
"""
from fastapi import APIRouter, HTTPException
from models.schemas import (
    ConfigPreset,
    ConfigTemplateSave,
    ConfigTemplate,
    ConfigTemplateListResponse,
)
from services.config_template_store import config_template_store
from typing import List, Optional
import logging

logger = logging.getLogger(__name__)

router = APIRouter()

# Predefined configuration presets
PRESETS = {
    "fast": {
        "name": "fast",
        "description": "Quick scan with parallel execution",
        "config": {
            "generations": 5,
            "eval_threshold": 0.5,
            "parallel_requests": 10,
            "parallel_attempts": 16,
            "probes": ["dan", "encoding"]
        }
    },
    "default": {
        "name": "default",
        "description": "Balanced scan with common probes",
        "config": {
            "generations": 10,
            "eval_threshold": 0.5,
            "parallel_attempts": 4,
            "probes": ["dan", "encoding", "promptinject", "toxicity"]
        }
    },
    "full": {
        "name": "full",
        "description": "Comprehensive scan with all probes",
        "config": {
            "generations": 20,
            "eval_threshold": 0.5,
            "probes": ["all"],
            "parallel_attempts": 8
        }
    },
    "owasp": {
        "name": "owasp",
        "description": "OWASP LLM Top 10 focused scan",
        "config": {
            "generations": 10,
            "eval_threshold": 0.5,
            "parallel_attempts": 4,
            "probe_tags": "owasp:llm"
        }
    }
}


@router.get("/presets", response_model=List[ConfigPreset])
async def list_presets():
    """
    Get list of available configuration presets

    Returns:
        List of configuration presets
    """
    return [
        ConfigPreset(**preset)
        for preset in PRESETS.values()
    ]


@router.get("/presets/{preset_name}", response_model=ConfigPreset)
async def get_preset(preset_name: str):
    """
    Get a specific configuration preset

    Args:
        preset_name: Name of the preset

    Returns:
        Configuration preset
    """
    preset = PRESETS.get(preset_name)

    if not preset:
        raise HTTPException(
            status_code=404,
            detail=f"Preset '{preset_name}' not found"
        )

    return ConfigPreset(**preset)


@router.post("/validate")
async def validate_config(config: dict):
    """
    Validate a configuration before running

    Args:
        config: Configuration dictionary to validate

    Returns:
        Validation result
    """
    # Basic validation
    errors = []

    # Check required fields
    if 'target_type' not in config:
        errors.append("target_type is required")

    if 'target_name' not in config:
        errors.append("target_name is required")

    # Validate ranges
    if 'generations' in config:
        if not 1 <= config['generations'] <= 500:
            errors.append("generations must be between 1 and 500")

    if 'eval_threshold' in config:
        if not 0.0 <= config['eval_threshold'] <= 1.0:
            errors.append("eval_threshold must be between 0.0 and 1.0")

    if errors:
        return {
            "valid": False,
            "errors": errors
        }

    return {
        "valid": True,
        "message": "Configuration is valid"
    }


# =============================================================================
# User Config Templates (M19)
# =============================================================================

@router.get("/templates", response_model=ConfigTemplateListResponse)
async def list_templates():
    """List all saved user config templates, sorted by most recently updated."""
    templates = config_template_store.list_templates()
    return ConfigTemplateListResponse(templates=templates, total_count=len(templates))


@router.get("/templates/{template_name}", response_model=ConfigTemplate)
async def get_template(template_name: str):
    """Get a specific user config template by name."""
    template = config_template_store.get_template(template_name)
    if not template:
        raise HTTPException(status_code=404, detail=f"Template '{template_name}' not found")
    return template


@router.post("/templates", response_model=ConfigTemplate, status_code=201)
async def create_template(body: ConfigTemplateSave):
    """Save a new user config template."""
    try:
        template = config_template_store.save_template(
            name=body.name,
            config=body.config,
            description=body.description,
        )
        return template
    except ValueError as e:
        raise HTTPException(status_code=400, detail=str(e))


@router.put("/templates/{template_name}", response_model=ConfigTemplate)
async def update_template(template_name: str, body: ConfigTemplateSave):
    """Update an existing user config template."""
    try:
        template = config_template_store.update_template(
            name=template_name,
            config=body.config,
            description=body.description,
        )
        return template
    except ValueError as e:
        raise HTTPException(status_code=404, detail=str(e))


@router.delete("/templates/{template_name}")
async def delete_template(template_name: str):
    """Delete a user config template."""
    if not config_template_store.delete_template(template_name):
        raise HTTPException(status_code=404, detail=f"Template '{template_name}' not found")
    return {"message": f"Template '{template_name}' deleted successfully"}
