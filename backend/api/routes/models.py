"""
Model listing endpoints for all generator types
"""
from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import List, Dict, Optional
import logging
import httpx
import asyncio

from services.model_discovery import get_ollama_discovery

logger = logging.getLogger(__name__)

router = APIRouter()


class ApiKeyValidationRequest(BaseModel):
    """Request model for API key validation"""
    provider: str
    api_key: str


class ApiKeyValidationResponse(BaseModel):
    """Response model for API key validation"""
    valid: bool
    provider: str
    message: str
    details: Optional[Dict] = None


# Comprehensive model lists for each generator type
GENERATOR_MODELS = {
    "openai": {
        "models": [
            {
                "id": "gpt-4o",
                "name": "GPT-4o",
                "description": "Most capable model, multimodal",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "gpt-4o-mini",
                "name": "GPT-4o Mini",
                "description": "Affordable and fast model",
                "context_length": 16384,
                "recommended": True
            },
            {
                "id": "gpt-4-turbo",
                "name": "GPT-4 Turbo",
                "description": "High capability model with vision",
                "context_length": 128000,
                "recommended": False
            },
            {
                "id": "gpt-4",
                "name": "GPT-4",
                "description": "Previous generation flagship",
                "context_length": 8192,
                "recommended": False
            },
            {
                "id": "gpt-3.5-turbo",
                "name": "GPT-3.5 Turbo",
                "description": "Fast and affordable",
                "context_length": 16385,
                "recommended": True
            },
            {
                "id": "o1-preview",
                "name": "O1 Preview",
                "description": "Advanced reasoning model",
                "context_length": 32768,
                "recommended": False
            },
            {
                "id": "o1-mini",
                "name": "O1 Mini",
                "description": "Fast reasoning model",
                "context_length": 65536,
                "recommended": False
            },
        ],
        "requires_api_key": True,
        "api_key_env_var": "OPENAI_API_KEY"
    },
    "huggingface": {
        "models": [
            {
                "id": "meta-llama/Llama-2-7b-chat-hf",
                "name": "Llama 2 7B Chat",
                "description": "Meta's Llama 2 chat model",
                "context_length": 4096,
                "recommended": True
            },
            {
                "id": "meta-llama/Llama-2-13b-chat-hf",
                "name": "Llama 2 13B Chat",
                "description": "Larger Llama 2 chat model",
                "context_length": 4096,
                "recommended": False
            },
            {
                "id": "mistralai/Mistral-7B-Instruct-v0.2",
                "name": "Mistral 7B Instruct",
                "description": "Mistral's instruction-tuned model",
                "context_length": 8192,
                "recommended": True
            },
            {
                "id": "mistralai/Mixtral-8x7B-Instruct-v0.1",
                "name": "Mixtral 8x7B Instruct",
                "description": "Mixtral mixture-of-experts model",
                "context_length": 32768,
                "recommended": True
            },
            {
                "id": "lmsys/vicuna-13b-v1.3",
                "name": "Vicuna 13B",
                "description": "LMSys Vicuna chat model",
                "context_length": 2048,
                "recommended": False
            },
            {
                "id": "lmsys/vicuna-7b-v1.3",
                "name": "Vicuna 7B",
                "description": "Smaller Vicuna chat model",
                "context_length": 2048,
                "recommended": False
            },
            {
                "id": "tiiuae/falcon-7b-instruct",
                "name": "Falcon 7B Instruct",
                "description": "TII's Falcon instruction model",
                "context_length": 2048,
                "recommended": False
            },
            {
                "id": "google/flan-t5-xxl",
                "name": "FLAN-T5 XXL",
                "description": "Google's FLAN-T5 model",
                "context_length": 512,
                "recommended": False
            },
            {
                "id": "gpt2",
                "name": "GPT-2",
                "description": "OpenAI's GPT-2 (for testing)",
                "context_length": 1024,
                "recommended": False
            },
        ],
        "requires_api_key": False,
        "api_key_env_var": "HF_INFERENCE_TOKEN",
        "note": "API token recommended for better rate limits"
    },
    "anthropic": {
        "models": [
            {
                "id": "claude-3-5-sonnet-20241022",
                "name": "Claude 3.5 Sonnet",
                "description": "Most intelligent model",
                "context_length": 200000,
                "recommended": True
            },
            {
                "id": "claude-3-5-haiku-20241022",
                "name": "Claude 3.5 Haiku",
                "description": "Fastest and most compact",
                "context_length": 200000,
                "recommended": True
            },
            {
                "id": "claude-3-opus-20240229",
                "name": "Claude 3 Opus",
                "description": "Powerful model for complex tasks",
                "context_length": 200000,
                "recommended": False
            },
            {
                "id": "claude-3-sonnet-20240229",
                "name": "Claude 3 Sonnet",
                "description": "Balanced performance",
                "context_length": 200000,
                "recommended": False
            },
            {
                "id": "claude-3-haiku-20240307",
                "name": "Claude 3 Haiku",
                "description": "Fast and compact",
                "context_length": 200000,
                "recommended": False
            },
        ],
        "requires_api_key": True,
        "api_key_env_var": "ANTHROPIC_API_KEY"
    },
    "cohere": {
        "models": [
            {
                "id": "command-r-plus",
                "name": "Command R+",
                "description": "Most powerful model",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "command-r",
                "name": "Command R",
                "description": "Balanced performance",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "command",
                "name": "Command",
                "description": "Standard model",
                "context_length": 4096,
                "recommended": False
            },
            {
                "id": "command-light",
                "name": "Command Light",
                "description": "Faster, smaller model",
                "context_length": 4096,
                "recommended": False
            },
        ],
        "requires_api_key": True,
        "api_key_env_var": "COHERE_API_KEY"
    },
    "replicate": {
        "models": [
            {
                "id": "meta/llama-2-70b-chat",
                "name": "Llama 2 70B Chat",
                "description": "Meta's largest Llama 2 model",
                "context_length": 4096,
                "recommended": True
            },
            {
                "id": "meta/llama-2-13b-chat",
                "name": "Llama 2 13B Chat",
                "description": "Medium Llama 2 model",
                "context_length": 4096,
                "recommended": False
            },
            {
                "id": "meta/llama-2-7b-chat",
                "name": "Llama 2 7B Chat",
                "description": "Smaller Llama 2 model",
                "context_length": 4096,
                "recommended": False
            },
            {
                "id": "mistralai/mistral-7b-instruct-v0.2",
                "name": "Mistral 7B Instruct",
                "description": "Mistral instruction model",
                "context_length": 8192,
                "recommended": True
            },
            {
                "id": "mistralai/mixtral-8x7b-instruct-v0.1",
                "name": "Mixtral 8x7B",
                "description": "Mixtral mixture-of-experts",
                "context_length": 32768,
                "recommended": True
            },
            {
                "id": "anthropic/claude-3-opus",
                "name": "Claude 3 Opus (Replicate)",
                "description": "Claude 3 via Replicate",
                "context_length": 200000,
                "recommended": False
            },
        ],
        "requires_api_key": True,
        "api_key_env_var": "REPLICATE_API_TOKEN",
        "note": "Format: owner/model-name"
    },
    # Note: Ollama models are fetched dynamically via model_discovery service
    # This static entry is kept for fallback and metadata reference only
    "ollama": {
        "models": [],  # Populated dynamically
        "requires_api_key": False,
        "note": "Models fetched dynamically from Ollama. Use 'ollama pull <model>' to download.",
        "dynamic": True  # Flag indicating this uses dynamic discovery
    },
    "litellm": {
        "models": [
            {
                "id": "ollama/llama3.2",
                "name": "Ollama - Llama 3.2",
                "description": "Llama 3.2 via Ollama",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "ollama/mistral",
                "name": "Ollama - Mistral",
                "description": "Mistral via Ollama",
                "context_length": 8192,
                "recommended": True
            },
            {
                "id": "gpt-4o",
                "name": "OpenAI - GPT-4o",
                "description": "GPT-4o via LiteLLM",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "claude-3-5-sonnet-20241022",
                "name": "Anthropic - Claude 3.5 Sonnet",
                "description": "Claude via LiteLLM",
                "context_length": 200000,
                "recommended": True
            },
            {
                "id": "command-r-plus",
                "name": "Cohere - Command R+",
                "description": "Cohere via LiteLLM",
                "context_length": 128000,
                "recommended": False
            },
            {
                "id": "gemini/gemini-pro",
                "name": "Google - Gemini Pro",
                "description": "Gemini via LiteLLM",
                "context_length": 32768,
                "recommended": True
            },
        ],
        "requires_api_key": False,
        "note": "LiteLLM is a proxy. API keys depend on the underlying provider (e.g., OPENAI_API_KEY for OpenAI models)."
    },
    "nim": {
        "models": [
            {
                "id": "meta/llama-3.1-8b-instruct",
                "name": "Llama 3.1 8B Instruct",
                "description": "Efficient Llama 3.1 model",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "meta/llama-3.1-70b-instruct",
                "name": "Llama 3.1 70B Instruct",
                "description": "Large Llama 3.1 model",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "mistralai/mixtral-8x7b-instruct-v0.1",
                "name": "Mixtral 8x7B Instruct",
                "description": "Mixtral on NIM",
                "context_length": 32768,
                "recommended": True
            },
            {
                "id": "mistralai/mistral-7b-instruct-v0.3",
                "name": "Mistral 7B Instruct",
                "description": "Mistral on NIM",
                "context_length": 8192,
                "recommended": False
            },
            {
                "id": "google/gemma-7b",
                "name": "Gemma 7B",
                "description": "Google's Gemma on NIM",
                "context_length": 8192,
                "recommended": False
            },
            {
                "id": "microsoft/phi-3-mini-128k-instruct",
                "name": "Phi-3 Mini",
                "description": "Microsoft Phi-3 on NIM",
                "context_length": 128000,
                "recommended": False
            },
        ],
        "requires_api_key": True,
        "api_key_env_var": "NIM_API_KEY",
        "note": "NVIDIA NIM microservices. Get API key from build.nvidia.com"
    },
    "groq": {
        "models": [
            {
                "id": "llama-3.3-70b-versatile",
                "name": "Llama 3.3 70B Versatile",
                "description": "Latest Llama 3.3 with 128K context",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "llama-3.1-8b-instant",
                "name": "Llama 3.1 8B Instant",
                "description": "Fast, efficient Llama model",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "llama-3.1-70b-versatile",
                "name": "Llama 3.1 70B Versatile",
                "description": "Large Llama 3.1 model",
                "context_length": 128000,
                "recommended": False
            },
            {
                "id": "mixtral-8x7b-32768",
                "name": "Mixtral 8x7B",
                "description": "Mixtral MoE model",
                "context_length": 32768,
                "recommended": False
            },
            {
                "id": "gemma2-9b-it",
                "name": "Gemma 2 9B",
                "description": "Google Gemma 2 instruction-tuned",
                "context_length": 8192,
                "recommended": False
            },
        ],
        "requires_api_key": True,
        "api_key_env_var": "GROQ_API_KEY",
        "note": "Groq provides ultra-fast inference. Get API key from console.groq.com"
    },
    "mistral": {
        "models": [
            {
                "id": "mistral-large-latest",
                "name": "Mistral Large",
                "description": "Most capable Mistral model",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "mistral-small-latest",
                "name": "Mistral Small",
                "description": "Fast and cost-effective",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "mistral-medium-latest",
                "name": "Mistral Medium",
                "description": "Balanced performance",
                "context_length": 32768,
                "recommended": False
            },
            {
                "id": "open-mistral-7b",
                "name": "Open Mistral 7B",
                "description": "Open-source base model",
                "context_length": 32768,
                "recommended": False
            },
            {
                "id": "open-mixtral-8x7b",
                "name": "Open Mixtral 8x7B",
                "description": "Open-source MoE model",
                "context_length": 32768,
                "recommended": False
            },
            {
                "id": "codestral-latest",
                "name": "Codestral",
                "description": "Optimized for code generation",
                "context_length": 32768,
                "recommended": False
            },
        ],
        "requires_api_key": True,
        "api_key_env_var": "MISTRAL_API_KEY",
        "note": "Mistral AI models. Get API key from console.mistral.ai"
    },
    "azure": {
        "models": [
            {
                "id": "gpt-4o",
                "name": "GPT-4o (Azure)",
                "description": "Most capable Azure OpenAI model",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "gpt-4-turbo",
                "name": "GPT-4 Turbo (Azure)",
                "description": "Fast GPT-4 on Azure",
                "context_length": 128000,
                "recommended": False
            },
            {
                "id": "gpt-4",
                "name": "GPT-4 (Azure)",
                "description": "Standard GPT-4 on Azure",
                "context_length": 8192,
                "recommended": False
            },
            {
                "id": "gpt-35-turbo",
                "name": "GPT-3.5 Turbo (Azure)",
                "description": "Fast and cost-effective",
                "context_length": 16384,
                "recommended": True
            },
        ],
        "requires_api_key": True,
        "api_key_env_var": "AZURE_OPENAI_API_KEY",
        "note": "Azure OpenAI Service. Also requires AZURE_OPENAI_ENDPOINT. Model ID should match your deployment name."
    },
    "bedrock": {
        "models": [
            {
                "id": "anthropic.claude-3-5-sonnet-20241022-v2:0",
                "name": "Claude 3.5 Sonnet v2",
                "description": "Latest Claude on Bedrock",
                "context_length": 200000,
                "recommended": True
            },
            {
                "id": "anthropic.claude-3-haiku-20240307-v1:0",
                "name": "Claude 3 Haiku",
                "description": "Fast Claude on Bedrock",
                "context_length": 200000,
                "recommended": True
            },
            {
                "id": "anthropic.claude-3-sonnet-20240229-v1:0",
                "name": "Claude 3 Sonnet",
                "description": "Balanced Claude on Bedrock",
                "context_length": 200000,
                "recommended": False
            },
            {
                "id": "amazon.titan-text-express-v1",
                "name": "Amazon Titan Text Express",
                "description": "Amazon's foundation model",
                "context_length": 8000,
                "recommended": False
            },
            {
                "id": "meta.llama3-1-70b-instruct-v1:0",
                "name": "Llama 3.1 70B (Bedrock)",
                "description": "Meta Llama on Bedrock",
                "context_length": 128000,
                "recommended": False
            },
            {
                "id": "mistral.mistral-large-2407-v1:0",
                "name": "Mistral Large (Bedrock)",
                "description": "Mistral on Bedrock",
                "context_length": 128000,
                "recommended": False
            },
        ],
        "requires_api_key": True,
        "api_key_env_var": "AWS_ACCESS_KEY_ID",
        "note": "AWS Bedrock. Requires AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, and AWS_DEFAULT_REGION environment variables."
    }
}


