"""
Tests for M20: Enforce max_concurrent_scans limit.

Covers:
- _count_running_scans counts only PENDING and RUNNING scans
- start_scan raises MaxConcurrentScansError when limit reached
- Completed/failed/cancelled scans don't count against limit
- Limit is configurable via settings.max_concurrent_scans
- MaxConcurrentScansError contains running count and limit
- After a scan finishes, new scans can start
"""
import os
import sys
from unittest.mock import patch, AsyncMock, MagicMock

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from models.schemas import ScanStatus, ScanConfigRequest
from services.garak_wrapper import GarakWrapper, MaxConcurrentScansError


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture
def wrapper(tmp_path):
    """Create a GarakWrapper with mocked settings."""
    with patch("services.garak_wrapper.settings") as mock_settings:
        mock_settings.garak_service_url = "http://localhost:9090"
        mock_settings.garak_reports_path = tmp_path
        mock_settings.max_concurrent_scans = 3
        w = GarakWrapper()
    return w


def _add_scan(wrapper, scan_id: str, status: str):
    """Add a fake scan entry to active_scans."""
    wrapper.active_scans[scan_id] = {
        "scan_id": scan_id,
        "status": status,
        "progress": 0.0,
        "passed": 0,
        "failed": 0,
    }


# ---------------------------------------------------------------------------
# _count_running_scans
# ---------------------------------------------------------------------------

class TestCountRunningScans:

    def test_empty_returns_zero(self, wrapper):
        assert wrapper._count_running_scans() == 0

    def test_counts_running(self, wrapper):
        _add_scan(wrapper, "s1", ScanStatus.RUNNING)
        assert wrapper._count_running_scans() == 1

    def test_counts_pending(self, wrapper):
        _add_scan(wrapper, "s1", ScanStatus.PENDING)
        assert wrapper._count_running_scans() == 1

    def test_counts_both_running_and_pending(self, wrapper):
        _add_scan(wrapper, "s1", ScanStatus.RUNNING)
        _add_scan(wrapper, "s2", ScanStatus.PENDING)
        assert wrapper._count_running_scans() == 2

    def test_ignores_completed(self, wrapper):
        _add_scan(wrapper, "s1", ScanStatus.COMPLETED)
        assert wrapper._count_running_scans() == 0

    def test_ignores_failed(self, wrapper):
        _add_scan(wrapper, "s1", ScanStatus.FAILED)
        assert wrapper._count_running_scans() == 0

    def test_ignores_cancelled(self, wrapper):
        _add_scan(wrapper, "s1", ScanStatus.CANCELLED)
        assert wrapper._count_running_scans() == 0

    def test_mixed_statuses(self, wrapper):
        _add_scan(wrapper, "s1", ScanStatus.RUNNING)
        _add_scan(wrapper, "s2", ScanStatus.COMPLETED)
        _add_scan(wrapper, "s3", ScanStatus.PENDING)
        _add_scan(wrapper, "s4", ScanStatus.FAILED)
        _add_scan(wrapper, "s5", ScanStatus.CANCELLED)
        assert wrapper._count_running_scans() == 2


# ---------------------------------------------------------------------------
# MaxConcurrentScansError
# ---------------------------------------------------------------------------

class TestMaxConcurrentScansError:

    def test_error_has_running_and_limit(self):
        err = MaxConcurrentScansError(running=3, limit=5)
        assert err.running == 3
        assert err.limit == 5

    def test_error_message_contains_counts(self):
        err = MaxConcurrentScansError(running=3, limit=5)
        assert "3/5" in str(err)

    def test_is_exception(self):
        assert issubclass(MaxConcurrentScansError, Exception)


# ---------------------------------------------------------------------------
# start_scan enforcement
# ---------------------------------------------------------------------------

