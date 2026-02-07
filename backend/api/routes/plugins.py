"""
Plugin discovery endpoints
"""
from fastapi import APIRouter, HTTPException, Request, Response
from models.schemas import PluginListResponse, PluginInfo
from services.garak_wrapper import garak_wrapper
import logging
import time
import hashlib
from typing import Dict, List, Optional, Any, Tuple

logger = logging.getLogger(__name__)

router = APIRouter()

# Plugin cache with 5 minute TTL (similar to Ollama model discovery)
CACHE_TTL_SECONDS = 300  # 5 minutes


def generate_etag(data: List[str]) -> str:
    """Generate ETag from list content using MD5 hash."""
    content = ",".join(sorted(data))
    hash_value = hashlib.md5(content.encode()).hexdigest()[:16]
    return f'"{hash_value}"'


class PluginCache:
    """Simple time-based cache for plugin lists with ETag support."""

    def __init__(self, ttl_seconds: int = CACHE_TTL_SECONDS):
        self._cache: Dict[str, Dict[str, Any]] = {}
        self._ttl = ttl_seconds

    def get(self, key: str) -> Optional[Tuple[List[str], str]]:
        """Get cached value and ETag if not expired."""
        if key in self._cache:
            entry = self._cache[key]
            if time.time() - entry["timestamp"] < self._ttl:
                logger.debug(f"Cache hit for '{key}'")
                return entry["data"], entry["etag"]
            else:
                logger.debug(f"Cache expired for '{key}'")
                del self._cache[key]
        return None

    def set(self, key: str, data: List[str]) -> str:
        """Cache a value with current timestamp and generated ETag. Returns ETag."""
        etag = generate_etag(data)
        self._cache[key] = {
            "data": data,
            "timestamp": time.time(),
            "etag": etag
        }
        logger.debug(f"Cached '{key}' with {len(data)} items, ETag: {etag}")
        return etag

    def get_etag(self, key: str) -> Optional[str]:
        """Get just the ETag for a cached key if not expired."""
        if key in self._cache:
            entry = self._cache[key]
            if time.time() - entry["timestamp"] < self._ttl:
                return entry["etag"]
        return None

    def invalidate(self, key: Optional[str] = None) -> None:
        """Invalidate cache entry or all entries."""
        if key:
            self._cache.pop(key, None)
            logger.debug(f"Invalidated cache for '{key}'")
        else:
            self._cache.clear()
            logger.debug("Invalidated all plugin cache entries")


# Global cache instance
plugin_cache = PluginCache()


def check_etag_match(request: Request, etag: str) -> bool:
    """Check if client's If-None-Match header matches the current ETag."""
    if_none_match = request.headers.get("if-none-match")
    if if_none_match:
        # Handle multiple ETags (comma-separated) and wildcard
        client_etags = [e.strip() for e in if_none_match.split(",")]
        return etag in client_etags or "*" in client_etags
    return False


@router.get("/generators", response_model=PluginListResponse)
async def list_generators(request: Request, response: Response):
    """
    List all available generator (model interface) plugins

    Returns:
        List of generator plugins (cached for 5 minutes)
    Supports:
        ETag/If-None-Match for conditional requests (returns 304 if unchanged)
    """
    try:
        # Check cache first
        cached = plugin_cache.get('generators')
        if cached is not None:
            generators, etag = cached
            # Check if client has current version
            if check_etag_match(request, etag):
                return Response(status_code=304, headers={"ETag": etag})
        else:
            generators = garak_wrapper.list_plugins('generators')
            etag = plugin_cache.set('generators', generators)

        plugin_infos = [
            PluginInfo(
                name=gen,
                full_name=f"generators.{gen}",
                description=f"Generator interface for {gen}",
                active=True
            )
            for gen in generators
        ]

        response.headers["ETag"] = etag
        response.headers["Cache-Control"] = f"max-age={CACHE_TTL_SECONDS}"

        return PluginListResponse(
            plugins=plugin_infos,
            total_count=len(plugin_infos)
        )

    except Exception as e:
        logger.error(f"Error listing generators: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/probes", response_model=PluginListResponse)
