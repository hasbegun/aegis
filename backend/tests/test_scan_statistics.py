"""
Tests for M18: Scan statistics endpoint.

Covers:
- Empty state (no scans)
- Single scan statistics
- Multiple scans aggregation
- Status counting (completed, failed, cancelled, running)
- Pass rate calculations (overall, avg, min, max)
- Daily trend generation
- Top failing probes aggregation
- Target breakdown
- Days parameter for trend window
"""
import json
import os
import sys
from datetime import datetime, timedelta
from pathlib import Path
from unittest.mock import patch

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from services.garak_wrapper import GarakWrapper


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

def _make_report_jsonl(entries: list[dict]) -> str:
    return "\n".join(json.dumps(e) for e in entries)


def _make_scan_entries(
    target_type: str = "ollama",
    target_name: str = "llama3.2:3b",
    started_at: str = "2026-02-10T12:00:00",
    completed_at: str = "2026-02-10T12:05:00",
    attempts: list[dict] | None = None,
) -> list[dict]:
    """Build a minimal JSONL entry list for a single scan."""
    entries = [
        {
            "entry_type": "config",
            "plugins.target_type": target_type,
            "plugins.target_name": target_name,
            "transient.starttime_iso": started_at,
            "transient.endtime_iso": completed_at,
        },
    ]
    if attempts:
        entries.extend(attempts)
    return entries


def _attempt(probe: str, status: int) -> dict:
    return {"entry_type": "attempt", "probe_classname": probe, "status": status}


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def reports_dir(tmp_path):
    return tmp_path


@pytest.fixture
def wrapper(reports_dir):
    with patch("services.garak_wrapper.settings") as mock_settings:
        mock_settings.garak_service_url = "http://localhost:9090"
        mock_settings.garak_reports_path = reports_dir
        w = GarakWrapper(cache_ttl=300)
    return w


def _write_scan(reports_dir: Path, scan_id: str, entries: list[dict]):
    report_file = reports_dir / f"garak.{scan_id}.report.jsonl"
    report_file.write_text(_make_report_jsonl(entries))


# ---------------------------------------------------------------------------
# Empty state
# ---------------------------------------------------------------------------

class TestEmptyState:

    def test_no_scans_returns_zeros(self, wrapper):
        stats = wrapper.get_scan_statistics()
        assert stats["total_scans"] == 0
        assert stats["completed_scans"] == 0
        assert stats["total_tests"] == 0
        assert stats["overall_pass_rate"] == 0.0
        assert stats["avg_pass_rate"] == 0.0
        assert stats["min_pass_rate"] is None
        assert stats["max_pass_rate"] is None
        assert stats["top_failing_probes"] == []
        assert stats["target_breakdown"] == []

    def test_daily_trends_has_entries_for_requested_days(self, wrapper):
        stats = wrapper.get_scan_statistics(days=7)
        assert len(stats["daily_trends"]) == 7
        # All days should have zero counts
        for point in stats["daily_trends"]:
            assert point["scan_count"] == 0
            assert point["avg_pass_rate"] == 0.0


# ---------------------------------------------------------------------------
# Single scan
# ---------------------------------------------------------------------------

class TestSingleScan:

    def test_counts_single_completed_scan(self, wrapper, reports_dir):
        _write_scan(reports_dir, "scan-1", _make_scan_entries(
            attempts=[
                _attempt("dan.DanJailbreak", 2),  # passed
                _attempt("dan.DanJailbreak", 1),  # failed
                _attempt("encoding.Base64", 2),    # passed
            ]
        ))
        stats = wrapper.get_scan_statistics()
        assert stats["total_scans"] == 1
        assert stats["completed_scans"] == 1
        assert stats["total_tests"] == 3
        assert stats["total_passed"] == 2
        assert stats["total_failed"] == 1

    def test_pass_rate_calculation(self, wrapper, reports_dir):
        _write_scan(reports_dir, "scan-1", _make_scan_entries(
            attempts=[
                _attempt("dan.DanJailbreak", 2),
                _attempt("dan.DanJailbreak", 1),
                _attempt("dan.DanJailbreak", 2),
                _attempt("dan.DanJailbreak", 2),
            ]
        ))
        stats = wrapper.get_scan_statistics()
        assert stats["overall_pass_rate"] == 75.0
        assert stats["avg_pass_rate"] == 75.0
        assert stats["min_pass_rate"] == 75.0
        assert stats["max_pass_rate"] == 75.0

    def test_target_breakdown_single_target(self, wrapper, reports_dir):
        _write_scan(reports_dir, "scan-1", _make_scan_entries(
            target_type="openai", target_name="gpt-4",
            attempts=[_attempt("dan.DanJailbreak", 2)]
        ))
        stats = wrapper.get_scan_statistics()
        assert len(stats["target_breakdown"]) == 1
        target = stats["target_breakdown"][0]
        assert target["target_type"] == "openai"
        assert target["target_name"] == "gpt-4"
        assert target["scan_count"] == 1
        assert target["avg_pass_rate"] == 100.0


