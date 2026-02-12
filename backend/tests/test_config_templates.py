"""
Tests for M19: Config save/load endpoints (user templates).

Covers:
- ConfigTemplateStore CRUD operations
- Name validation (empty, too long, reserved, special chars)
- File-based persistence (JSON files on disk)
- Duplicate name prevention
- Update semantics (config, description, updated_at)
- List ordering (most recently updated first)
- Delete behavior
- Pydantic model validation
"""
import json
import os
import sys
import time
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from services.config_template_store import ConfigTemplateStore, _slug, RESERVED_NAMES


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

SAMPLE_CONFIG = {
    "target_type": "ollama",
    "target_name": "llama3.2:3b",
    "probes": ["dan", "encoding"],
    "generations": 10,
    "eval_threshold": 0.5,
}


@pytest.fixture
def store(tmp_path):
    """Create a ConfigTemplateStore backed by a temporary directory."""
    with patch("services.config_template_store.settings") as mock_settings:
        mock_settings.garak_reports_path = tmp_path / "reports"
        mock_settings.garak_reports_path.mkdir()
        s = ConfigTemplateStore(templates_dir=tmp_path / "templates")
    return s


# ---------------------------------------------------------------------------
# Slug generation
# ---------------------------------------------------------------------------

class TestSlug:

    def test_lowercase_and_spaces(self):
        assert _slug("My Template") == "my_template"

    def test_special_chars_replaced(self):
        assert _slug("test@#$%") == "test____"

    def test_hyphens_preserved(self):
        assert _slug("my-template") == "my-template"

    def test_underscores_preserved(self):
        assert _slug("my_template") == "my_template"


# ---------------------------------------------------------------------------
# Name validation
# ---------------------------------------------------------------------------

class TestNameValidation:

    def test_valid_name(self, store):
        # Should not raise
        store.save_template("my-template", SAMPLE_CONFIG)

    def test_empty_name_rejected(self, store):
        with pytest.raises(ValueError, match="cannot be empty"):
            store.save_template("", SAMPLE_CONFIG)

    def test_whitespace_only_rejected(self, store):
        with pytest.raises(ValueError, match="cannot be empty"):
            store.save_template("   ", SAMPLE_CONFIG)

    def test_too_long_name_rejected(self, store):
        with pytest.raises(ValueError, match="100 characters"):
            store.save_template("x" * 101, SAMPLE_CONFIG)

    def test_special_chars_rejected(self, store):
        with pytest.raises(ValueError, match="letters, numbers"):
            store.save_template("test@template", SAMPLE_CONFIG)

    def test_reserved_name_fast(self, store):
        with pytest.raises(ValueError, match="built-in preset"):
            store.save_template("fast", SAMPLE_CONFIG)

    def test_reserved_name_default(self, store):
        with pytest.raises(ValueError, match="built-in preset"):
            store.save_template("default", SAMPLE_CONFIG)

    def test_reserved_name_full(self, store):
        with pytest.raises(ValueError, match="built-in preset"):
            store.save_template("full", SAMPLE_CONFIG)

    def test_reserved_name_owasp(self, store):
        with pytest.raises(ValueError, match="built-in preset"):
            store.save_template("owasp", SAMPLE_CONFIG)

    def test_reserved_name_case_insensitive(self, store):
        with pytest.raises(ValueError, match="built-in preset"):
            store.save_template("FAST", SAMPLE_CONFIG)

    def test_name_with_spaces_allowed(self, store):
        t = store.save_template("My Custom Template", SAMPLE_CONFIG)
        assert t["name"] == "My Custom Template"

    def test_name_with_numbers_allowed(self, store):
        t = store.save_template("template123", SAMPLE_CONFIG)
        assert t["name"] == "template123"


# ---------------------------------------------------------------------------
# Create (save)
# ---------------------------------------------------------------------------

