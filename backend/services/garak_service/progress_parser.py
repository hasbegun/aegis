"""
Progress parser for garak CLI stdout output.
Extracts structured progress events from garak's text output.
"""
import re
import logging
from typing import Optional, Dict, Any

logger = logging.getLogger(__name__)


class ProgressParser:
    """Parses garak stdout lines into structured progress events."""

    def __init__(self, scan_id: str):
        self.scan_id = scan_id
        self.completed_probes = 0
        self.total_probes = 0
        self.total_passed = 0
        self.total_failed = 0
        self.last_completed_probe: Optional[str] = None

    def parse_line(self, line: str) -> Optional[Dict[str, Any]]:
        """
        Parse a single output line from garak stdout.

        Returns a dict with 'event_type' key and event-specific data,
        or None if the line doesn't match any known pattern.
        """
        if not line or not line.strip():
            return None

        line = line.strip()

        # Check for error patterns first
        event = self._check_errors(line)
        if event:
            return event

        # Pattern 1: Full progress with iterations
        # "probes.web_injection.MarkdownImageExfil: 42%|...| 5/12 [00:55<01:13, 10.55s/it]"
        match = re.search(
            r'(probes\.\S+):\s+(\d+)%\|[^|]*\|\s*(\d+)/(\d+)\s+\[([^<]+)<([^,]+),',
            line
        )
        if match:
            return {
                "event_type": "progress",
                "probe": match.group(1),
                "percent": int(match.group(2)),
                "current": int(match.group(3)),
                "total": int(match.group(4)),
                "elapsed": match.group(5).strip(),
                "remaining": match.group(6).strip(),
            }

        # Pattern 1b: Simple progress - "probes.ansiescape.AnsiEscaped: 6%"
        match = re.search(r'(probes\.\S+):\s+(\d+)%', line)
        if match:
            return {
                "event_type": "progress",
                "probe": match.group(1),
                "percent": int(match.group(2)),
            }

        # Pattern 2: Probe count - "1 3/51 [00:52:13:08, 16.44s/it]"
        if 'probes.' not in line and '%' not in line:
            match = re.search(r'(\d+)\s+(\d+)/(\d+)\s+\[', line)
            if match:
                self.completed_probes = int(match.group(2))
                self.total_probes = int(match.group(3))
                return {
                    "event_type": "probe_count",
                    "completed": self.completed_probes,
                    "total": self.total_probes,
                }

        # Pattern 3: Probe completion with result
        # "web_injection.MarkdownImageExfil  web_injection.MarkdownExfilContent: PASS  ok on   59/  60"
        match = re.search(r'([\w\.]+)\s+([\w\.]+):\s+(PASS|FAIL)', line)
        if match:
            probe_module = match.group(1)
            if self.last_completed_probe != probe_module:
                self.completed_probes += 1
                self.last_completed_probe = probe_module

        # Pattern 3b: Extract probe name from line
        if 'probes.' in line:
            parts = line.split()
            for part in parts:
                if part.startswith('probes.'):
                    probe_name = part.rstrip(':,;')
                    return {
                        "event_type": "current_probe",
                        "probe": probe_name,
                    }

        # Pattern 4: Test results - "PASS ok on 20/20" or "FAIL ok on 59/60"
        line_upper = line.upper()
        if ('PASS' in line_upper or 'FAIL' in line_upper) and 'ok on' in line.lower():
            match = re.search(r'(\d+)\s*/\s*(\d+)', line)
            if match:
                tests_passed = int(match.group(1))
                total_tests = int(match.group(2))
                tests_failed = total_tests - tests_passed
                self.total_passed += tests_passed
                self.total_failed += tests_failed
                return {
                    "event_type": "result",
                    "tests_passed": tests_passed,
                    "tests_failed": tests_failed,
                    "total_tests": total_tests,
                    "total_passed": self.total_passed,
                    "total_failed": self.total_failed,
                }

        # Pattern 5: HTML report path
        match = re.search(r'report html summary being written to\s+(.+\.html)', line)
        if match:
            return {
                "event_type": "report",
                "report_type": "html",
                "path": match.group(1).strip(),
            }

        # Pattern 6: JSONL report path
        match = re.search(r'report closed.*?([/\w\-\.]+\.jsonl)', line)
        if match:
            return {
                "event_type": "report",
                "report_type": "jsonl",
                "path": match.group(1).strip(),
            }

        # Pattern 7: passed/failed counts
        if 'passed' in line.lower() or 'failed' in line.lower():
            passed_match = re.search(r'passed[:\s]+(\d+)', line, re.IGNORECASE)
            failed_match = re.search(r'failed[:\s]+(\d+)', line, re.IGNORECASE)
            if passed_match or failed_match:
                if passed_match:
                    self.total_passed = int(passed_match.group(1))
                if failed_match:
                    self.total_failed = int(failed_match.group(1))
                return {
                    "event_type": "result",
                    "total_passed": self.total_passed,
                    "total_failed": self.total_failed,
                }

        return None

    def _check_errors(self, line: str) -> Optional[Dict[str, Any]]:
        """Check for fatal error patterns in output line.

        Only match clear garak error indicators, not normal log output
        or test result lines (which contain PASS/FAIL as outcomes).
        Matches the actual exception line (e.g. "ConnectionError: ..."),
        not the "Traceback" header which carries no useful info.
        """
        if 'Unknown probes' in line:
            match = re.search(r'Unknown probes.*?:\s*(.+)', line)
            msg = f"Unknown probes: {match.group(1).strip()}" if match else line
            return {"event_type": "error", "message": msg}

        if '❌' in line:
            return {"event_type": "error", "message": line.strip()}

        # Match Python exception types at the end of tracebacks
        if re.search(
            r'(?:^|\s)(?:ModuleNotFoundError|ImportError|RuntimeError|'
            r'FileNotFoundError|ConnectionError|TimeoutError|'
            r'ValueError|KeyError|TypeError|AttributeError|'
            r'PermissionError|OSError):', line
        ):
            return {"event_type": "error", "message": line.strip()}

        return None
