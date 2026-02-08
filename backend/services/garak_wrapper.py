"""
Garak service client.
Communicates with the garak container over HTTP/SSE instead of
spawning local subprocesses.
"""
import asyncio
import json
import logging
import uuid
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any

import httpx

from models.schemas import ScanStatus, ScanConfigRequest
from services.workflow_analyzer import workflow_analyzer
from config import settings

logger = logging.getLogger(__name__)


class GarakWrapper:
    """HTTP client for the garak container service."""

    def __init__(self, garak_service_url: Optional[str] = None):
        self.garak_service_url = garak_service_url or settings.garak_service_url
        self.active_scans: Dict[str, Dict[str, Any]] = {}
        self.garak_reports_dir = settings.garak_reports_path
        logger.info(f"Garak service URL: {self.garak_service_url}")
        logger.info(f"Garak reports directory: {self.garak_reports_dir}")

    # ------------------------------------------------------------------
    # Health / Version / Plugins  (delegate to garak service)
    # ------------------------------------------------------------------

    def check_garak_installed(self) -> bool:
        """Check if garak service is available and garak is installed."""
        try:
            with httpx.Client(base_url=self.garak_service_url, timeout=5.0) as client:
                response = client.get("/health")
                if response.status_code == 200:
                    return response.json().get("garak_installed", False)
        except Exception as e:
            logger.error(f"Error checking garak service health: {e}")
        return False

    def get_garak_version(self) -> Optional[str]:
        """Get garak version from the service."""
        try:
            with httpx.Client(base_url=self.garak_service_url, timeout=5.0) as client:
                response = client.get("/version")
                if response.status_code == 200:
                    return response.json().get("version")
        except Exception as e:
            logger.error(f"Error getting garak version: {e}")
        return None

    def list_plugins(self, plugin_type: str) -> List[str]:
        """List plugins via garak service."""
        try:
            with httpx.Client(base_url=self.garak_service_url, timeout=60.0) as client:
                response = client.get(f"/plugins/{plugin_type}")
                if response.status_code == 200:
                    plugins = response.json().get("plugins", [])
                    logger.info(f"Found {len(plugins)} {plugin_type}")
                    return plugins
        except Exception as e:
            logger.error(f"Error listing {plugin_type}: {e}")
        return []

    # ------------------------------------------------------------------
    # Scan lifecycle
    # ------------------------------------------------------------------

    async def start_scan(self, config: ScanConfigRequest) -> str:
        """Start a scan via the garak service."""
        scan_id = str(uuid.uuid4())

        # Send scan config to garak service
        async with httpx.AsyncClient(
            base_url=self.garak_service_url, timeout=30.0
        ) as client:
            response = await client.post(
                "/scans",
                json={
                    "scan_id": scan_id,
                    "config": config.model_dump(),
                },
            )
            response.raise_for_status()

        # Initialize local tracking (same shape as before for WebSocket compat)
        total_probes = len(config.probes) if config.probes else 0
        self.active_scans[scan_id] = {
            "scan_id": scan_id,
            "status": ScanStatus.PENDING,
            "config": config,
            "progress": 0.0,
            "current_probe": None,
            "completed_probes": 0,
            "total_probes": total_probes,
            "current_iteration": 0,
            "total_iterations": 0,
            "passed": 0,
            "failed": 0,
            "elapsed_time": None,
            "estimated_remaining": None,
            "html_report_path": None,
            "jsonl_report_path": None,
            "created_at": datetime.now().isoformat(),
            "output_lines": [],
            "error_message": None,
        }

        # Start background task to consume SSE progress stream
        asyncio.create_task(self._consume_progress_stream(scan_id))

        return scan_id

    async def _consume_progress_stream(self, scan_id: str):
        """Connect to garak service SSE and update local scan state."""
        scan_info = self.active_scans.get(scan_id)
        if not scan_info:
            return

        # Small delay to let the garak service register the scan
        await asyncio.sleep(0.5)

        max_retries = 3
        for attempt in range(max_retries):
            try:
                async with httpx.AsyncClient(
                    base_url=self.garak_service_url,
                    timeout=httpx.Timeout(connect=10.0, read=None, write=10.0, pool=10.0),
                ) as client:
                    async with client.stream(
                        "GET", f"/scans/{scan_id}/progress"
                    ) as response:
                        if response.status_code != 200:
                            body = await response.aread()
                            logger.error(
                                f"SSE endpoint returned {response.status_code} for {scan_id}: {body.decode()}"
                            )
                            if attempt < max_retries - 1:
                                await asyncio.sleep(2 * (attempt + 1))
                                continue
                            scan_info["status"] = ScanStatus.FAILED
                            scan_info["error_message"] = (
                                f"Garak service error: {response.status_code}"
                            )
                            scan_info["completed_at"] = datetime.now().isoformat()
                            return

                        async for line in response.aiter_lines():
                            if not line.startswith("data: "):
                                continue
                            try:
                                data = json.loads(line[6:])
                            except json.JSONDecodeError:
                                continue

                            self._update_scan_from_event(scan_id, data)

                            # Forward raw output to workflow analyzer
                            raw_line = data.get("raw_line")
                            if raw_line:
                                workflow_analyzer.process_garak_output(scan_id, raw_line)

                # Stream ended normally -- if scan isn't in a terminal state, mark completed
                if scan_info.get("status") in [ScanStatus.RUNNING, ScanStatus.PENDING]:
                    scan_info["status"] = ScanStatus.COMPLETED
                    scan_info["progress"] = 100.0
                    scan_info["completed_at"] = datetime.now().isoformat()
                return

            except Exception as e:
                logger.error(f"Error consuming progress stream for {scan_id} (attempt {attempt + 1}): {e}")
                if attempt < max_retries - 1:
                    await asyncio.sleep(2 * (attempt + 1))
                    continue
                if scan_info.get("status") in [ScanStatus.RUNNING, ScanStatus.PENDING]:
                    scan_info["status"] = ScanStatus.FAILED
                    scan_info["error_message"] = (
                        f"Lost connection to garak service: {e}"
                    )
                    scan_info["completed_at"] = datetime.now().isoformat()

    def _update_scan_from_event(self, scan_id: str, event: dict):
        """Update local scan state from an SSE event."""
        scan_info = self.active_scans.get(scan_id)
        if not scan_info:
            return

        etype = event.get("event_type")

        if etype == "status":
            status_str = event.get("status", "")
            scan_info["status"] = self._map_status(status_str)

        elif etype == "progress":
            scan_info["current_probe"] = event.get("probe")
            scan_info["progress"] = float(event.get("percent", scan_info["progress"]))
            scan_info["current_iteration"] = event.get("current", 0)
            scan_info["total_iterations"] = event.get("total", 0)
            scan_info["elapsed_time"] = event.get("elapsed")
            scan_info["estimated_remaining"] = event.get("remaining")
            scan_info["status"] = ScanStatus.RUNNING

        elif etype == "probe_count":
            scan_info["completed_probes"] = event.get("completed", 0)
            scan_info["total_probes"] = event.get("total", 0)

        elif etype == "current_probe":
            scan_info["current_probe"] = event.get("probe")

        elif etype == "result":
            scan_info["passed"] = event.get("total_passed", scan_info.get("passed", 0))
            scan_info["failed"] = event.get("total_failed", scan_info.get("failed", 0))

        elif etype == "report":
            rtype = event.get("report_type")
            if rtype == "html":
                scan_info["html_report_path"] = event.get("path")
            elif rtype == "jsonl":
                scan_info["jsonl_report_path"] = event.get("path")

        elif etype == "complete":
            scan_info["status"] = ScanStatus.COMPLETED
            scan_info["progress"] = 100.0
            scan_info["completed_at"] = datetime.now().isoformat()
            scan_info["passed"] = event.get("passed", scan_info.get("passed", 0))
            scan_info["failed"] = event.get("failed", scan_info.get("failed", 0))

        elif etype == "error":
            scan_info["status"] = ScanStatus.FAILED
            scan_info["error_message"] = event.get("message")
            scan_info["completed_at"] = datetime.now().isoformat()

        elif etype == "output":
            scan_info.setdefault("output_lines", []).append(
                event.get("line", "")
            )

    @staticmethod
    def _map_status(status_str: str) -> ScanStatus:
        mapping = {
            "pending": ScanStatus.PENDING,
            "running": ScanStatus.RUNNING,
            "completed": ScanStatus.COMPLETED,
            "failed": ScanStatus.FAILED,
            "cancelled": ScanStatus.CANCELLED,
        }
        return mapping.get(status_str, ScanStatus.PENDING)

    async def cancel_scan(self, scan_id: str) -> bool:
        """Cancel a scan via the garak service."""
        scan_info = self.active_scans.get(scan_id)
        if not scan_info:
            logger.warning(f"Cannot cancel scan {scan_id}: not found")
            return False

        if scan_info["status"] not in [ScanStatus.RUNNING, ScanStatus.PENDING]:
            logger.warning(f"Cannot cancel scan {scan_id}: status is {scan_info['status']}")
            return False

        try:
            async with httpx.AsyncClient(
                base_url=self.garak_service_url, timeout=10.0
            ) as client:
                response = await client.delete(f"/scans/{scan_id}")
                if response.status_code == 200:
                    scan_info["status"] = ScanStatus.CANCELLED
                    scan_info["completed_at"] = datetime.now().isoformat()
                    logger.info(f"Scan {scan_id} cancelled")
                    return True
                else:
                    logger.error(
                        f"Failed to cancel scan {scan_id}: {response.status_code}"
                    )
        except Exception as e:
            logger.error(f"Error cancelling scan {scan_id}: {e}")
        return False

    # ------------------------------------------------------------------
    # Report reading (unchanged -- reads from shared volume)
    # ------------------------------------------------------------------

    def get_scan_status(self, scan_id: str) -> Optional[Dict[str, Any]]:
        """Get current status of a scan (active or historical)."""
        # Check active scans first
        scan_info = self.active_scans.get(scan_id)
        if scan_info:
            return {k: v for k, v in scan_info.items() if k != "process"}

        # Check historical scans on disk
        if self.garak_reports_dir.exists():
            report_file = self.garak_reports_dir / f"garak.{scan_id}.report.jsonl"
            if report_file.exists():
                return self._parse_report_file(report_file, scan_id)

        return None

    def delete_scan(self, scan_id: str) -> bool:
        """Delete a scan and all its associated reports."""
        # Remove from active scans
        if scan_id in self.active_scans:
            scan_info = self.active_scans[scan_id]
            if scan_info.get("status") in [ScanStatus.RUNNING, ScanStatus.PENDING]:
                try:
                    asyncio.create_task(self.cancel_scan(scan_id))
                except Exception as e:
                    logger.warning(f"Failed to cancel running scan {scan_id}: {e}")
            del self.active_scans[scan_id]
            logger.info(f"Removed scan {scan_id} from active scans")

        # Delete report files
        if self.garak_reports_dir.exists():
            deleted_files = []
            try:
                for file_pattern in [
                    f"garak.{scan_id}.report.jsonl",
                    f"garak.{scan_id}.report.html",
                    f"garak.{scan_id}.*",
                ]:
                    for file_path in self.garak_reports_dir.glob(file_pattern):
                        try:
                            file_path.unlink()
                            deleted_files.append(str(file_path))
                        except Exception as e:
                            logger.error(f"Failed to delete file {file_path}: {e}")
                if deleted_files:
                    logger.info(f"Deleted {len(deleted_files)} file(s) for scan {scan_id}")
            except Exception as e:
                logger.error(f"Error deleting report files for scan {scan_id}: {e}")

        return True

    def get_all_scans(self) -> List[Dict[str, Any]]:
        """Get information about all scans (active and historical)."""
        all_scans = []

        # Active scans
        for scan_info in self.active_scans.values():
            scan_copy = {k: v for k, v in scan_info.items() if k != "process"}
            all_scans.append(scan_copy)

        # Historical scans from reports directory
        if not self.garak_reports_dir.exists():
            logger.warning(f"Reports directory not found: {self.garak_reports_dir}")
            return sorted(all_scans, key=lambda x: x.get("started_at", ""), reverse=True)

        try:
            report_files = list(self.garak_reports_dir.glob("garak.*.report.jsonl"))
            for report_file in report_files:
                try:
                    scan_id = report_file.stem.replace("garak.", "").replace(".report", "")
                    if scan_id in self.active_scans:
                        continue
                    scan_info = self._parse_report_file(report_file, scan_id)
                    if scan_info:
                        all_scans.append(scan_info)
                except Exception as e:
                    logger.error(f"Error parsing report file {report_file}: {e}")
        except Exception as e:
            logger.error(f"Error reading reports directory: {e}")

        return sorted(all_scans, key=lambda x: x.get("started_at", ""), reverse=True)

    def _parse_report_file(self, report_file: Path, scan_id: str) -> Optional[Dict[str, Any]]:
        """Parse a garak report.jsonl file to extract scan information."""
        try:
            with open(report_file, "r", encoding="utf-8") as f:
                lines = f.readlines()

            if not lines:
                return None

            first_entry = json.loads(lines[0])

            scan_info = {
                "scan_id": scan_id,
                "status": "completed",
                "target_type": first_entry.get("plugins.target_type", "unknown"),
                "target_name": first_entry.get("plugins.target_name", "unknown"),
                "started_at": first_entry.get("transient.starttime_iso", ""),
                "completed_at": first_entry.get("transient.endtime_iso", ""),
                "passed": 0,
                "failed": 0,
                "total_tests": 0,
                "progress": 100.0,
            }

            html_report_path = report_file.parent / f"garak.{scan_id}.report.html"
            if html_report_path.exists():
                scan_info["html_report_path"] = str(html_report_path)

            scan_info["jsonl_report_path"] = str(report_file)

            for line in lines:
                try:
                    entry = json.loads(line)
                    if "status" in entry and entry.get("status") in [1, 2]:
                        scan_info["total_tests"] += 1
                        if entry["status"] == 2:
                            scan_info["passed"] += 1
                        elif entry["status"] == 1:
                            scan_info["failed"] += 1
                except json.JSONDecodeError:
                    continue

            if not scan_info["started_at"]:
                file_mtime = datetime.fromtimestamp(report_file.stat().st_mtime)
                scan_info["started_at"] = file_mtime.isoformat()

            return scan_info

        except Exception as e:
            logger.error(f"Error parsing report file {report_file}: {e}")
            return None

    def get_scan_results(self, scan_id: str) -> Optional[Dict[str, Any]]:
        """Get detailed scan results including probe-level breakdown."""
        scan_info = self.get_scan_status(scan_id)
        if not scan_info:
            return None

        config_data = None
        if "config" in scan_info:
            config = scan_info["config"]
            config_data = config.model_dump() if hasattr(config, "model_dump") else config

        results = {
            "scan_id": scan_id,
            "status": scan_info["status"],
            "config": config_data,
            "created_at": scan_info.get("created_at"),
            "started_at": scan_info.get("started_at"),
            "completed_at": scan_info.get("completed_at"),
            "duration": self._calculate_duration(scan_info),
            "results": {
                "passed": scan_info.get("passed", 0),
                "failed": scan_info.get("failed", 0),
                "total_probes": scan_info.get("total_probes", 0),
                "completed_probes": scan_info.get("completed_probes", 0),
                "current_probe": scan_info.get("current_probe"),
                "progress": scan_info.get("progress", 0.0),
            },
            "summary": {
                "total_tests": scan_info.get("passed", 0) + scan_info.get("failed", 0),
                "pass_rate": self._calculate_pass_rate(scan_info),
                "status": scan_info["status"],
                "error_message": scan_info.get("error_message"),
            },
            "html_report_path": scan_info.get("html_report_path"),
            "jsonl_report_path": scan_info.get("jsonl_report_path"),
            "output_lines": scan_info.get("output_lines", []),
        }

        return results

    def _calculate_duration(self, scan_info: Dict[str, Any]) -> Optional[float]:
        if not scan_info.get("started_at") or not scan_info.get("completed_at"):
            return None
        try:
            start = datetime.fromisoformat(scan_info["started_at"])
            end = datetime.fromisoformat(scan_info["completed_at"])
            return (end - start).total_seconds()
        except Exception:
            return None

    def _calculate_pass_rate(self, scan_info: Dict[str, Any]) -> float:
        passed = scan_info.get("passed", 0)
        failed = scan_info.get("failed", 0)
        total = passed + failed
        if total == 0:
            return 0.0
        return (passed / total) * 100.0


# Global instance
try:
    garak_wrapper = GarakWrapper()
except Exception:
    garak_wrapper = GarakWrapper()
