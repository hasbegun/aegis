"""
Tests for M15: Scan result caching layer.

Covers:
- Cache hit/miss behavior
- TTL expiry
- mtime-based invalidation
- Manual invalidation (delete_scan, invalidate_cache, clear_cache)
- Shared cache between _parse_report_file, get_probe_details, get_probe_attempts
"""
import json
import os
import sys
import time
import tempfile
from pathlib import Path
from unittest.mock import patch

import pytest

# Add backend root to path so we can import modules
sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from services.garak_wrapper import GarakWrapper, REPORT_CACHE_TTL


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

SCAN_ID = "test-scan-001"


def _make_report_jsonl(entries: list[dict]) -> str:
    """Serialize a list of dicts to JSONL string."""
    return "\n".join(json.dumps(e) for e in entries)


def _sample_entries() -> list[dict]:
    """Minimal JSONL entries that _parse_report_file can process."""
    return [
        {
            "entry_type": "config",
            "plugins.target_type": "ollama",
            "plugins.target_name": "llama3.2:3b",
            "transient.starttime_iso": "2025-01-01T00:00:00",
            "transient.endtime_iso": "2025-01-01T00:05:00",
        },
        {
            "entry_type": "attempt",
            "probe_classname": "dan.DanJailbreak",
            "status": 2,
            "goal": "Jailbreak the model",
        },
        {
            "entry_type": "attempt",
            "probe_classname": "dan.DanJailbreak",
            "status": 1,
            "goal": "Jailbreak the model",
        },
        {
            "entry_type": "attempt",
            "probe_classname": "encoding.InjectBase64",
            "status": 2,
            "goal": "Inject encoded content",
        },
        {
            "entry_type": "eval",
            "probe": "dan.DanJailbreak",
            "detector": "dan.DanDetector",
            "passed": 1,
            "total": 2,
        },
        {
            "entry_type": "digest",
            "eval": {"dan.DanJailbreak": {"score": 0.5}},
        },
    ]


@pytest.fixture
def reports_dir(tmp_path):
    """Create a temporary reports directory with a sample JSONL file."""
    report_file = tmp_path / f"garak.{SCAN_ID}.report.jsonl"
    report_file.write_text(_make_report_jsonl(_sample_entries()))
    return tmp_path


@pytest.fixture
def wrapper(reports_dir):
    """Create a GarakWrapper with the temp reports dir and a short TTL."""
    with patch("services.garak_wrapper.settings") as mock_settings:
        mock_settings.garak_service_url = "http://localhost:9090"
        mock_settings.garak_reports_path = reports_dir
        w = GarakWrapper(cache_ttl=2)  # 2-second TTL for tests
    return w


# ---------------------------------------------------------------------------
# _get_report_entries: basic cache behavior
# ---------------------------------------------------------------------------

class TestGetReportEntries:
    """Test the core cache method."""

    def test_returns_parsed_entries(self, wrapper):
        entries = wrapper._get_report_entries(SCAN_ID)
        assert entries is not None
        assert len(entries) == 6
        assert entries[0]["entry_type"] == "config"

    def test_returns_none_for_missing_scan(self, wrapper):
        entries = wrapper._get_report_entries("nonexistent-scan")
        assert entries is None

    def test_cache_hit_returns_same_object(self, wrapper):
        """Second call should return the exact same list object (cache hit)."""
        first = wrapper._get_report_entries(SCAN_ID)
        second = wrapper._get_report_entries(SCAN_ID)
        assert first is second  # same object reference = cache hit

    def test_cache_populates_internal_dict(self, wrapper):
        assert SCAN_ID not in wrapper._report_cache
        wrapper._get_report_entries(SCAN_ID)
        assert SCAN_ID in wrapper._report_cache
        assert "entries" in wrapper._report_cache[SCAN_ID]
        assert "mtime" in wrapper._report_cache[SCAN_ID]
        assert "cached_at" in wrapper._report_cache[SCAN_ID]


# ---------------------------------------------------------------------------
# TTL expiry
# ---------------------------------------------------------------------------

class TestCacheTTL:
    """Test TTL-based cache invalidation."""

    def test_cache_expires_after_ttl(self, wrapper):
        """After TTL, cache should be refreshed."""
        first = wrapper._get_report_entries(SCAN_ID)
        assert first is not None

        # Artificially expire the cache
        wrapper._report_cache[SCAN_ID]["cached_at"] = time.monotonic() - 10

        second = wrapper._get_report_entries(SCAN_ID)
        assert second is not None
        # New object = cache was refreshed
        assert first is not second
        assert len(second) == len(first)

    def test_cache_valid_within_ttl(self, wrapper):
        """Within TTL, cache should return same object."""
        first = wrapper._get_report_entries(SCAN_ID)
        # Don't manipulate cached_at, just call again immediately
        second = wrapper._get_report_entries(SCAN_ID)
        assert first is second


