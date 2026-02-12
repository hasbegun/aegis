"""
File-based storage for user config templates.

Templates are stored as individual JSON files in a configurable directory
(default: alongside garak reports at /data/config_templates).
"""
import json
import logging
import re
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any

from config import settings

logger = logging.getLogger(__name__)

# Reserved names that conflict with built-in presets
RESERVED_NAMES = frozenset({"fast", "default", "full", "owasp"})

# Filename-safe pattern: alphanumeric, hyphens, underscores, spaces
_SAFE_NAME_RE = re.compile(r"^[\w\s-]+$")


def _slug(name: str) -> str:
    """Convert a template name to a safe filename slug."""
    return re.sub(r"[^\w-]", "_", name.strip().lower())


class ConfigTemplateStore:
    """CRUD operations for user config templates stored as JSON files."""

    def __init__(self, templates_dir: Optional[Path] = None):
        self._dir = templates_dir or (settings.garak_reports_path.parent / "config_templates")
        self._dir.mkdir(parents=True, exist_ok=True)
        logger.info(f"Config templates directory: {self._dir}")

    # ------------------------------------------------------------------
    # Helpers
    # ------------------------------------------------------------------

    def _file_for(self, name: str) -> Path:
        return self._dir / f"{_slug(name)}.json"

    @staticmethod
    def _validate_name(name: str) -> Optional[str]:
        """Return an error message if the name is invalid, else None."""
        name = name.strip()
        if not name:
            return "Template name cannot be empty"
        if len(name) > 100:
            return "Template name must be 100 characters or less"
        if not _SAFE_NAME_RE.match(name):
            return "Template name can only contain letters, numbers, spaces, hyphens, and underscores"
        if _slug(name) in {_slug(n) for n in RESERVED_NAMES}:
            return f"'{name}' conflicts with a built-in preset name"
        return None

    # ------------------------------------------------------------------
    # CRUD
    # ------------------------------------------------------------------

    def list_templates(self) -> List[Dict[str, Any]]:
        """Return all saved templates, sorted by updated_at descending."""
        templates = []
        for path in self._dir.glob("*.json"):
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
                templates.append(data)
            except (json.JSONDecodeError, OSError) as e:
                logger.warning(f"Skipping invalid template file {path}: {e}")
        templates.sort(key=lambda t: t.get("updated_at", ""), reverse=True)
        return templates

    def get_template(self, name: str) -> Optional[Dict[str, Any]]:
        """Get a template by name. Returns None if not found."""
        path = self._file_for(name)
        if not path.exists():
            return None
        try:
            return json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as e:
            logger.error(f"Error reading template {name}: {e}")
            return None

    def save_template(
        self,
        name: str,
        config: Dict[str, Any],
        description: Optional[str] = None,
    ) -> Dict[str, Any]:
        """Create a new template. Raises ValueError if name is invalid or taken."""
        error = self._validate_name(name)
        if error:
            raise ValueError(error)

        path = self._file_for(name)
        if path.exists():
            raise ValueError(f"Template '{name}' already exists. Use update to modify it.")

        now = datetime.now().isoformat()
        template = {
            "name": name.strip(),
            "description": description,
            "config": config,
            "created_at": now,
            "updated_at": now,
        }
        path.write_text(json.dumps(template, indent=2), encoding="utf-8")
        logger.info(f"Created config template: {name}")
        return template

    def update_template(
        self,
        name: str,
        config: Optional[Dict[str, Any]] = None,
        description: Optional[str] = ...,  # sentinel: ... means "not provided"
    ) -> Dict[str, Any]:
        """Update an existing template. Raises ValueError if not found."""
        path = self._file_for(name)
        if not path.exists():
            raise ValueError(f"Template '{name}' not found")

        try:
            existing = json.loads(path.read_text(encoding="utf-8"))
        except (json.JSONDecodeError, OSError) as e:
            raise ValueError(f"Error reading template '{name}': {e}")

        if config is not None:
            existing["config"] = config
        if description is not ...:
            existing["description"] = description
        existing["updated_at"] = datetime.now().isoformat()

        path.write_text(json.dumps(existing, indent=2), encoding="utf-8")
        logger.info(f"Updated config template: {name}")
        return existing

    def delete_template(self, name: str) -> bool:
        """Delete a template. Returns True if deleted, False if not found."""
        path = self._file_for(name)
        if not path.exists():
            return False
        try:
            path.unlink()
            logger.info(f"Deleted config template: {name}")
            return True
        except OSError as e:
            logger.error(f"Error deleting template {name}: {e}")
            return False


# Global instance
config_template_store = ConfigTemplateStore()