# ---------------------------------------------------------------------------
# Multiple scans
# ---------------------------------------------------------------------------

class TestMultipleScans:

    def test_aggregates_across_scans(self, wrapper, reports_dir):
        _write_scan(reports_dir, "scan-1", _make_scan_entries(
            attempts=[
                _attempt("dan.DanJailbreak", 2),
                _attempt("dan.DanJailbreak", 1),
            ]
        ))
        _write_scan(reports_dir, "scan-2", _make_scan_entries(
            started_at="2026-02-11T12:00:00",
            attempts=[
                _attempt("encoding.Base64", 2),
                _attempt("encoding.Base64", 2),
                _attempt("encoding.Base64", 2),
                _attempt("encoding.Base64", 1),
            ]
        ))
        stats = wrapper.get_scan_statistics()
        assert stats["total_scans"] == 2
        assert stats["completed_scans"] == 2
        assert stats["total_tests"] == 6
        assert stats["total_passed"] == 4
        assert stats["total_failed"] == 2

    def test_pass_rate_min_max(self, wrapper, reports_dir):
        # Scan 1: 50% pass rate (1 pass, 1 fail)
        _write_scan(reports_dir, "scan-1", _make_scan_entries(
            attempts=[_attempt("dan.X", 2), _attempt("dan.X", 1)]
        ))
        # Scan 2: 100% pass rate (2 pass, 0 fail)
        _write_scan(reports_dir, "scan-2", _make_scan_entries(
            started_at="2026-02-11T12:00:00",
            attempts=[_attempt("dan.X", 2), _attempt("dan.X", 2)]
        ))
        stats = wrapper.get_scan_statistics()
        assert stats["min_pass_rate"] == 50.0
        assert stats["max_pass_rate"] == 100.0
        assert stats["avg_pass_rate"] == 75.0

    def test_target_breakdown_multiple_targets(self, wrapper, reports_dir):
        _write_scan(reports_dir, "scan-1", _make_scan_entries(
            target_type="ollama", target_name="llama3.2:3b",
            attempts=[_attempt("dan.X", 2)]
        ))
        _write_scan(reports_dir, "scan-2", _make_scan_entries(
            target_type="openai", target_name="gpt-4",
            started_at="2026-02-11T12:00:00",
            attempts=[_attempt("dan.X", 2)]
        ))
        _write_scan(reports_dir, "scan-3", _make_scan_entries(
            target_type="ollama", target_name="llama3.2:3b",
            started_at="2026-02-11T13:00:00",
            attempts=[_attempt("dan.X", 1)]
        ))
        stats = wrapper.get_scan_statistics()
        assert len(stats["target_breakdown"]) == 2
        # Ollama has 2 scans, should be first (sorted by scan_count desc)
        ollama = stats["target_breakdown"][0]
        assert ollama["target_name"] == "llama3.2:3b"
        assert ollama["scan_count"] == 2


# ---------------------------------------------------------------------------
# Status counting
# ---------------------------------------------------------------------------

class TestStatusCounting:

    def test_counts_active_scans(self, wrapper, reports_dir):
        # Add a running scan
        wrapper.active_scans["running-1"] = {
            "scan_id": "running-1",
            "status": "running",
            "progress": 50.0,
            "passed": 3, "failed": 1,
            "started_at": "2026-02-11T10:00:00",
            "target_type": "ollama", "target_name": "llama3.2:3b",
        }
        # Add a completed scan on disk
        _write_scan(reports_dir, "scan-1", _make_scan_entries(
            attempts=[_attempt("dan.X", 2)]
        ))
        stats = wrapper.get_scan_statistics()
        assert stats["total_scans"] == 2
        assert stats["completed_scans"] == 1
        assert stats["running_scans"] == 1

        # Cleanup
        del wrapper.active_scans["running-1"]


# ---------------------------------------------------------------------------
# Daily trends
# ---------------------------------------------------------------------------

