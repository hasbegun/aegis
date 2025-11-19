"""
Pydantic models for request/response validation
"""
from pydantic import BaseModel, Field
from typing import Optional, List, Dict, Any
from enum import Enum


class ScanStatus(str, Enum):
    """Scan execution status"""
    PENDING = "pending"
    RUNNING = "running"
    COMPLETED = "completed"
    FAILED = "failed"
    CANCELLED = "cancelled"


class GeneratorType(str, Enum):
    """Supported generator types"""
    OPENAI = "openai"
    HUGGINGFACE = "huggingface"
    REPLICATE = "replicate"
    COHERE = "cohere"
    ANTHROPIC = "anthropic"
    LITELLM = "litellm"
    NIM = "nim"


class ScanConfigRequest(BaseModel):
    """Request model for starting a scan"""
    target_type: str = Field(..., description="Generator type (e.g., 'openai')")
    target_name: str = Field(..., description="Model name (e.g., 'gpt-3.5-turbo')")
    probes: List[str] = Field(default=["all"], description="List of probe names or 'all'")
    detectors: Optional[List[str]] = Field(default=None, description="List of detector names (optional)")
    buffs: Optional[List[str]] = Field(default=None, description="List of buffs to apply (optional)")

    # Run parameters
    generations: int = Field(default=5, ge=1, le=100, description="Number of generations per prompt")
    eval_threshold: float = Field(default=0.5, ge=0.0, le=1.0, description="Evaluation threshold")
    seed: Optional[int] = Field(default=None, description="Random seed for reproducibility")

    # System parameters
    parallel_requests: Optional[int] = Field(default=None, ge=1, description="Parallel requests count")
    parallel_attempts: Optional[int] = Field(default=None, ge=1, description="Parallel attempts count")

    # Options
    generator_options: Optional[Dict[str, Any]] = Field(default=None, description="Generator-specific options")
    probe_options: Optional[Dict[str, Any]] = Field(default=None, description="Probe-specific options")

    # Reporting
    report_prefix: Optional[str] = Field(default=None, description="Prefix for report files")

    class Config:
        json_schema_extra = {
            "example": {
                "target_type": "openai",
                "target_name": "gpt-3.5-turbo",
                "probes": ["dan", "encoding"],
                "generations": 10,
                "eval_threshold": 0.5,
                "generator_options": {
                    "temperature": 0.7,
                    "api_key": "sk-..."
                }
            }
        }


class ScanResponse(BaseModel):
    """Response model for scan initiation"""
    scan_id: str = Field(..., description="Unique scan identifier")
    status: ScanStatus = Field(..., description="Current scan status")
    message: str = Field(..., description="Status message")
    created_at: str = Field(..., description="Scan creation timestamp")


class ScanStatusResponse(BaseModel):
    """Response model for scan status query"""
    scan_id: str
    status: ScanStatus
    progress: float = Field(ge=0.0, le=100.0, description="Progress percentage")
    current_probe: Optional[str] = Field(default=None, description="Currently executing probe")
    completed_probes: int = Field(default=0, description="Number of completed probes")
    total_probes: int = Field(default=0, description="Total number of probes")
    passed: int = Field(default=0, description="Number of passed tests")
    failed: int = Field(default=0, description="Number of failed tests")
    elapsed_time: Optional[float] = Field(default=None, description="Elapsed time in seconds")
    estimated_remaining: Optional[float] = Field(default=None, description="Estimated remaining time")
    error_message: Optional[str] = Field(default=None, description="Error message if failed")


class PluginInfo(BaseModel):
    """Information about a plugin (probe, detector, generator, buff)"""
    name: str = Field(..., description="Plugin name")
    full_name: str = Field(..., description="Fully qualified plugin name")
    description: Optional[str] = Field(default=None, description="Plugin description")
    active: bool = Field(default=True, description="Whether plugin is active by default")
    tags: Optional[List[str]] = Field(default=None, description="Plugin tags")
    primary_detector: Optional[str] = Field(default=None, description="Primary detector (for probes)")
    goal: Optional[str] = Field(default=None, description="Plugin goal/purpose")