# ---------------------------------------------------------------------------
# mtime-based invalidation
# ---------------------------------------------------------------------------

class TestCacheMtimeInvalidation:
    """Test that file changes invalidate the cache."""

    def test_mtime_change_refreshes_cache(self, wrapper, reports_dir):
        """If the file is rewritten, cache should be invalidated."""
        first = wrapper._get_report_entries(SCAN_ID)
        assert first is not None

        # Rewrite the file with different content (adds an entry)
        report_file = reports_dir / f"garak.{SCAN_ID}.report.jsonl"
        entries = _sample_entries()
        entries.append({
            "entry_type": "attempt",
            "probe_classname": "encoding.InjectBase64",
            "status": 1,
            "goal": "Inject encoded content",
        })
        # Ensure mtime changes by writing with a slight delay
        time.sleep(0.05)
        report_file.write_text(_make_report_jsonl(entries))

        second = wrapper._get_report_entries(SCAN_ID)
        assert second is not None
        assert len(second) == 7  # one more entry
        assert first is not second


# ---------------------------------------------------------------------------
# Manual invalidation
# ---------------------------------------------------------------------------

class TestManualInvalidation:
    """Test invalidate_cache and clear_cache."""

    def test_invalidate_cache_removes_entry(self, wrapper):
        wrapper._get_report_entries(SCAN_ID)
        assert SCAN_ID in wrapper._report_cache

        wrapper.invalidate_cache(SCAN_ID)
        assert SCAN_ID not in wrapper._report_cache

    def test_invalidate_cache_nonexistent_is_noop(self, wrapper):
        """Invalidating a scan that's not cached should not raise."""
        wrapper.invalidate_cache("nonexistent")  # no error

    def test_clear_cache_removes_all(self, wrapper, reports_dir):
        """clear_cache should empty the entire cache."""
        # Create a second scan
        scan_id2 = "test-scan-002"
        report2 = reports_dir / f"garak.{scan_id2}.report.jsonl"
        report2.write_text(_make_report_jsonl(_sample_entries()))

        wrapper._get_report_entries(SCAN_ID)
        wrapper._get_report_entries(scan_id2)
        assert len(wrapper._report_cache) == 2

        wrapper.clear_cache()
        assert len(wrapper._report_cache) == 0

    def test_delete_scan_invalidates_cache(self, wrapper):
        """delete_scan should remove the scan from cache."""
        wrapper._get_report_entries(SCAN_ID)
        assert SCAN_ID in wrapper._report_cache

        wrapper.delete_scan(SCAN_ID)
        assert SCAN_ID not in wrapper._report_cache


# ---------------------------------------------------------------------------
# Shared cache across methods
# ---------------------------------------------------------------------------

class TestSharedCache:
    """Test that _parse_report_file, get_probe_details, get_probe_attempts
    all share the same cached entries."""

    def test_parse_report_uses_cache(self, wrapper, reports_dir):
        """_parse_report_file should populate cache, second call uses it."""
        report_file = reports_dir / f"garak.{SCAN_ID}.report.jsonl"

        result = wrapper._parse_report_file(report_file, SCAN_ID)
        assert result is not None
        assert result["passed"] == 2
        assert result["failed"] == 1
        assert SCAN_ID in wrapper._report_cache

    def test_probe_details_uses_cache(self, wrapper):
        """get_probe_details should use cached entries."""
        # Pre-populate cache
        wrapper._get_report_entries(SCAN_ID)
        cached_entries = wrapper._report_cache[SCAN_ID]["entries"]

        with patch.object(wrapper, '_get_report_entries', return_value=cached_entries) as mock:
            result = wrapper.get_probe_details(SCAN_ID)
            mock.assert_called_once_with(SCAN_ID)

        assert result is not None
        assert result["total_probes"] == 2  # dan.DanJailbreak, encoding.InjectBase64

    def test_probe_attempts_uses_cache(self, wrapper):
        """get_probe_attempts should use cached entries."""
        # Pre-populate cache
        wrapper._get_report_entries(SCAN_ID)
        cached_entries = wrapper._report_cache[SCAN_ID]["entries"]

        with patch.object(wrapper, '_get_report_entries', return_value=cached_entries) as mock:
            result = wrapper.get_probe_attempts(SCAN_ID, "dan.DanJailbreak")
            mock.assert_called_once_with(SCAN_ID)

        assert result is not None
        assert result["total_attempts"] == 2

    def test_multiple_methods_share_single_parse(self, wrapper, reports_dir):
        """Calling multiple methods on the same scan should only parse once."""
        report_file = reports_dir / f"garak.{SCAN_ID}.report.jsonl"

        # Call three different methods
        wrapper._parse_report_file(report_file, SCAN_ID)
        entries_after_first = wrapper._report_cache[SCAN_ID]["entries"]

        wrapper.get_probe_details(SCAN_ID)
        entries_after_second = wrapper._report_cache[SCAN_ID]["entries"]

        wrapper.get_probe_attempts(SCAN_ID, "dan.DanJailbreak")
        entries_after_third = wrapper._report_cache[SCAN_ID]["entries"]

        # All should be the exact same cached object
        assert entries_after_first is entries_after_second
        assert entries_after_second is entries_after_third