@router.get("/{generator_type}/models")
async def list_generator_models(generator_type: str):
    """
    Get list of available models for a specific generator type

    Args:
        generator_type: Type of generator (openai, huggingface, etc.)

    Returns:
        Model list with metadata for the generator type
    """
    # Normalize generator type (remove "Generator" suffix if present)
    generator_type = generator_type.lower().replace("generator", "")

    if generator_type not in GENERATOR_MODELS:
        raise HTTPException(
            status_code=404,
            detail=f"Generator type '{generator_type}' not found. Available types: {list(GENERATOR_MODELS.keys())}"
        )

    # Handle Ollama dynamically
    if generator_type == "ollama":
        return await _get_ollama_models()

    return {
        "generator_type": generator_type,
        **GENERATOR_MODELS[generator_type]
    }


async def _get_ollama_models() -> Dict:
    """Fetch Ollama models dynamically."""
    discovery = get_ollama_discovery()
    result = await discovery.fetch_models()

    return {
        "generator_type": "ollama",
        "models": result.get("models", []),
        "requires_api_key": False,
        "note": GENERATOR_MODELS["ollama"]["note"],
        "ollama_status": result.get("ollama_status", "unknown"),
        "ollama_host": result.get("ollama_host"),
        "model_count": result.get("model_count", 0),
        "last_updated": result.get("last_updated"),
        "error": result.get("error"),
    }


