"""
Model listing endpoints for all generator types
"""
from fastapi import APIRouter, HTTPException
from typing import List, Dict, Optional
import logging

logger = logging.getLogger(__name__)

router = APIRouter()


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
    "ollama": {
        "models": [
            {
                "id": "llama3.2",
                "name": "Llama 3.2",
                "description": "Meta's latest Llama model",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "llama3.1",
                "name": "Llama 3.1",
                "description": "Previous Llama 3 version",
                "context_length": 128000,
                "recommended": True
            },
            {
                "id": "llama2",
                "name": "Llama 2",
                "description": "Meta's Llama 2",
                "context_length": 4096,
                "recommended": False
            },
            {
                "id": "mistral",
                "name": "Mistral",
                "description": "Mistral 7B model",
                "context_length": 8192,
                "recommended": True
            },
            {
                "id": "mixtral",
                "name": "Mixtral",
                "description": "Mixtral 8x7B model",
                "context_length": 32768,
                "recommended": True
            },
            {
                "id": "gemma2",
                "name": "Gemma 2",
                "description": "Google's Gemma 2",
                "context_length": 8192,
                "recommended": True
            },
            {
                "id": "phi3",
                "name": "Phi-3",
                "description": "Microsoft's Phi-3",
                "context_length": 128000,
                "recommended": False
            },
            {
                "id": "qwen2",
                "name": "Qwen 2",
                "description": "Alibaba's Qwen 2",
                "context_length": 32768,
                "recommended": False
            },
            {
                "id": "codellama",
                "name": "Code Llama",
                "description": "Code-focused Llama",
                "context_length": 16384,
                "recommended": False
            },
            {
                "id": "vicuna",
                "name": "Vicuna",
                "description": "LMSys Vicuna",
                "context_length": 2048,
                "recommended": False
            },
        ],
        "requires_api_key": False,
        "note": "Requires Ollama running locally. Use 'ollama pull <model>' to download."
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

    return {
        "generator_type": generator_type,
        **GENERATOR_MODELS[generator_type]
    }


@router.get("/models/all")
async def list_all_models():
    """
    Get list of all available models for all generator types

    Returns:
        Complete model catalog organized by generator type
    """
    return {
        "generators": GENERATOR_MODELS,
        "total_generators": len(GENERATOR_MODELS),
        "total_models": sum(len(data["models"]) for data in GENERATOR_MODELS.values())
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
