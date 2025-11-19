"""
Configuration management endpoints
"""
from fastapi import APIRouter, HTTPException
from models.schemas import ConfigPreset
from typing import List
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
        if not 1 <= config['generations'] <= 100:
            errors.append("generations must be between 1 and 100")

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