@router.post("/ollama/refresh")
async def refresh_ollama_models():
    """
    Force refresh the Ollama model list (bypass cache)

    Returns:
        Updated model list from Ollama
    """
    discovery = get_ollama_discovery()
    discovery.clear_cache()
    result = await discovery.fetch_models(force_refresh=True)

    return {
        "message": "Ollama model list refreshed",
        "generator_type": "ollama",
        "models": result.get("models", []),
        "ollama_status": result.get("ollama_status", "unknown"),
        "model_count": result.get("model_count", 0),
    }


@router.get("/ollama/status")
async def get_ollama_status():
    """
    Check Ollama connection status

    Returns:
        Connection status and basic info
    """
    discovery = get_ollama_discovery()
    is_connected = await discovery.check_connection()

    return {
        "connected": is_connected,
        "host": discovery.ollama_host,
    }


@router.get("/models/all")
async def list_all_models():
    """
    Get list of all available models for all generator types

    Returns:
        Complete model catalog organized by generator type
    """
    # Create a copy of static models
    generators = dict(GENERATOR_MODELS)

    # Fetch Ollama models dynamically
    ollama_data = await _get_ollama_models()
    generators["ollama"] = {
        "models": ollama_data.get("models", []),
        "requires_api_key": False,
        "note": ollama_data.get("note"),
        "ollama_status": ollama_data.get("ollama_status"),
    }

    return {
        "generators": generators,
        "total_generators": len(generators),
        "total_models": sum(len(data["models"]) for data in generators.values())
    }