class TestDailyTrends:

    def test_trends_cover_requested_days(self, wrapper, reports_dir):
        stats = wrapper.get_scan_statistics(days=14)
        assert len(stats["daily_trends"]) == 14

    def test_trends_sorted_ascending(self, wrapper, reports_dir):
        stats = wrapper.get_scan_statistics(days=7)
        dates = [p["date"] for p in stats["daily_trends"]]
        assert dates == sorted(dates)

    def test_trend_data_for_scan_day(self, wrapper, reports_dir):
        today = datetime.now().strftime("%Y-%m-%d")
        _write_scan(reports_dir, "scan-1", _make_scan_entries(
            started_at=f"{today}T12:00:00",
            completed_at=f"{today}T12:05:00",
            attempts=[_attempt("dan.X", 2), _attempt("dan.X", 1)]
        ))
        stats = wrapper.get_scan_statistics(days=1)
        assert len(stats["daily_trends"]) == 1
        point = stats["daily_trends"][0]
        assert point["date"] == today
        assert point["scan_count"] == 1
        assert point["total_passed"] == 1
        assert point["total_failed"] == 1
        assert point["avg_pass_rate"] == 50.0


# ---------------------------------------------------------------------------
# Top failing probes
# ---------------------------------------------------------------------------

class TestTopFailingProbes:

    def test_probes_aggregated_by_category(self, wrapper, reports_dir):
        _write_scan(reports_dir, "scan-1", _make_scan_entries(
            attempts=[
                _attempt("dan.DanJailbreak", 1),
                _attempt("dan.DanJailbreak", 1),
                _attempt("dan.DanOther", 2),
                _attempt("encoding.Base64", 1),
                _attempt("encoding.Base64", 2),
            ]
        ))
        stats = wrapper.get_scan_statistics()
        probes = {p["probe_category"]: p for p in stats["top_failing_probes"]}
        assert "dan" in probes
        assert "encoding" in probes
        # dan: 2 failed, 1 passed = 3 total
        assert probes["dan"]["failure_count"] == 2
        assert probes["dan"]["total_count"] == 3
        # encoding: 1 failed, 1 passed = 2 total
        assert probes["encoding"]["failure_count"] == 1
        assert probes["encoding"]["total_count"] == 2

    def test_probes_sorted_by_failure_count(self, wrapper, reports_dir):
        _write_scan(reports_dir, "scan-1", _make_scan_entries(
            attempts=[
                _attempt("encoding.X", 1),
                _attempt("dan.X", 1), _attempt("dan.X", 1), _attempt("dan.X", 1),
                _attempt("xss.X", 1), _attempt("xss.X", 1),
            ]
        ))
        stats = wrapper.get_scan_statistics()
        categories = [p["probe_category"] for p in stats["top_failing_probes"]]
        assert categories == ["dan", "xss", "encoding"]

    def test_top_probes_capped_at_10(self, wrapper, reports_dir):
        # Create 15 different probe categories
        attempts = []
        for i in range(15):
            attempts.append(_attempt(f"cat{i}.Probe", 1))
        _write_scan(reports_dir, "scan-1", _make_scan_entries(attempts=attempts))
        stats = wrapper.get_scan_statistics()
        assert len(stats["top_failing_probes"]) <= 10

    def test_failure_rate_calculation(self, wrapper, reports_dir):
        _write_scan(reports_dir, "scan-1", _make_scan_entries(
            attempts=[
                _attempt("dan.X", 1), _attempt("dan.X", 1),
                _attempt("dan.X", 2), _attempt("dan.X", 2),
            ]
        ))
        stats = wrapper.get_scan_statistics()
        dan = stats["top_failing_probes"][0]
        assert dan["probe_category"] == "dan"
        assert dan["failure_rate"] == 50.0


# ---------------------------------------------------------------------------
# Pydantic model validation
# ---------------------------------------------------------------------------

class TestResponseModel:

    def test_response_matches_model(self, wrapper, reports_dir):
        """Verify the dict returned by get_scan_statistics() validates against
        the Pydantic ScanStatisticsResponse model."""
        _write_scan(reports_dir, "scan-1", _make_scan_entries(
            attempts=[_attempt("dan.X", 2), _attempt("dan.X", 1)]
        ))
        stats = wrapper.get_scan_statistics()

        from models.schemas import ScanStatisticsResponse
        response = ScanStatisticsResponse(**stats)
        assert response.total_scans == 1
        assert response.total_tests == 2
        assert len(response.daily_trends) == 30

    def test_empty_validates(self, wrapper):
        stats = wrapper.get_scan_statistics()
        from models.schemas import ScanStatisticsResponse
        response = ScanStatisticsResponse(**stats)
        assert response.total_scans == 0