async def list_probes(request: Request, response: Response):
    """
    List all available probe plugins

    Returns:
        List of probe plugins (cached for 5 minutes)
    Supports:
        ETag/If-None-Match for conditional requests (returns 304 if unchanged)
    """
    try:
        # Check cache first
        cached = plugin_cache.get('probes')
        if cached is not None:
            probes, etag = cached
            # Check if client has current version
            if check_etag_match(request, etag):
                return Response(status_code=304, headers={"ETag": etag})
        else:
            probes = garak_wrapper.list_plugins('probes')
            etag = plugin_cache.set('probes', probes)

        plugin_infos = [
            PluginInfo(
                name=probe,
                full_name=f"probes.{probe}",
                description=f"Vulnerability probe: {probe}",
                active=True
            )
            for probe in probes
        ]

        response.headers["ETag"] = etag
        response.headers["Cache-Control"] = f"max-age={CACHE_TTL_SECONDS}"

        return PluginListResponse(
            plugins=plugin_infos,
            total_count=len(plugin_infos)
        )

    except Exception as e:
        logger.error(f"Error listing probes: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/detectors", response_model=PluginListResponse)
async def list_detectors(request: Request, response: Response):
    """
    List all available detector plugins

    Returns:
        List of detector plugins (cached for 5 minutes)
    Supports:
        ETag/If-None-Match for conditional requests (returns 304 if unchanged)
    """
    try:
        # Check cache first
        cached = plugin_cache.get('detectors')
        if cached is not None:
            detectors, etag = cached
            # Check if client has current version
            if check_etag_match(request, etag):
                return Response(status_code=304, headers={"ETag": etag})
        else:
            detectors = garak_wrapper.list_plugins('detectors')
            etag = plugin_cache.set('detectors', detectors)

        plugin_infos = [
            PluginInfo(
                name=detector,
                full_name=f"detectors.{detector}",
                description=f"Result detector: {detector}",
                active=True
            )
            for detector in detectors
        ]

        response.headers["ETag"] = etag
        response.headers["Cache-Control"] = f"max-age={CACHE_TTL_SECONDS}"

        return PluginListResponse(
            plugins=plugin_infos,
            total_count=len(plugin_infos)
        )

    except Exception as e:
        logger.error(f"Error listing detectors: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.get("/buffs", response_model=PluginListResponse)
async def list_buffs(request: Request, response: Response):
    """
    List all available buff/fuzzing plugins

    Returns:
        List of buff plugins (cached for 5 minutes)
    Supports:
        ETag/If-None-Match for conditional requests (returns 304 if unchanged)
    """
    try:
        # Check cache first
        cached = plugin_cache.get('buffs')
        if cached is not None:
            buffs, etag = cached
            # Check if client has current version
            if check_etag_match(request, etag):
                return Response(status_code=304, headers={"ETag": etag})
        else:
            buffs = garak_wrapper.list_plugins('buffs')
            etag = plugin_cache.set('buffs', buffs)

        plugin_infos = [
            PluginInfo(
                name=buff,
                full_name=f"buffs.{buff}",
                description=f"Input transformation: {buff}",
                active=True
            )
            for buff in buffs
        ]

        response.headers["ETag"] = etag
        response.headers["Cache-Control"] = f"max-age={CACHE_TTL_SECONDS}"

        return PluginListResponse(
            plugins=plugin_infos,
            total_count=len(plugin_infos)
        )

    except Exception as e:
        logger.error(f"Error listing buffs: {e}")
        raise HTTPException(status_code=500, detail=str(e))


@router.post("/cache/refresh")
async def refresh_plugin_cache():
    """
    Invalidate the plugin cache to force a refresh on next request.

    Returns:
        Confirmation message
    """
    plugin_cache.invalidate()
    logger.info("Plugin cache invalidated via API")
    return {"message": "Plugin cache invalidated", "ttl_seconds": CACHE_TTL_SECONDS}


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
