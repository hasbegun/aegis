"""
Plugin discovery endpoints
"""
from fastapi import APIRouter, HTTPException
from models.schemas import PluginListResponse, PluginInfo
from services.garak_wrapper import garak_wrapper
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


@router.get("/generators", response_model=PluginListResponse)
async def list_generators():
    """
    List all available generator (model interface) plugins

    Returns:
        List of generator plugins
    """
    try:
        generators = garak_wrapper.list_plugins('generators')

        plugin_infos = [
            PluginInfo(
                name=gen,
                full_name=f"generators.{gen}",
                description=f"Generator interface for {gen}",
                active=True
            )
            for gen in generators
        ]

        return PluginListResponse(
            plugins=plugin_infos,
            total_count=len(plugin_infos)
        )

    except Exception as e:
        logger.error(f"Error listing generators: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/probes", response_model=PluginListResponse)
async def list_probes():
    """
    List all available probe plugins

    Returns:
        List of probe plugins
    """
    try:
        probes = garak_wrapper.list_plugins('probes')

        plugin_infos = [
            PluginInfo(
                name=probe,
                full_name=f"probes.{probe}",
                description=f"Vulnerability probe: {probe}",
                active=True
            )
            for probe in probes
        ]

        return PluginListResponse(
            plugins=plugin_infos,
            total_count=len(plugin_infos)
        )

    except Exception as e:
        logger.error(f"Error listing probes: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/detectors", response_model=PluginListResponse)
async def list_detectors():
    """
    List all available detector plugins

    Returns:
        List of detector plugins
    """
    try:
        detectors = garak_wrapper.list_plugins('detectors')

        plugin_infos = [
            PluginInfo(
                name=detector,
                full_name=f"detectors.{detector}",
                description=f"Result detector: {detector}",
                active=True
            )
            for detector in detectors
        ]

        return PluginListResponse(
            plugins=plugin_infos,
            total_count=len(plugin_infos)
        )

    except Exception as e:
        logger.error(f"Error listing detectors: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/buffs", response_model=PluginListResponse)
async def list_buffs():
    """
    List all available buff/fuzzing plugins

    Returns:
        List of buff plugins
    """
    try:
        buffs = garak_wrapper.list_plugins('buffs')

        plugin_infos = [
            PluginInfo(
                name=buff,
                full_name=f"buffs.{buff}",
                description=f"Input transformation: {buff}",
                active=True
            )
            for buff in buffs
        ]

        return PluginListResponse(
            plugins=plugin_infos,
            total_count=len(plugin_infos)
        )

    except Exception as e:
        logger.error(f"Error listing buffs: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/{plugin_type}/{plugin_name}/info")
async def get_plugin_info(plugin_type: str, plugin_name: str):
    """
    Get detailed information about a specific plugin

    Args:
        plugin_type: Type of plugin (probes, detectors, generators, buffs)
        plugin_name: Name of the plugin

    Returns:
        Detailed plugin information
    """
    # This would require calling garak --plugin_info
    # For now, return basic info
    return {
        "plugin_type": plugin_type,
        "plugin_name": plugin_name,
        "full_name": f"{plugin_type}.{plugin_name}",
        "message": "Detailed plugin info endpoint - to be implemented"
    }