# ---------------------------------------------------------------------------
# Correctness after cache
# ---------------------------------------------------------------------------

class TestCachedResultsCorrectness:
    """Ensure cached data produces correct results."""

    def test_parse_report_counts(self, wrapper, reports_dir):
        report_file = reports_dir / f"garak.{SCAN_ID}.report.jsonl"
        result = wrapper._parse_report_file(report_file, SCAN_ID)
        assert result["passed"] == 2
        assert result["failed"] == 1
        assert result["total_tests"] == 3
        assert result["target_type"] == "ollama"
        assert result["target_name"] == "llama3.2:3b"
        assert result["digest"] == {"dan.DanJailbreak": {"score": 0.5}}

    def test_probe_details_breakdown(self, wrapper):
        result = wrapper.get_probe_details(SCAN_ID)
        assert result is not None
        probes = {p["probe_classname"]: p for p in result["probes"]}

        dan = probes["dan.DanJailbreak"]
        assert dan["passed"] == 1
        assert dan["failed"] == 1
        assert dan["total"] == 2
        assert dan["pass_rate"] == 50.0

        enc = probes["encoding.InjectBase64"]
        assert enc["passed"] == 1
        assert enc["failed"] == 0
        assert enc["total"] == 1
        assert enc["pass_rate"] == 100.0

    def test_probe_attempts_for_probe(self, wrapper):
        result = wrapper.get_probe_attempts(SCAN_ID, "dan.DanJailbreak")
        assert result is not None
        assert result["total_attempts"] == 2

        statuses = {a["status"] for a in result["attempts"]}
        assert statuses == {"passed", "failed"}

    def test_probe_attempts_filter(self, wrapper):
        result = wrapper.get_probe_attempts(
            SCAN_ID, "dan.DanJailbreak", status_filter="failed"
        )
        assert result is not None
        assert result["total_attempts"] == 1
        assert result["attempts"][0]["status"] == "failed"


# ---------------------------------------------------------------------------
# Edge cases
# ---------------------------------------------------------------------------

class TestCacheEdgeCases:
    """Edge cases for the cache."""

    def test_empty_report_file(self, wrapper, reports_dir):
        """Empty JSONL file should return None entries and not cache."""
        scan_id = "empty-scan"
        report_file = reports_dir / f"garak.{scan_id}.report.jsonl"
        report_file.write_text("")

        entries = wrapper._get_report_entries(scan_id)
        # Empty file → empty list → still cached (valid parse)
        assert entries is not None
        assert len(entries) == 0

    def test_malformed_jsonl_lines_skipped(self, wrapper, reports_dir):
        """Malformed lines should be skipped, valid lines cached."""
        scan_id = "malformed-scan"
        report_file = reports_dir / f"garak.{scan_id}.report.jsonl"
        content = (
            '{"entry_type": "config", "plugins.target_type": "ollama"}\n'
            "this is not json\n"
            '{"entry_type": "attempt", "status": 2, "probe_classname": "test.Probe"}\n'
        )
        report_file.write_text(content)

        entries = wrapper._get_report_entries(scan_id)
        assert entries is not None
        assert len(entries) == 2  # skipped the bad line

    def test_file_deleted_after_cache(self, wrapper, reports_dir):
        """If file is deleted after caching, cache still valid until TTL/mtime check."""
        wrapper._get_report_entries(SCAN_ID)
        assert SCAN_ID in wrapper._report_cache

        # Delete the file
        report_file = reports_dir / f"garak.{SCAN_ID}.report.jsonl"
        report_file.unlink()

        # Cache is still valid (file existence check fails, returns None)
        entries = wrapper._get_report_entries(SCAN_ID)
        assert entries is None

    def test_default_ttl_constant(self):
        """Verify the default TTL constant."""
        assert REPORT_CACHE_TTL == 300

    def test_custom_ttl_in_constructor(self, reports_dir):
        """Verify custom TTL can be passed."""
        with patch("services.garak_wrapper.settings") as mock_settings:
            mock_settings.garak_service_url = "http://localhost:9090"
            mock_settings.garak_reports_path = reports_dir
            w = GarakWrapper(cache_ttl=60)
        assert w._cache_ttl == 60


