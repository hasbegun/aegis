"""
Dynamic model discovery service for LLM providers.
Queries provider APIs to get available models instead of relying on static lists.
"""
import logging
import httpx
from typing import Dict, List, Optional, Any
from datetime import datetime, timedelta
import os

logger = logging.getLogger(__name__)


class OllamaModelDiscovery:
    """Discovers available models from a running Ollama instance."""

    # Predefined model metadata for enriching discovered models
    MODEL_METADATA = {
        "llama3.2": {"name": "Llama 3.2", "description": "Meta's latest Llama model", "recommended": True},
        "llama3.1": {"name": "Llama 3.1", "description": "Previous Llama 3 version", "recommended": True},
        "llama3": {"name": "Llama 3", "description": "Meta's Llama 3", "recommended": True},
        "llama2": {"name": "Llama 2", "description": "Meta's Llama 2", "recommended": False},
        "mistral": {"name": "Mistral", "description": "Mistral 7B model", "recommended": True},
        "mixtral": {"name": "Mixtral", "description": "Mixtral 8x7B model", "recommended": True},
        "gemma2": {"name": "Gemma 2", "description": "Google's Gemma 2", "recommended": True},
        "gemma": {"name": "Gemma", "description": "Google's Gemma", "recommended": False},
        "phi3": {"name": "Phi-3", "description": "Microsoft's Phi-3", "recommended": False},
        "phi": {"name": "Phi", "description": "Microsoft's Phi", "recommended": False},
        "qwen2": {"name": "Qwen 2", "description": "Alibaba's Qwen 2", "recommended": False},
        "qwen": {"name": "Qwen", "description": "Alibaba's Qwen", "recommended": False},
        "codellama": {"name": "Code Llama", "description": "Code-focused Llama", "recommended": False},
        "vicuna": {"name": "Vicuna", "description": "LMSys Vicuna", "recommended": False},
        "deepseek-coder": {"name": "DeepSeek Coder", "description": "DeepSeek coding model", "recommended": False},
        "deepseek": {"name": "DeepSeek", "description": "DeepSeek model", "recommended": False},
        "starcoder": {"name": "StarCoder", "description": "BigCode StarCoder", "recommended": False},
        "yi": {"name": "Yi", "description": "01.AI Yi model", "recommended": False},
        "openchat": {"name": "OpenChat", "description": "OpenChat model", "recommended": False},
        "neural-chat": {"name": "Neural Chat", "description": "Intel Neural Chat", "recommended": False},
        "dolphin": {"name": "Dolphin", "description": "Dolphin fine-tuned model", "recommended": False},
        "orca-mini": {"name": "Orca Mini", "description": "Orca Mini model", "recommended": False},
        "nous-hermes": {"name": "Nous Hermes", "description": "Nous Hermes model", "recommended": False},
        "wizard": {"name": "Wizard", "description": "WizardLM model", "recommended": False},
        "stable-code": {"name": "Stable Code", "description": "Stability AI code model", "recommended": False},
        "codegemma": {"name": "CodeGemma", "description": "Google's CodeGemma", "recommended": False},
        "command-r": {"name": "Command R", "description": "Cohere Command R", "recommended": False},
    }

    # Suggested models to show even if not downloaded
    SUGGESTED_MODELS = [
        {"id": "llama3.2", "name": "Llama 3.2", "description": "Meta's latest Llama model", "recommended": True},
        {"id": "mistral", "name": "Mistral", "description": "Mistral 7B model", "recommended": True},
        {"id": "gemma2", "name": "Gemma 2", "description": "Google's Gemma 2", "recommended": True},
        {"id": "mixtral", "name": "Mixtral", "description": "Mixtral 8x7B model", "recommended": True},
        {"id": "codellama", "name": "Code Llama", "description": "Code-focused Llama", "recommended": False},
        {"id": "phi3", "name": "Phi-3", "description": "Microsoft's Phi-3", "recommended": False},
    ]

    def __init__(self, ollama_host: Optional[str] = None, cache_ttl_seconds: int = 300):
        """
        Initialize Ollama model discovery.

        Args:
            ollama_host: Ollama API host URL (default: from OLLAMA_HOST env or http://localhost:11434)
            cache_ttl_seconds: How long to cache the model list (default: 5 minutes)
        """
        self.ollama_host = ollama_host or os.environ.get("OLLAMA_HOST", "http://localhost:11434")
        # Remove trailing slash if present
        self.ollama_host = self.ollama_host.rstrip("/")
        self.cache_ttl = timedelta(seconds=cache_ttl_seconds)
        self._cache: Optional[Dict[str, Any]] = None
        self._cache_time: Optional[datetime] = None
        self._is_connected: bool = False

        logger.info(f"OllamaModelDiscovery initialized with host: {self.ollama_host}")

    def _is_cache_valid(self) -> bool:
        """Check if cached data is still valid."""
        if self._cache is None or self._cache_time is None:
            return False
        return datetime.now() - self._cache_time < self.cache_ttl

    def _get_base_model_name(self, model_id: str) -> str:
        """Extract base model name from full model ID (e.g., 'llama3.2:latest' -> 'llama3.2')."""
        # Remove tag if present
        base_name = model_id.split(":")[0]
        # Remove size suffix (e.g., 'llama3.2-7b' -> 'llama3.2')
        for suffix in ["-7b", "-8b", "-13b", "-70b", "-1b", "-3b"]:
            if suffix in base_name.lower():
                base_name = base_name.lower().replace(suffix, "")
                break
        return base_name

    def _enrich_model_info(self, model: Dict[str, Any]) -> Dict[str, Any]:
        """Add metadata to a discovered model."""
        model_id = model.get("name", model.get("id", ""))
        base_name = self._get_base_model_name(model_id)

        # Look up metadata
        metadata = self.MODEL_METADATA.get(base_name, {})

        # Format size
        size_bytes = model.get("size", 0)
        if size_bytes > 0:
            size_gb = size_bytes / (1024 ** 3)
            size_str = f"{size_gb:.1f} GB"
        else:
            size_str = None

        return {
            "id": model_id,
            "name": metadata.get("name", base_name.title()),
            "description": metadata.get("description", f"Ollama model: {model_id}"),
            "recommended": metadata.get("recommended", False),
            "available": True,
            "size": size_str,
            "modified_at": model.get("modified_at"),
            "details": model.get("details", {}),
        }

    async def fetch_models(self, force_refresh: bool = False) -> Dict[str, Any]:
        """
        Fetch available models from Ollama.

        Args:
            force_refresh: If True, bypass cache and fetch fresh data

        Returns:
            Dict with models list and connection status
        """
        # Check cache first
        if not force_refresh and self._is_cache_valid():
            logger.debug("Returning cached Ollama models")
            return self._cache

        logger.info(f"Fetching models from Ollama at {self.ollama_host}")

        try:
            async with httpx.AsyncClient(timeout=10.0) as client:
                response = await client.get(f"{self.ollama_host}/api/tags")
                response.raise_for_status()
                data = response.json()

            models_raw = data.get("models", [])
            models = [self._enrich_model_info(m) for m in models_raw]

            # Sort: recommended first, then alphabetically
            models.sort(key=lambda m: (not m.get("recommended", False), m.get("name", "").lower()))

            self._is_connected = True
            self._cache = {
                "models": models,
                "ollama_status": "connected",
                "ollama_host": self.ollama_host,
                "model_count": len(models),
                "last_updated": datetime.now().isoformat(),
            }
            self._cache_time = datetime.now()

            logger.info(f"Discovered {len(models)} models from Ollama")
            return self._cache

        except httpx.ConnectError as e:
            logger.warning(f"Cannot connect to Ollama at {self.ollama_host}: {e}")
            self._is_connected = False
            return self._get_fallback_response("Connection refused - is Ollama running?")

        except httpx.TimeoutException as e:
            logger.warning(f"Timeout connecting to Ollama: {e}")
            self._is_connected = False
            return self._get_fallback_response("Connection timeout")

        except Exception as e:
            logger.error(f"Error fetching Ollama models: {e}")
            self._is_connected = False
            return self._get_fallback_response(str(e))

    def _get_fallback_response(self, error_message: str) -> Dict[str, Any]:
        """Return fallback response with suggested models when Ollama is unavailable."""
        suggested = []
        for model in self.SUGGESTED_MODELS:
            suggested.append({
                **model,
                "available": False,
                "size": None,
            })

        return {
            "models": suggested,
            "ollama_status": "disconnected",
            "ollama_host": self.ollama_host,
            "error": error_message,
            "model_count": 0,
            "note": "Showing suggested models. Start Ollama and pull models with 'ollama pull <model>'",
        }

    async def check_connection(self) -> bool:
        """Check if Ollama is reachable."""
        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                response = await client.get(f"{self.ollama_host}/api/tags")
                self._is_connected = response.status_code == 200
                return self._is_connected
        except Exception:
            self._is_connected = False
            return False

    @property
    def is_connected(self) -> bool:
        """Return last known connection status."""
        return self._is_connected

    def clear_cache(self):
        """Clear the cached model list."""
        self._cache = None
        self._cache_time = None
        logger.info("Ollama model cache cleared")


# Global instance - initialized on startup
ollama_discovery: Optional[OllamaModelDiscovery] = None


def get_ollama_discovery() -> OllamaModelDiscovery:
    """Get or create the global OllamaModelDiscovery instance."""
    global ollama_discovery
    if ollama_discovery is None:
        from config import settings
        ollama_discovery = OllamaModelDiscovery(
            ollama_host=settings.ollama_host,
            cache_ttl_seconds=settings.ollama_model_cache_ttl
        )
    return ollama_discovery


async def initialize_model_discovery():
    """Initialize model discovery on application startup."""
    global ollama_discovery
    from config import settings

    ollama_discovery = OllamaModelDiscovery(
        ollama_host=settings.ollama_host,
        cache_ttl_seconds=settings.ollama_model_cache_ttl
    )

    # Try to fetch models on startup
    result = await ollama_discovery.fetch_models()

    if ollama_discovery.is_connected:
        logger.info(f"Ollama connected: {result.get('model_count', 0)} models available")
    else:
        logger.warning(f"Ollama not available: {result.get('error', 'Unknown error')}")

    return ollama_discovery