class TestStartScanEnforcement:

    @pytest.mark.anyio
    async def test_rejects_when_at_limit(self, wrapper):
        """Should raise when running count >= max_concurrent_scans."""
        with patch("services.garak_wrapper.settings") as mock_settings:
            mock_settings.max_concurrent_scans = 2
            mock_settings.garak_service_url = "http://localhost:9090"
            mock_settings.garak_reports_path = wrapper.garak_reports_dir

            _add_scan(wrapper, "s1", ScanStatus.RUNNING)
            _add_scan(wrapper, "s2", ScanStatus.RUNNING)

            config = ScanConfigRequest(
                target_type="ollama",
                target_name="llama3.2:3b",
            )

            with pytest.raises(MaxConcurrentScansError) as exc_info:
                await wrapper.start_scan(config)

            assert exc_info.value.running == 2
            assert exc_info.value.limit == 2

    @pytest.mark.anyio
    async def test_rejects_when_over_limit(self, wrapper):
        """Edge case: more running than limit (shouldn't happen but be safe)."""
        with patch("services.garak_wrapper.settings") as mock_settings:
            mock_settings.max_concurrent_scans = 1
            mock_settings.garak_service_url = "http://localhost:9090"
            mock_settings.garak_reports_path = wrapper.garak_reports_dir

            _add_scan(wrapper, "s1", ScanStatus.RUNNING)
            _add_scan(wrapper, "s2", ScanStatus.RUNNING)

            config = ScanConfigRequest(
                target_type="ollama",
                target_name="llama3.2:3b",
            )

            with pytest.raises(MaxConcurrentScansError):
                await wrapper.start_scan(config)

    @pytest.mark.anyio
    async def test_allows_when_under_limit(self, wrapper):
        """Should proceed when under the limit (mocking the HTTP call)."""
        with patch("services.garak_wrapper.settings") as mock_settings:
            mock_settings.max_concurrent_scans = 3
            mock_settings.garak_service_url = "http://localhost:9090"
            mock_settings.garak_reports_path = wrapper.garak_reports_dir

            _add_scan(wrapper, "s1", ScanStatus.RUNNING)
            # 1 running, limit 3 → should be allowed

            config = ScanConfigRequest(
                target_type="ollama",
                target_name="llama3.2:3b",
            )

            # Mock the HTTP call to garak service
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.raise_for_status = MagicMock()

            with patch("httpx.AsyncClient") as MockClient:
                mock_client_instance = AsyncMock()
                mock_client_instance.post = AsyncMock(return_value=mock_response)
                mock_client_instance.__aenter__ = AsyncMock(return_value=mock_client_instance)
                mock_client_instance.__aexit__ = AsyncMock(return_value=None)
                MockClient.return_value = mock_client_instance

                # Also mock the background task
                with patch("asyncio.create_task"):
                    scan_id = await wrapper.start_scan(config)

            assert scan_id is not None
            assert scan_id in wrapper.active_scans

            # Clean up
            del wrapper.active_scans[scan_id]

    @pytest.mark.anyio
    async def test_allows_when_completed_scans_dont_count(self, wrapper):
        """Completed scans shouldn't prevent new scans."""
        with patch("services.garak_wrapper.settings") as mock_settings:
            mock_settings.max_concurrent_scans = 1
            mock_settings.garak_service_url = "http://localhost:9090"
            mock_settings.garak_reports_path = wrapper.garak_reports_dir

            # One completed scan — should NOT count
            _add_scan(wrapper, "s1", ScanStatus.COMPLETED)

            config = ScanConfigRequest(
                target_type="ollama",
                target_name="llama3.2:3b",
            )

            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.raise_for_status = MagicMock()

            with patch("httpx.AsyncClient") as MockClient:
                mock_client_instance = AsyncMock()
                mock_client_instance.post = AsyncMock(return_value=mock_response)
                mock_client_instance.__aenter__ = AsyncMock(return_value=mock_client_instance)
                mock_client_instance.__aexit__ = AsyncMock(return_value=None)
                MockClient.return_value = mock_client_instance

                with patch("asyncio.create_task"):
                    scan_id = await wrapper.start_scan(config)

            assert scan_id is not None

            # Clean up
            del wrapper.active_scans[scan_id]

    @pytest.mark.anyio
    async def test_allows_after_scan_finishes(self, wrapper):
        """After a running scan completes, a new one should be allowed."""
        with patch("services.garak_wrapper.settings") as mock_settings:
            mock_settings.max_concurrent_scans = 1
            mock_settings.garak_service_url = "http://localhost:9090"
            mock_settings.garak_reports_path = wrapper.garak_reports_dir

            _add_scan(wrapper, "s1", ScanStatus.RUNNING)

            config = ScanConfigRequest(
                target_type="ollama",
                target_name="llama3.2:3b",
            )

            # Should fail while s1 is running
            with pytest.raises(MaxConcurrentScansError):
                await wrapper.start_scan(config)

            # Mark s1 as completed
            wrapper.active_scans["s1"]["status"] = ScanStatus.COMPLETED

            # Now should succeed
            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.raise_for_status = MagicMock()

            with patch("httpx.AsyncClient") as MockClient:
                mock_client_instance = AsyncMock()
                mock_client_instance.post = AsyncMock(return_value=mock_response)
                mock_client_instance.__aenter__ = AsyncMock(return_value=mock_client_instance)
                mock_client_instance.__aexit__ = AsyncMock(return_value=None)
                MockClient.return_value = mock_client_instance

                with patch("asyncio.create_task"):
                    scan_id = await wrapper.start_scan(config)

            assert scan_id is not None

            # Clean up
            del wrapper.active_scans[scan_id]