@router.get("/models/recommended")
async def list_recommended_models():
    """
    Get list of recommended models for each generator type

    Returns:
        Recommended models for quick start
    """
    recommended = {}
    for gen_type, data in GENERATOR_MODELS.items():
        recommended[gen_type] = {
            "models": [m for m in data["models"] if m.get("recommended", False)],
            "requires_api_key": data["requires_api_key"],
            "api_key_env_var": data.get("api_key_env_var"),
        }

    return recommended


@router.post("/validate-api-key", response_model=ApiKeyValidationResponse)
async def validate_api_key(request: ApiKeyValidationRequest):
    """
    Validate an API key for a specific provider.

    Makes a minimal API call to verify the key is valid without incurring
    significant costs.

    Args:
        request: Provider name and API key to validate

    Returns:
        Validation result with status and message
    """
    provider = request.provider.lower().replace("generator", "")
    api_key = request.api_key.strip()

    if not api_key:
        return ApiKeyValidationResponse(
            valid=False,
            provider=provider,
            message="API key is empty"
        )

    # Provider-specific validation
    validators = {
        "openai": _validate_openai_key,
        "anthropic": _validate_anthropic_key,
        "cohere": _validate_cohere_key,
        "replicate": _validate_replicate_key,
        "groq": _validate_groq_key,
        "mistral": _validate_mistral_key,
        "huggingface": _validate_huggingface_key,
    }

    validator = validators.get(provider)
    if not validator:
        # For unsupported providers, just do basic format check
        return ApiKeyValidationResponse(
            valid=True,
            provider=provider,
            message=f"API key format accepted (validation not available for {provider})"
        )

    try:
        result = await validator(api_key)
        return ApiKeyValidationResponse(
            valid=result["valid"],
            provider=provider,
            message=result["message"],
            details=result.get("details")
        )
    except Exception as e:
        logger.error(f"Error validating {provider} API key: {e}")
        return ApiKeyValidationResponse(
            valid=False,
            provider=provider,
            message=f"Validation error: {str(e)}"
        )