# ---------------------------------------------------------------------------
# Layer 2 (scan info cache) was removed in H1 — DB handles metadata queries.
# ---------------------------------------------------------------------------

class TestParseReportFile:
    """Test _parse_report_file (no longer cached, always re-parses)."""

    def test_parse_returns_correct_data(self, wrapper, reports_dir):
        report_file = reports_dir / f"garak.{SCAN_ID}.report.jsonl"
        result = wrapper._parse_report_file(report_file, SCAN_ID)
        assert result is not None
        assert result["passed"] == 2
        assert result["failed"] == 1

    def test_parse_detects_file_changes(self, wrapper, reports_dir):
        report_file = reports_dir / f"garak.{SCAN_ID}.report.jsonl"
        first = wrapper._parse_report_file(report_file, SCAN_ID)

        # Rewrite file with extra attempt
        time.sleep(0.05)
        entries = _sample_entries()
        entries.append({"entry_type": "attempt", "probe_classname": "x.Y", "status": 1})
        report_file.write_text(_make_report_jsonl(entries))

        second = wrapper._parse_report_file(report_file, SCAN_ID)
        assert second["failed"] == 2  # was 1, now 2


# ---------------------------------------------------------------------------
# Layer 3: _results_cache (get_scan_results for historical scans)
# ---------------------------------------------------------------------------

class TestResultsCache:
    """Test Layer 3 caching of full scan results."""

    def test_get_results_populates_cache(self, wrapper):
        result = wrapper.get_scan_results(SCAN_ID)
        assert result is not None
        assert SCAN_ID in wrapper._results_cache
        assert wrapper._results_cache[SCAN_ID]["data"] is result

    def test_second_get_results_returns_cached(self, wrapper):
        first = wrapper.get_scan_results(SCAN_ID)
        second = wrapper.get_scan_results(SCAN_ID)
        assert first is second  # same object

    def test_results_cache_has_correct_data(self, wrapper):
        result = wrapper.get_scan_results(SCAN_ID)
        assert result["scan_id"] == SCAN_ID
        assert result["status"] == "completed"
        assert result["results"]["passed"] == 2
        assert result["results"]["failed"] == 1
        assert result["digest"] == {"dan.DanJailbreak": {"score": 0.5}}

    def test_active_scan_bypasses_cache(self, wrapper):
        """Active scans should never be cached (live data)."""
        wrapper.active_scans[SCAN_ID] = {
            "scan_id": SCAN_ID,
            "status": "running",
            "passed": 0, "failed": 0,
            "progress": 50.0,
        }
        result = wrapper.get_scan_results(SCAN_ID)
        assert result is not None
        assert SCAN_ID not in wrapper._results_cache

        # Clean up
        del wrapper.active_scans[SCAN_ID]

    def test_mtime_change_refreshes_results(self, wrapper, reports_dir):
        first = wrapper.get_scan_results(SCAN_ID)
        assert first is not None

        time.sleep(0.05)
        entries = _sample_entries()
        entries.append({"entry_type": "attempt", "probe_classname": "x.Y", "status": 1})
        report_file = reports_dir / f"garak.{SCAN_ID}.report.jsonl"
        report_file.write_text(_make_report_jsonl(entries))

        second = wrapper.get_scan_results(SCAN_ID)
        assert second is not first
        assert second["results"]["failed"] == 2

    def test_invalidate_clears_results_cache(self, wrapper):
        wrapper.get_scan_results(SCAN_ID)
        assert SCAN_ID in wrapper._results_cache

        wrapper.invalidate_cache(SCAN_ID)
        assert SCAN_ID not in wrapper._results_cache

    def test_clear_cache_clears_results(self, wrapper):
        wrapper.get_scan_results(SCAN_ID)
        wrapper.clear_cache()
        assert len(wrapper._results_cache) == 0

    def test_nonexistent_scan_returns_none(self, wrapper):
        result = wrapper.get_scan_results("nonexistent")
        assert result is None

    def test_both_cache_layers_cleared_together(self, wrapper, reports_dir):
        """invalidate_cache should clear both remaining cache layers."""
        wrapper._get_report_entries(SCAN_ID)
        wrapper.get_scan_results(SCAN_ID)

        assert SCAN_ID in wrapper._report_cache
        assert SCAN_ID in wrapper._results_cache

        wrapper.invalidate_cache(SCAN_ID)

        assert SCAN_ID not in wrapper._report_cache
        assert SCAN_ID not in wrapper._results_cache