class TestCreate:

    def test_save_returns_template(self, store):
        t = store.save_template("test", SAMPLE_CONFIG, description="A test template")
        assert t["name"] == "test"
        assert t["description"] == "A test template"
        assert t["config"] == SAMPLE_CONFIG
        assert "created_at" in t
        assert "updated_at" in t
        assert t["created_at"] == t["updated_at"]

    def test_save_creates_file(self, store):
        store.save_template("test", SAMPLE_CONFIG)
        path = store._file_for("test")
        assert path.exists()
        data = json.loads(path.read_text())
        assert data["name"] == "test"
        assert data["config"] == SAMPLE_CONFIG

    def test_duplicate_name_rejected(self, store):
        store.save_template("test", SAMPLE_CONFIG)
        with pytest.raises(ValueError, match="already exists"):
            store.save_template("test", SAMPLE_CONFIG)

    def test_description_optional(self, store):
        t = store.save_template("no-desc", SAMPLE_CONFIG)
        assert t["description"] is None

    def test_config_preserved_exactly(self, store):
        config = {
            "target_type": "openai",
            "target_name": "gpt-4",
            "probes": ["all"],
            "generations": 20,
            "system_prompt": "You are a helpful assistant",
            "generator_options": {"temperature": 0.7},
        }
        t = store.save_template("complex", config)
        assert t["config"] == config


# ---------------------------------------------------------------------------
# Read (get)
# ---------------------------------------------------------------------------

class TestGet:

    def test_get_existing(self, store):
        store.save_template("test", SAMPLE_CONFIG, description="desc")
        t = store.get_template("test")
        assert t is not None
        assert t["name"] == "test"
        assert t["description"] == "desc"

    def test_get_nonexistent(self, store):
        assert store.get_template("nonexistent") is None

    def test_get_returns_full_data(self, store):
        store.save_template("test", SAMPLE_CONFIG)
        t = store.get_template("test")
        assert "name" in t
        assert "config" in t
        assert "created_at" in t
        assert "updated_at" in t


# ---------------------------------------------------------------------------
# Update
# ---------------------------------------------------------------------------

class TestUpdate:

    def test_update_config(self, store):
        store.save_template("test", SAMPLE_CONFIG)
        new_config = {"target_type": "openai", "target_name": "gpt-4", "probes": ["all"]}
        t = store.update_template("test", config=new_config)
        assert t["config"] == new_config

    def test_update_description(self, store):
        store.save_template("test", SAMPLE_CONFIG, description="old")
        t = store.update_template("test", description="new desc")
        assert t["description"] == "new desc"
        # Config should be unchanged
        assert t["config"] == SAMPLE_CONFIG

    def test_update_changes_updated_at(self, store):
        t1 = store.save_template("test", SAMPLE_CONFIG)
        time.sleep(0.01)
        t2 = store.update_template("test", description="updated")
        assert t2["updated_at"] > t1["updated_at"]
        assert t2["created_at"] == t1["created_at"]

    def test_update_nonexistent_raises(self, store):
        with pytest.raises(ValueError, match="not found"):
            store.update_template("ghost", config=SAMPLE_CONFIG)

    def test_update_persisted_to_file(self, store):
        store.save_template("test", SAMPLE_CONFIG)
        new_config = {"probes": ["all"]}
        store.update_template("test", config=new_config)
        # Re-read from disk
        data = json.loads(store._file_for("test").read_text())
        assert data["config"] == new_config


# ---------------------------------------------------------------------------
# Delete
# ---------------------------------------------------------------------------

class TestDelete:

    def test_delete_existing(self, store):
        store.save_template("test", SAMPLE_CONFIG)
        assert store.delete_template("test") is True
        assert store.get_template("test") is None

    def test_delete_nonexistent(self, store):
        assert store.delete_template("ghost") is False

    def test_delete_removes_file(self, store):
        store.save_template("test", SAMPLE_CONFIG)
        path = store._file_for("test")
        assert path.exists()
        store.delete_template("test")
        assert not path.exists()