async def _validate_openai_key(api_key: str) -> Dict:
    """Validate OpenAI API key by listing models"""
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            response = await client.get(
                "https://api.openai.com/v1/models",
                headers={"Authorization": f"Bearer {api_key}"}
            )
            if response.status_code == 200:
                return {"valid": True, "message": "OpenAI API key is valid"}
            elif response.status_code == 401:
                return {"valid": False, "message": "Invalid OpenAI API key"}
            elif response.status_code == 429:
                return {"valid": True, "message": "OpenAI API key is valid (rate limited)"}
            else:
                return {"valid": False, "message": f"OpenAI API error: {response.status_code}"}
        except httpx.TimeoutException:
            return {"valid": False, "message": "OpenAI API request timed out"}
        except Exception as e:
            return {"valid": False, "message": f"Connection error: {str(e)}"}


async def _validate_anthropic_key(api_key: str) -> Dict:
    """Validate Anthropic API key with a minimal request"""
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            # Use the messages endpoint with minimal content to validate
            response = await client.post(
                "https://api.anthropic.com/v1/messages",
                headers={
                    "x-api-key": api_key,
                    "anthropic-version": "2023-06-01",
                    "content-type": "application/json"
                },
                json={
                    "model": "claude-3-haiku-20240307",
                    "max_tokens": 1,
                    "messages": [{"role": "user", "content": "Hi"}]
                }
            )
            if response.status_code == 200:
                return {"valid": True, "message": "Anthropic API key is valid"}
            elif response.status_code == 401:
                return {"valid": False, "message": "Invalid Anthropic API key"}
            elif response.status_code == 429:
                return {"valid": True, "message": "Anthropic API key is valid (rate limited)"}
            elif response.status_code == 400:
                # Bad request but key is valid
                error_data = response.json()
                if "authentication" in str(error_data).lower():
                    return {"valid": False, "message": "Invalid Anthropic API key"}
                return {"valid": True, "message": "Anthropic API key is valid"}
            else:
                return {"valid": False, "message": f"Anthropic API error: {response.status_code}"}
        except httpx.TimeoutException:
            return {"valid": False, "message": "Anthropic API request timed out"}
        except Exception as e:
            return {"valid": False, "message": f"Connection error: {str(e)}"}