class PluginListResponse(BaseModel):
    """Response model for plugin listing"""
    plugins: List[PluginInfo]
    total_count: int


class ConfigPreset(BaseModel):
    """Configuration preset"""
    name: str = Field(..., description="Preset name")
    description: Optional[str] = Field(default=None, description="Preset description")
    config: Dict[str, Any] = Field(..., description="Configuration dictionary")


class SystemInfoResponse(BaseModel):
    """System information response"""
    garak_version: str
    python_version: str
    backend_version: str
    garak_installed: bool
    available_generators: List[str]


class ScanResult(BaseModel):
    """Detailed scan result"""
    scan_id: str
    status: ScanStatus
    config: Optional[ScanConfigRequest] = Field(default=None, description="Scan configuration (may not be available for historical scans)")
    results: Dict[str, Any]
    report_path: Optional[str] = Field(default=None)
    created_at: Optional[str] = Field(default=None, description="When the scan was created (may not be available for historical scans)")
    started_at: Optional[str] = Field(default=None, description="When the scan actually started")
    completed_at: Optional[str] = Field(default=None)
    duration: Optional[float] = Field(default=None, description="Scan duration in seconds")
    summary: Optional[Dict[str, Any]] = Field(default=None, description="Results summary")
    html_report_path: Optional[str] = Field(default=None, description="Path to HTML report file")
    jsonl_report_path: Optional[str] = Field(default=None, description="Path to JSONL report file")


# Custom Probe Models
class CustomProbeTemplate(str, Enum):
    """Available probe templates"""
    MINIMAL = "minimal"
    BASIC = "basic"
    ADVANCED = "advanced"


class CustomProbeCreateRequest(BaseModel):
    """Request to create a custom probe"""
    name: str = Field(..., description="Probe class name (must be valid Python identifier)")
    code: str = Field(..., description="Python code for the probe")
    description: Optional[str] = Field(default=None, description="Probe description")

    class Config:
        json_schema_extra = {
            "example": {
                "name": "MyCustomProbe",
                "code": "import garak.probes.base\n\nclass MyCustomProbe(garak.probes.base.Probe):\n    \"\"\"My custom probe\"\"\"\n    prompts = ['Test prompt 1', 'Test prompt 2']",
                "description": "A custom probe for testing"
            }
        }


class CustomProbeValidateRequest(BaseModel):
    """Request to validate probe code"""
    code: str = Field(..., description="Python code to validate")


class ValidationError(BaseModel):
    """Validation error details"""
    line: Optional[int] = Field(default=None, description="Line number where error occurred")
    column: Optional[int] = Field(default=None, description="Column number where error occurred")
    message: str = Field(..., description="Error message")
    error_type: str = Field(..., description="Type of error (syntax, import, structure, etc.)")


class CustomProbeValidationResponse(BaseModel):
    """Response for probe validation"""
    valid: bool = Field(..., description="Whether the probe code is valid")
    errors: List[ValidationError] = Field(default_factory=list, description="List of validation errors")
    warnings: List[str] = Field(default_factory=list, description="List of warnings")
    probe_info: Optional[Dict[str, Any]] = Field(default=None, description="Extracted probe information if valid")


class CustomProbe(BaseModel):
    """Custom probe metadata"""
    name: str = Field(..., description="Probe class name")
    file_path: str = Field(..., description="Path to probe file")
    description: Optional[str] = Field(default=None, description="Probe description")
    created_at: str = Field(..., description="Creation timestamp")
    updated_at: str = Field(..., description="Last update timestamp")
    goal: Optional[str] = Field(default=None, description="Probe goal")
    tags: Optional[List[str]] = Field(default=None, description="Probe tags")
    primary_detector: Optional[str] = Field(default=None, description="Primary detector")


class CustomProbeListResponse(BaseModel):
    """Response for listing custom probes"""
    probes: List[CustomProbe] = Field(..., description="List of custom probes")
    total_count: int = Field(..., description="Total number of custom probes")


class CustomProbeGetResponse(BaseModel):
    """Response for getting a specific custom probe"""
    probe: CustomProbe = Field(..., description="Probe metadata")
    code: str = Field(..., description="Probe source code")