# ---------------------------------------------------------------------------
# List
# ---------------------------------------------------------------------------

class TestList:

    def test_list_empty(self, store):
        assert store.list_templates() == []

    def test_list_single(self, store):
        store.save_template("one", SAMPLE_CONFIG)
        templates = store.list_templates()
        assert len(templates) == 1
        assert templates[0]["name"] == "one"

    def test_list_multiple_sorted_by_updated_at(self, store):
        store.save_template("first", SAMPLE_CONFIG)
        time.sleep(0.01)
        store.save_template("second", SAMPLE_CONFIG)
        time.sleep(0.01)
        store.save_template("third", SAMPLE_CONFIG)

        templates = store.list_templates()
        names = [t["name"] for t in templates]
        assert names == ["third", "second", "first"]

    def test_list_after_update_reorders(self, store):
        store.save_template("old", SAMPLE_CONFIG)
        time.sleep(0.01)
        store.save_template("new", SAMPLE_CONFIG)
        time.sleep(0.01)
        # Update "old" so it becomes most recent
        store.update_template("old", description="refreshed")

        templates = store.list_templates()
        names = [t["name"] for t in templates]
        assert names[0] == "old"

    def test_list_after_delete(self, store):
        store.save_template("keep", SAMPLE_CONFIG)
        store.save_template("remove", SAMPLE_CONFIG)
        store.delete_template("remove")
        templates = store.list_templates()
        assert len(templates) == 1
        assert templates[0]["name"] == "keep"


# ---------------------------------------------------------------------------
# Pydantic model validation
# ---------------------------------------------------------------------------

class TestPydanticModels:

    def test_template_validates(self, store):
        from models.schemas import ConfigTemplate
        store.save_template("test", SAMPLE_CONFIG, description="desc")
        data = store.get_template("test")
        template = ConfigTemplate(**data)
        assert template.name == "test"
        assert template.description == "desc"

    def test_list_response_validates(self, store):
        from models.schemas import ConfigTemplateListResponse
        store.save_template("one", SAMPLE_CONFIG)
        store.save_template("two", SAMPLE_CONFIG)
        templates = store.list_templates()
        response = ConfigTemplateListResponse(templates=templates, total_count=len(templates))
        assert response.total_count == 2
        assert len(response.templates) == 2

    def test_save_request_validates(self):
        from models.schemas import ConfigTemplateSave
        req = ConfigTemplateSave(name="test", config=SAMPLE_CONFIG, description="desc")
        assert req.name == "test"

    def test_save_request_rejects_empty_name(self):
        from models.schemas import ConfigTemplateSave
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            ConfigTemplateSave(name="", config=SAMPLE_CONFIG)

    def test_save_request_rejects_long_name(self):
        from models.schemas import ConfigTemplateSave
        from pydantic import ValidationError
        with pytest.raises(ValidationError):
            ConfigTemplateSave(name="x" * 101, config=SAMPLE_CONFIG)


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

class TestEdgeCases:

    def test_malformed_json_file_skipped_in_list(self, store):
        """A corrupt file should be skipped, not crash the list."""
        store.save_template("good", SAMPLE_CONFIG)
        bad_file = store._dir / "bad.json"
        bad_file.write_text("not valid json{{{", encoding="utf-8")

        templates = store.list_templates()
        assert len(templates) == 1
        assert templates[0]["name"] == "good"

    def test_directory_created_if_missing(self, tmp_path):
        new_dir = tmp_path / "nonexistent" / "templates"
        with patch("services.config_template_store.settings") as mock_settings:
            mock_settings.garak_reports_path = tmp_path / "reports"
            s = ConfigTemplateStore(templates_dir=new_dir)
        assert new_dir.exists()
        s.save_template("test", SAMPLE_CONFIG)
        assert s.get_template("test") is not None

    def test_name_stripped(self, store):
        t = store.save_template("  padded  ", SAMPLE_CONFIG)
        assert t["name"] == "padded"