async def _validate_cohere_key(api_key: str) -> Dict:
    """Validate Cohere API key"""
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            response = await client.get(
                "https://api.cohere.ai/v1/models",
                headers={"Authorization": f"Bearer {api_key}"}
            )
            if response.status_code == 200:
                return {"valid": True, "message": "Cohere API key is valid"}
            elif response.status_code == 401:
                return {"valid": False, "message": "Invalid Cohere API key"}
            elif response.status_code == 429:
                return {"valid": True, "message": "Cohere API key is valid (rate limited)"}
            else:
                return {"valid": False, "message": f"Cohere API error: {response.status_code}"}
        except httpx.TimeoutException:
            return {"valid": False, "message": "Cohere API request timed out"}
        except Exception as e:
            return {"valid": False, "message": f"Connection error: {str(e)}"}


async def _validate_replicate_key(api_key: str) -> Dict:
    """Validate Replicate API key"""
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            response = await client.get(
                "https://api.replicate.com/v1/account",
                headers={"Authorization": f"Token {api_key}"}
            )
            if response.status_code == 200:
                data = response.json()
                return {
                    "valid": True,
                    "message": "Replicate API key is valid",
                    "details": {"username": data.get("username")}
                }
            elif response.status_code == 401:
                return {"valid": False, "message": "Invalid Replicate API key"}
            else:
                return {"valid": False, "message": f"Replicate API error: {response.status_code}"}
        except httpx.TimeoutException:
            return {"valid": False, "message": "Replicate API request timed out"}
        except Exception as e:
            return {"valid": False, "message": f"Connection error: {str(e)}"}


async def _validate_groq_key(api_key: str) -> Dict:
    """Validate Groq API key"""
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            response = await client.get(
                "https://api.groq.com/openai/v1/models",
                headers={"Authorization": f"Bearer {api_key}"}
            )
            if response.status_code == 200:
                return {"valid": True, "message": "Groq API key is valid"}
            elif response.status_code == 401:
                return {"valid": False, "message": "Invalid Groq API key"}
            elif response.status_code == 429:
                return {"valid": True, "message": "Groq API key is valid (rate limited)"}
            else:
                return {"valid": False, "message": f"Groq API error: {response.status_code}"}
        except httpx.TimeoutException:
            return {"valid": False, "message": "Groq API request timed out"}
        except Exception as e:
            return {"valid": False, "message": f"Connection error: {str(e)}"}


async def _validate_mistral_key(api_key: str) -> Dict:
    """Validate Mistral API key"""
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            response = await client.get(
                "https://api.mistral.ai/v1/models",
                headers={"Authorization": f"Bearer {api_key}"}
            )
            if response.status_code == 200:
                return {"valid": True, "message": "Mistral API key is valid"}
            elif response.status_code == 401:
                return {"valid": False, "message": "Invalid Mistral API key"}
            elif response.status_code == 429:
                return {"valid": True, "message": "Mistral API key is valid (rate limited)"}
            else:
                return {"valid": False, "message": f"Mistral API error: {response.status_code}"}
        except httpx.TimeoutException:
            return {"valid": False, "message": "Mistral API request timed out"}
        except Exception as e:
            return {"valid": False, "message": f"Connection error: {str(e)}"}


async def _validate_huggingface_key(api_key: str) -> Dict:
    """Validate Hugging Face API key"""
    async with httpx.AsyncClient(timeout=10.0) as client:
        try:
            response = await client.get(
                "https://huggingface.co/api/whoami-v2",
                headers={"Authorization": f"Bearer {api_key}"}
            )
            if response.status_code == 200:
                data = response.json()
                return {
                    "valid": True,
                    "message": "Hugging Face API key is valid",
                    "details": {"username": data.get("name")}
                }
            elif response.status_code == 401:
                return {"valid": False, "message": "Invalid Hugging Face API key"}
            else:
                return {"valid": False, "message": f"Hugging Face API error: {response.status_code}"}
        except httpx.TimeoutException:
            return {"valid": False, "message": "Hugging Face API request timed out"}
        except Exception as e:
            return {"valid": False, "message": f"Connection error: {str(e)}"}
