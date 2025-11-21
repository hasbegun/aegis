"""
Test Configuration
Central configuration for all LLM security tests
"""

import os
from pathlib import Path
from typing import Dict, Any

# Load .env file if it exists
try:
    from dotenv import load_dotenv
    env_path = Path(__file__).parent / '.env'
    if env_path.exists():
        load_dotenv(env_path)
        print(f"[Config] Loaded .env from {env_path}")
except ImportError:
    pass  # python-dotenv not installed, use system env vars

# Backend API Configuration
API_BASE_URL = os.getenv("INNOX_API_URL", "http://localhost:8888")
API_TIMEOUT = int(os.getenv("API_TIMEOUT", "300"))

# Target LLM Configuration (Open WebUI with Ollama)
TARGET_CONFIG = {
    "generator_type": "rest",
    "uri": os.getenv("OPENWEBUI_URL", "http://localhost:3030/api/v1/chat/completions"),
    "method": "POST",
    "headers": {
        "Content-Type": "application/json",
        "Authorization": f"Bearer {os.getenv('OPENWEBUI_API_KEY', 'sk-15bdf48030cd4a7e8ee6d98e2ff3faa2')}"
    },
    "req_template_json_object": {
        "model": os.getenv("OLLAMA_MODEL", "mistral:latest"),
        "messages": [
            {"role": "user", "content": "$INPUT"}
        ],
        "stream": False
    },
    "response_json_field": "choices[0].message.content"
}

# Test Execution Configuration
DEFAULT_GENERATIONS = int(os.getenv("TEST_GENERATIONS", "10"))
QUICK_GENERATIONS = 3
FULL_GENERATIONS = 25

# Report Configuration
REPORTS_DIR = os.path.join(os.path.dirname(__file__), "reports")
os.makedirs(REPORTS_DIR, exist_ok=True)

# Test Sections Configuration
TEST_SECTIONS = {
    "section_1": {
        "name": "Prompt Injection",
        "description": "Tests for system prompt extraction and instruction override",
        "time_estimate": "30-45 min",
        "severity": "CRITICAL"
    },
    "section_2": {
        "name": "Jailbreak & DAN",
        "description": "Tests for jailbreak techniques and DAN attacks",
        "time_estimate": "45-60 min",
        "severity": "CRITICAL"
    },
    "section_3": {
        "name": "Data Leakage",
        "description": "Tests for PII and training data extraction",
        "time_estimate": "30-40 min",
        "severity": "HIGH"
    },
    "section_4": {
        "name": "Toxicity & Harm",
        "description": "Tests for harmful content generation",
        "time_estimate": "20-30 min",
        "severity": "HIGH"
    },
    "section_5": {
        "name": "Encoding Attacks",
        "description": "Tests for obfuscation and encoding bypasses",
        "time_estimate": "20-30 min",
        "severity": "MEDIUM"
    }
}


def get_scan_config(probes: list, generations: int = None) -> Dict[str, Any]:
    """
    Generate scan configuration for API request

    Args:
        probes: List of probe names or categories
        generations: Number of generations per probe

    Returns:
        Scan configuration dictionary matching ScanConfigRequest schema
    """
    if generations is None:
        generations = DEFAULT_GENERATIONS

    # Backend expects ScanConfigRequest format:
    # - target_type: Generator type (e.g., 'huggingface', 'openai')
    # - target_name: Model name
    # - probes: List of probe names
    # - generations: Number of test generations
    return {
        "target_type": "huggingface",  # Standard generator type
        "target_name": os.getenv("OLLAMA_MODEL", "mistral:latest"),
        "probes": probes,
        "generations": generations
    }


def print_section_header(section_key: str):
    """Print formatted section header"""
    section = TEST_SECTIONS.get(section_key, {})
    name = section.get("name", "Unknown Section")
    description = section.get("description", "")
    time_estimate = section.get("time_estimate", "Unknown")
    severity = section.get("severity", "MEDIUM")

    print("\n" + "=" * 70)
    print(f"  {name.upper()}")
    print("=" * 70)
    print(f"Description:  {description}")
    print(f"Severity:     {severity}")
    print(f"Time:         {time_estimate}")
    print("=" * 70 + "\n")