# ---------------------------------------------------------------------------
# Limit configuration
# ---------------------------------------------------------------------------

class TestLimitConfiguration:

    @pytest.mark.anyio
    async def test_limit_of_one(self, wrapper):
        """Limit of 1 means only one scan at a time."""
        with patch("services.garak_wrapper.settings") as mock_settings:
            mock_settings.max_concurrent_scans = 1
            mock_settings.garak_service_url = "http://localhost:9090"
            mock_settings.garak_reports_path = wrapper.garak_reports_dir

            _add_scan(wrapper, "s1", ScanStatus.PENDING)

            config = ScanConfigRequest(
                target_type="ollama",
                target_name="llama3.2:3b",
            )

            with pytest.raises(MaxConcurrentScansError) as exc_info:
                await wrapper.start_scan(config)
            assert exc_info.value.limit == 1

    @pytest.mark.anyio
    async def test_limit_of_ten(self, wrapper):
        """Higher limit allows more concurrent scans."""
        with patch("services.garak_wrapper.settings") as mock_settings:
            mock_settings.max_concurrent_scans = 10
            mock_settings.garak_service_url = "http://localhost:9090"
            mock_settings.garak_reports_path = wrapper.garak_reports_dir

            for i in range(9):
                _add_scan(wrapper, f"s{i}", ScanStatus.RUNNING)

            # 9 running, limit 10 → should be allowed
            config = ScanConfigRequest(
                target_type="ollama",
                target_name="llama3.2:3b",
            )

            mock_response = MagicMock()
            mock_response.status_code = 200
            mock_response.raise_for_status = MagicMock()

            with patch("httpx.AsyncClient") as MockClient:
                mock_client_instance = AsyncMock()
                mock_client_instance.post = AsyncMock(return_value=mock_response)
                mock_client_instance.__aenter__ = AsyncMock(return_value=mock_client_instance)
                mock_client_instance.__aexit__ = AsyncMock(return_value=None)
                MockClient.return_value = mock_client_instance

                with patch("asyncio.create_task"):
                    scan_id = await wrapper.start_scan(config)

            assert scan_id is not None

            # Clean up
            del wrapper.active_scans[scan_id]
