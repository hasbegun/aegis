"""
Tests for CLI flag support in ScanConfigRequest schema and ScanManager._build_command.

Covers M22 (--report_threshold) and M24 (--collect_timing).
"""
import json
import sys
import os
import pytest

# Add backend root to path so we can import modules
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))
sys.path.insert(0, os.path.join(os.path.dirname(__file__), "..", "services", "garak_service"))

from models.schemas import ScanConfigRequest


# ---------------------------------------------------------------------------
# Schema validation tests
# ---------------------------------------------------------------------------

class TestReportThresholdSchema:
    """M22: --report_threshold schema validation."""

    def test_default_is_none(self):
        config = ScanConfigRequest(target_type="ollama", target_name="llama3.2:3b")
        assert config.report_threshold is None

    def test_valid_value(self):
        config = ScanConfigRequest(
            target_type="ollama",
            target_name="llama3.2:3b",
            report_threshold=0.75,
        )
        assert config.report_threshold == 0.75

    def test_zero_is_valid(self):
        config = ScanConfigRequest(
            target_type="ollama",
            target_name="llama3.2:3b",
            report_threshold=0.0,
        )
        assert config.report_threshold == 0.0

    def test_one_is_valid(self):
        config = ScanConfigRequest(
            target_type="ollama",
            target_name="llama3.2:3b",
            report_threshold=1.0,
        )
        assert config.report_threshold == 1.0

    def test_negative_rejected(self):
        with pytest.raises(Exception):
            ScanConfigRequest(
                target_type="ollama",
                target_name="llama3.2:3b",
                report_threshold=-0.1,
            )

    def test_above_one_rejected(self):
        with pytest.raises(Exception):
            ScanConfigRequest(
                target_type="ollama",
                target_name="llama3.2:3b",
                report_threshold=1.1,
            )

    def test_serialization_roundtrip(self):
        config = ScanConfigRequest(
            target_type="ollama",
            target_name="llama3.2:3b",
            report_threshold=0.42,
        )
        data = config.model_dump()
        assert data["report_threshold"] == 0.42
        restored = ScanConfigRequest(**data)
        assert restored.report_threshold == 0.42

    def test_none_omitted_in_json(self):
        config = ScanConfigRequest(target_type="ollama", target_name="llama3.2:3b")
        data = config.model_dump(exclude_none=True)
        assert "report_threshold" not in data


class TestCollectTimingSchema:
    """M24: --collect_timing schema validation."""

    def test_default_is_false(self):
        config = ScanConfigRequest(target_type="ollama", target_name="llama3.2:3b")
        assert config.collect_timing is False

    def test_set_true(self):
        config = ScanConfigRequest(
            target_type="ollama",
            target_name="llama3.2:3b",
            collect_timing=True,
        )
        assert config.collect_timing is True

    def test_set_false_explicitly(self):
        config = ScanConfigRequest(
            target_type="ollama",
            target_name="llama3.2:3b",
            collect_timing=False,
        )
        assert config.collect_timing is False

    def test_serialization_roundtrip(self):
        config = ScanConfigRequest(
            target_type="ollama",
            target_name="llama3.2:3b",
            collect_timing=True,
        )
        data = config.model_dump()
        assert data["collect_timing"] is True
        restored = ScanConfigRequest(**data)
        assert restored.collect_timing is True


# ---------------------------------------------------------------------------
# CLI command building tests
# ---------------------------------------------------------------------------

class TestBuildCommandReportThreshold:
    """M22: --report_threshold in CLI command builder."""

    def _build(self, config_overrides: dict) -> list[str]:
        """Helper: build command from a config dict via ScanManager._build_command."""
        from scan_manager import ScanManager
        mgr = ScanManager.__new__(ScanManager)
        mgr.garak_path = "/usr/local/bin/garak"
        base = {"target_type": "ollama", "target_name": "llama3.2:3b"}
        base.update(config_overrides)
        return mgr._build_command(base)

    def test_not_present_when_none(self):
        cmd = self._build({})
        assert "--report_threshold" not in cmd

    def test_present_when_set(self):
        cmd = self._build({"report_threshold": 0.75})
        idx = cmd.index("--report_threshold")
        assert cmd[idx + 1] == "0.75"

    def test_zero_value(self):
        cmd = self._build({"report_threshold": 0.0})
        # 0.0 is falsy in Python but `is not None` check should still include it
        idx = cmd.index("--report_threshold")
        assert cmd[idx + 1] == "0.0"

    def test_one_value(self):
        cmd = self._build({"report_threshold": 1.0})
        idx = cmd.index("--report_threshold")
        assert cmd[idx + 1] == "1.0"


class TestBuildCommandCollectTiming:
    """M24: --collect_timing in CLI command builder."""

    def _build(self, config_overrides: dict) -> list[str]:
        from scan_manager import ScanManager
        mgr = ScanManager.__new__(ScanManager)
        mgr.garak_path = "/usr/local/bin/garak"
        base = {"target_type": "ollama", "target_name": "llama3.2:3b"}
        base.update(config_overrides)
        return mgr._build_command(base)

    def test_not_present_when_false(self):
        cmd = self._build({})
        assert "--collect_timing" not in cmd

    def test_not_present_when_explicitly_false(self):
        cmd = self._build({"collect_timing": False})
        assert "--collect_timing" not in cmd

    def test_present_when_true(self):
        cmd = self._build({"collect_timing": True})
        assert "--collect_timing" in cmd

    def test_is_standalone_flag(self):
        """--collect_timing should be a standalone flag, not followed by a value."""
        cmd = self._build({"collect_timing": True})
        idx = cmd.index("--collect_timing")
        # Next element (if any) should be a different flag or end of list
        if idx + 1 < len(cmd):
            assert cmd[idx + 1].startswith("--") or cmd[idx + 1].startswith("-")


# ---------------------------------------------------------------------------
# Combined / integration-style tests
# ---------------------------------------------------------------------------

class TestBuildCommandCombined:
    """Test both flags together with other existing flags."""

    def _build(self, config_overrides: dict) -> list[str]:
        from scan_manager import ScanManager
        mgr = ScanManager.__new__(ScanManager)
        mgr.garak_path = "/usr/local/bin/garak"
        base = {"target_type": "ollama", "target_name": "llama3.2:3b"}
        base.update(config_overrides)
        return mgr._build_command(base)

    def test_both_flags_present(self):
        cmd = self._build({
            "report_threshold": 0.5,
            "collect_timing": True,
        })
        assert "--report_threshold" in cmd
        assert "--collect_timing" in cmd
        idx = cmd.index("--report_threshold")
        assert cmd[idx + 1] == "0.5"

    def test_both_flags_with_existing_flags(self):
        cmd = self._build({
            "report_threshold": 0.8,
            "collect_timing": True,
            "timeout_per_probe": 120,
            "continue_on_error": True,
            "extended_detectors": True,
        })
        assert "--report_threshold" in cmd
        assert "--collect_timing" in cmd
        assert "--timeout_per_probe" in cmd
        assert "--continue_on_error" in cmd
        assert "--extended_detectors" in cmd

    def test_schema_to_command_roundtrip(self):
        """Validate schema -> dict -> command pipeline."""
        config = ScanConfigRequest(
            target_type="ollama",
            target_name="llama3.2:3b",
            report_threshold=0.65,
            collect_timing=True,
            generations=3,
        )
        cmd = self._build(config.model_dump())
        assert "--report_threshold" in cmd
        assert "--collect_timing" in cmd
        idx = cmd.index("--report_threshold")
        assert cmd[idx + 1] == "0.65"
