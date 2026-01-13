"""
Garak CLI wrapper service
Handles execution of garak commands and process management
"""
import asyncio
import subprocess
import json
import logging
import uuid
import shutil
from datetime import datetime
from pathlib import Path
from typing import Dict, List, Optional, Any
from models.schemas import ScanStatus, ScanConfigRequest
from services.workflow_analyzer import workflow_analyzer
from config import settings

logger = logging.getLogger(__name__)


class GarakWrapper:
    """Wrapper for garak CLI operations"""

    def __init__(self, garak_path: Optional[str] = None):
        self.active_scans: Dict[str, Dict[str, Any]] = {}
        self.garak_path = garak_path or self._find_garak()
        self.garak_reports_dir = settings.garak_reports_path
        logger.info(f"Garak path: {self.garak_path}")
        logger.info(f"Garak reports directory: {self.garak_reports_dir}")

    def _find_garak(self) -> Optional[str]:
        """Find garak executable in PATH or as module"""
        # First try as executable
        garak_path = shutil.which("garak")
        if garak_path:
            logger.info(f"Found garak at: {garak_path}")
            return garak_path

        # Try common locations
        common_paths = [
            "/usr/local/bin/garak",
            str(Path.home() / ".local" / "bin" / "garak"),
        ]

        for path in common_paths:
            if Path(path).exists():
                logger.info(f"Found garak at: {path}")
                return path

        # Try running as Python module
        try:
            result = subprocess.run(
                ["python", "-m", "garak", "--version"],
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                logger.info("Found garak as Python module (python -m garak)")
                return "python -m garak"  # Special marker for module execution
        except Exception:
            pass

        logger.warning("garak not found in PATH or as module")
        return None

    def check_garak_installed(self) -> bool:
        """Check if garak is installed and accessible"""
        if not self.garak_path:
            return False

        try:
            # Build command based on whether it's module or executable
            if self.garak_path == "python -m garak":
                cmd = ["python", "-m", "garak", "--version"]
            else:
                cmd = [self.garak_path, "--version"]

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=5
            )
            return result.returncode == 0
        except Exception as e:
            logger.error(f"Error checking garak installation: {e}")
            return False

    def get_garak_version(self) -> Optional[str]:
        """Get garak version"""
        if not self.garak_path:
            return None

        try:
            # Build command based on whether it's module or executable
            if self.garak_path == "python -m garak":
                cmd = ["python", "-m", "garak", "--version"]
            else:
                cmd = [self.garak_path, "--version"]

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=5
            )
            if result.returncode == 0:
                # Parse version from output
                return result.stdout.strip()
            return None
        except Exception as e:
            logger.error(f"Error getting garak version: {e}")
            return None

    def list_plugins(self, plugin_type: str) -> List[str]:
        """
        List available plugins of a specific type

        Args:
            plugin_type: One of 'probes', 'detectors', 'generators', 'buffs'

        Returns:
            List of plugin names
        """
        if not self.garak_path:
            return []

        command_map = {
            'probes': '--list_probes',
            'detectors': '--list_detectors',
            'generators': '--list_generators',
            'buffs': '--list_buffs'
        }

        cmd_arg = command_map.get(plugin_type)
        if not cmd_arg:
            logger.error(f"Invalid plugin type: {plugin_type}")
            return []

        try:
            # Build command based on whether it's module or executable
            if self.garak_path == "python -m garak":
                cmd = ["python", "-m", "garak", cmd_arg]
            else:
                cmd = [self.garak_path, cmd_arg]

            result = subprocess.run(
                cmd,
                capture_output=True,
                text=True,
                timeout=30
            )

            if result.returncode == 0:
                # Parse output to extract plugin names
                plugins = self._parse_plugin_list(result.stdout, plugin_type)
                logger.info(f"Found {len(plugins)} {plugin_type}")
                return plugins
            else:
                logger.error(f"Error listing {plugin_type}: {result.stderr}")
                return []
        except Exception as e:
            logger.error(f"Exception listing {plugin_type}: {e}")
            return []

    def _parse_plugin_list(self, output: str, plugin_type: str) -> List[str]:
        """Parse plugin list output from garak"""
        import re

        plugins = []
        for line in output.split('\n'):
            line = line.strip()
            if not line or line.startswith('#') or line.startswith('garak'):
                continue

            # Remove ANSI escape codes
            # Matches \x1b[Xm or [Xm patterns where X can be numbers and semicolons
            line_clean = re.sub(r'\x1b\[[0-9;]*m', '', line)
            line_clean = re.sub(r'\[[0-9;]*m', '', line_clean)
            line_clean = line_clean.strip()

            if not line_clean:
                continue

            # Parse format: "probes: ansiescape 🌟" or "probes: ansiescape.AnsiEscaped"
            # Split by spaces and filter out emojis and extra symbols
            parts = line_clean.split()

            # Skip the "probes:", "detectors:", etc. prefix
            if len(parts) >= 2 and parts[0].endswith(':'):
                # Take the actual plugin name (second part)
                plugin_name = parts[1]
                # Remove emoji and other decorators (🌟, 💤, etc.)
                plugin_name = re.sub(r'[^\w\.\-]', '', plugin_name)

                if not plugin_name:
                    continue

                # Filter out category-only probes (those with 🌟 but no dot)
                # These are module names, not actual runnable probes
                # Only include if: has a dot (specific implementation) OR if it's not marked with 🌟
                has_star = '🌟' in line
                has_dot = '.' in plugin_name

                # Include if it has a specific class name (has dot) or if it's not a category marker
                # Categories are marked with 🌟 and have no dot
                if has_dot or not has_star:
                    plugins.append(plugin_name)

            elif len(parts) >= 1:
                # Fallback: just take first word if no colon prefix
                plugin_name = parts[0]
                plugin_name = re.sub(r'[^\w\.\-]', '', plugin_name)
                if plugin_name and '.' in plugin_name:  # Only specific implementations
                    plugins.append(plugin_name)

        return plugins

    def _build_command(self, config: ScanConfigRequest) -> List[str]:
        """Build garak command from configuration"""
        if not self.garak_path:
            raise RuntimeError("garak not found")

        # Handle module execution (python -m garak)
        if self.garak_path == "python -m garak":
            cmd = ["python", "-m", "garak"]
        else:
            cmd = [self.garak_path]

        # Target configuration
        cmd.extend(['--target_type', config.target_type])
        cmd.extend(['--target_name', config.target_name])

        # Probes - strip 'probes.' prefix if present
        if config.probes:
            probes_cleaned = [p.replace('probes.', '', 1) if p.startswith('probes.') else p for p in config.probes]
            probes_str = ','.join(probes_cleaned)
            cmd.extend(['--probes', probes_str])

        # Probe tags filter (e.g., 'owasp:llm01')
        if config.probe_tags:
            cmd.extend(['--probe_tags', config.probe_tags])

        # System prompt override
        if config.system_prompt:
            cmd.extend(['--system_prompt', config.system_prompt])

        # Extended detectors (run all detectors instead of primary only)
        if config.extended_detectors:
            cmd.append('--extended_detectors')

        # Deprefix (remove prompt from generator output)
        if config.deprefix:
            cmd.append('--deprefix')

        # Verbose mode (add -v flags based on level)
        if config.verbose > 0:
            cmd.append('-' + 'v' * config.verbose)

        # Skip unknown plugins
        if config.skip_unknown:
            cmd.append('--skip_unknown')

        # Buffs include original prompt
        if config.buffs_include_original_prompt:
            cmd.append('--buffs_include_original_prompt')

        # Detectors - strip 'detectors.' prefix if present
        if config.detectors:
            detectors_cleaned = [d.replace('detectors.', '', 1) if d.startswith('detectors.') else d for d in config.detectors]
            detectors_str = ','.join(detectors_cleaned)
            cmd.extend(['--detectors', detectors_str])

        # Buffs - strip 'buffs.' prefix if present
        if config.buffs:
            buffs_cleaned = [b.replace('buffs.', '', 1) if b.startswith('buffs.') else b for b in config.buffs]
            buffs_str = ','.join(buffs_cleaned)
            cmd.extend(['--buffs', buffs_str])

        # Run parameters
        cmd.extend(['--generations', str(config.generations)])
        cmd.extend(['--eval_threshold', str(config.eval_threshold)])

        if config.seed is not None:
            cmd.extend(['--seed', str(config.seed)])

        # System parameters
        if config.parallel_requests:
            cmd.extend(['--parallel_requests', str(config.parallel_requests)])

        if config.parallel_attempts:
            cmd.extend(['--parallel_attempts', str(config.parallel_attempts)])

        # Generator options (pass as JSON)
        # Structure must match garak's expected format: {"<generator_type>": {"key": "value"}}
        # e.g., {"ollama": {"host": "http://localhost:11434"}}

        # Extract base generator type (e.g., "ollama" from "ollama.OllamaGeneratorChat")
        generator_type = config.target_type.split('.')[0].lower()

        # Start with user-provided options (which should already be in nested format)
        # or create the nested structure
        generator_options = {}
        if config.generator_options:
            # If user provided flat options, nest them under the generator type
            user_opts = dict(config.generator_options)
            # Check if already nested (has generator type as key)
            if generator_type in user_opts:
                generator_options = user_opts
            else:
                generator_options = {generator_type: user_opts}

        # Auto-inject OLLAMA_HOST for Ollama generators if set in environment
        import os
        ollama_host = os.environ.get('OLLAMA_HOST')
        logger.info(f"Target type: {config.target_type}, Generator type: {generator_type}, OLLAMA_HOST env: {ollama_host}")

        # Check if this is an Ollama generator
        is_ollama = 'ollama' in generator_type

        if ollama_host and is_ollama:
            # Ensure the ollama key exists in generator_options
            if 'ollama' not in generator_options:
                generator_options['ollama'] = {}
            # Only set host if not already specified by user
            if 'host' not in generator_options['ollama']:
                generator_options['ollama']['host'] = ollama_host
                logger.info(f"Injecting Ollama host for generator: {ollama_host}")

        if generator_options:
            opts_json = json.dumps(generator_options)
            cmd.extend(['--generator_options', opts_json])
            logger.info(f"Generator options: {opts_json}")

        # Probe options
        if config.probe_options:
            opts_json = json.dumps(config.probe_options)
            cmd.extend(['--probe_options', opts_json])

        # Report prefix
        if config.report_prefix:
            cmd.extend(['--report_prefix', config.report_prefix])

        logger.info(f"Built command: {' '.join(cmd)}")
        return cmd

    async def start_scan(self, config: ScanConfigRequest) -> str:
        """
        Start a new garak scan

        Args:
            config: Scan configuration

        Returns:
            scan_id: Unique identifier for the scan
        """
        scan_id = str(uuid.uuid4())

        # Build command
        try:
            cmd = self._build_command(config)
        except Exception as e:
            logger.error(f"Error building command: {e}")
            raise

        # Calculate total probes from config
        total_probes = len(config.probes) if config.probes else 0

        # Initialize scan tracking
        self.active_scans[scan_id] = {
            'scan_id': scan_id,
            'status': ScanStatus.PENDING,
            'config': config,
            'progress': 0.0,
            'current_probe': None,
            'completed_probes': 0,
            'total_probes': total_probes,
            'current_iteration': 0,
            'total_iterations': 0,
            'passed': 0,
            'failed': 0,
            'elapsed_time': None,
            'estimated_remaining': None,
            'html_report_path': None,
            'jsonl_report_path': None,
            'created_at': datetime.now().isoformat(),
            'process': None,
            'output_lines': [],
            'error_message': None
        }

        # Start scan in background
        asyncio.create_task(self._run_scan(scan_id, cmd))

        return scan_id

    async def _run_scan(self, scan_id: str, cmd: List[str]):
        """Execute garak scan as subprocess"""
        scan_info = self.active_scans[scan_id]

        try:
            # Update status to running
            scan_info['status'] = ScanStatus.RUNNING
            scan_info['started_at'] = datetime.now().isoformat()

            # Execute command
            # Use STDOUT for both streams since garak outputs progress to stderr
            # Create in new process group so we can kill all children when canceled
            import os

            # Pass current environment to subprocess (includes OLLAMA_HOST, API keys, etc.)
            env = os.environ.copy()

            # Log key environment variables for debugging
            ollama_host = env.get('OLLAMA_HOST', 'not set')
            logger.info(f"[{scan_id}] Starting scan with OLLAMA_HOST={ollama_host}")

            process = await asyncio.create_subprocess_exec(
                *cmd,
                stdout=asyncio.subprocess.PIPE,
                stderr=asyncio.subprocess.STDOUT,  # Redirect stderr to stdout
                env=env,  # Pass environment variables to garak subprocess
                preexec_fn=os.setpgrp if hasattr(os, 'setpgrp') else None  # Create new process group (Unix/macOS)
            )

            scan_info['process'] = process

            # Read output (stderr is redirected to stdout)
            async def read_stream(stream):
                while True:
                    line = await stream.readline()
                    if not line:
                        break

                    decoded = line.decode('utf-8', errors='replace')

                    # Handle carriage returns (progress bars overwriting lines)
                    # Split by \r and process each part as a separate line
                    if '\r' in decoded:
                        parts = decoded.split('\r')
                        # Process all parts (each represents a line update)
                        for part in parts:
                            part = part.strip()
                            if part:
                                # Only log non-progress lines to reduce spam
                                if not ('|' in part and '%' in part):
                                    logger.info(f"[{scan_id}] {part}")
                                # Parse all parts for progress/results
                                self._parse_progress(scan_id, part)
                                # Process workflow data
                                workflow_analyzer.process_garak_output(scan_id, part)
                                # Only store the final version in output_lines
                                if part == parts[-1].strip():
                                    scan_info['output_lines'].append(part)
                    else:
                        decoded = decoded.strip()
                        if decoded:
                            scan_info['output_lines'].append(decoded)
                            logger.info(f"[{scan_id}] {decoded}")
                            self._parse_progress(scan_id, decoded)
                            # Process workflow data
                            workflow_analyzer.process_garak_output(scan_id, decoded)

            # Read stdout (which includes stderr)
            await read_stream(process.stdout)

            # Wait for completion
            returncode = await process.wait()

            # Update final status
            scan_info['completed_at'] = datetime.now().isoformat()

            # Check if error was detected during parsing (takes precedence)
            if scan_info.get('status') == ScanStatus.FAILED:
                logger.error(f"Scan {scan_id} failed: {scan_info.get('error_message')}")
            elif returncode == 0:
                scan_info['status'] = ScanStatus.COMPLETED
                scan_info['progress'] = 100.0
                logger.info(f"Scan {scan_id} completed successfully")
            else:
                scan_info['status'] = ScanStatus.FAILED
                if not scan_info.get('error_message'):
                    scan_info['error_message'] = f"Process exited with code {returncode}"
                logger.error(f"Scan {scan_id} failed with code {returncode}")

        except Exception as e:
            logger.error(f"Error running scan {scan_id}: {e}")
            scan_info['status'] = ScanStatus.FAILED
            scan_info['error_message'] = str(e)
            scan_info['completed_at'] = datetime.now().isoformat()

    def _parse_progress(self, scan_id: str, line: str):
        """Parse progress information from output line"""
        import re

        scan_info = self.active_scans[scan_id]

        # Check for error patterns first
        if 'Unknown probes' in line:
            # Extract the unknown probe names
            match = re.search(r'Unknown probes.*?:\s*(.+)', line)
            if match:
                unknown_probes = match.group(1).strip()
                scan_info['status'] = ScanStatus.FAILED
                scan_info['error_message'] = f"Unknown probes: {unknown_probes}"
                logger.error(f"[{scan_id}] {scan_info['error_message']}")
            return

        # Check for other error patterns
        if '❌' in line or 'ERROR' in line.upper() or 'FAILED' in line.upper():
            if not scan_info.get('error_message'):
                scan_info['error_message'] = line.strip()

        # Parse garak's actual output format
        # Pattern 1: "probes.web_injection.MarkdownImageExfil: 42%|████▏ | 5/12 [00:55<01:13, 10.55s/it]"
        # Full format with iterations
        full_progress_match = re.search(
            r'(probes\.\S+):\s+(\d+)%\|[^|]*\|\s*(\d+)/(\d+)\s+\[([^<]+)<([^,]+),',
            line
        )
        if full_progress_match:
            probe_name = full_progress_match.group(1)
            progress = int(full_progress_match.group(2))
            current_iter = int(full_progress_match.group(3))
            total_iter = int(full_progress_match.group(4))
            elapsed_time = full_progress_match.group(5).strip()
            remaining_time = full_progress_match.group(6).strip()

            scan_info['current_probe'] = probe_name
            scan_info['progress'] = float(progress)
            scan_info['current_iteration'] = current_iter
            scan_info['total_iterations'] = total_iter
            scan_info['elapsed_time'] = elapsed_time
            scan_info['estimated_remaining'] = remaining_time

            logger.info(f"[{scan_id}] 📊 Progress update: {probe_name} at {progress}% ({current_iter}/{total_iter})")
            return

        # Pattern 1b: Simple format without iterations - "probes.ansiescape.AnsiEscaped: 6%"
        simple_progress_match = re.search(r'(probes\.\S+):\s+(\d+)%', line)
        if simple_progress_match:
            probe_name = simple_progress_match.group(1)
            progress = int(simple_progress_match.group(2))

            scan_info['current_probe'] = probe_name
            scan_info['progress'] = float(progress)
            logger.debug(f"[{scan_id}] Progress: {probe_name} at {progress}%")
            return

        # Pattern 2: "X/Y [HH:MM:SS, speed]" - probe completion count
        # Example: "1 3/51 [00:52:13:08, 16.44s/it]"
        # IMPORTANT: This tracks WHICH PROBE we're on (1 of 4 probes)
        # NOT the progress within a probe (which is tracked by Pattern 1)
        # DO NOT set 'progress' here - only track probe counts
        if 'probes.' not in line and '%' not in line:
            probe_count_match = re.search(r'(\d+)\s+(\d+)/(\d+)\s+\[', line)
            if probe_count_match:
                current_item = int(probe_count_match.group(1))
                completed = int(probe_count_match.group(2))
                total = int(probe_count_match.group(3))

                scan_info['completed_probes'] = completed
                scan_info['total_probes'] = total

                # REMOVED: Do NOT calculate progress here!
                # Progress comes from Pattern 1 (per-probe progress bar)
                logger.info(f"[{scan_id}] 📋 Probe count: {completed}/{total}")
                return

        # Pattern 3: Probe completion line - contains both module names and PASS/FAIL
        # Example: "web_injection.MarkdownImageExfil  web_injection.MarkdownExfilContent: FAIL  ok on   59/  60"
        # Format: probe_name  detector_name: PASS/FAIL
        probe_completion_match = re.search(r'([\w\.]+)\s+([\w\.]+):\s+(PASS|FAIL)', line)
        if probe_completion_match:
            # This is a probe completion line
            probe_module = probe_completion_match.group(1)
            detector_module = probe_completion_match.group(2)

            # Only increment if we haven't already counted this probe
            # We track by probe module name to avoid counting each detector separately
            current_completed = scan_info.get('completed_probes', 0)
            last_completed_probe = scan_info.get('last_completed_probe')

            if last_completed_probe != probe_module:
                scan_info['completed_probes'] = current_completed + 1
                scan_info['last_completed_probe'] = probe_module
                logger.info(f"[{scan_id}] 🔬 Probe completed: {probe_module} ({scan_info['completed_probes']}/{scan_info['total_probes']})")

        # Pattern 3b: Extract probe name without percentage
        if 'probes.' in line:
            parts = line.split()
            for part in parts:
                if part.startswith('probes.'):
                    # Remove trailing punctuation
                    probe_name = part.rstrip(':,;')
                    scan_info['current_probe'] = probe_name
                    break

        # Pattern 4: Final results format:
        # "PASS ok on 20/20" - all tests passed
        # "FAIL ok on 59/60" - 59 passed, 1 failed (60-59=1)
        # Simplified step-by-step approach

        # Step 1: Check if line contains PASS or FAIL
        line_upper = line.upper()
        if 'PASS' in line_upper or 'FAIL' in line_upper:
            # Step 2: Check if it contains "ok on"
            if 'ok on' in line.lower():
                logger.info(f"[{scan_id}] 🔍 DEBUG - Found PASS/FAIL with 'ok on': '{line}'")

                # Step 3: Find the numbers using simple regex
                # Look for pattern like "20/ 20" or "20/20"
                numbers_match = re.search(r'(\d+)\s*/\s*(\d+)', line)
                if numbers_match:
                    tests_passed = int(numbers_match.group(1))
                    total_tests = int(numbers_match.group(2))
                    tests_failed = total_tests - tests_passed

                    logger.info(f"[{scan_id}] 🎯 DEBUG - Extracted numbers: {tests_passed}/{total_tests}")

                    # Accumulate results (multiple detectors may report results)
                    current_passed = scan_info.get('passed', 0)
                    current_failed = scan_info.get('failed', 0)

                    scan_info['passed'] = current_passed + tests_passed
                    scan_info['failed'] = current_failed + tests_failed

                    logger.info(f"[{scan_id}] ✅ Parsed results - This detector: {tests_passed} passed, {tests_failed} failed out of {total_tests} | Running total: {scan_info['passed']} passed, {scan_info['failed']} failed")
                    return
                else:
                    logger.warning(f"[{scan_id}] ⚠️  Found 'ok on' but couldn't extract numbers from: '{line}'")

        # Pattern 5: Extract HTML report path
        # Example: "📜 report html summary being written to /Users/.../.../garak.xxx.report.html"
        html_report_match = re.search(r'report html summary being written to\s+(.+\.html)', line)
        if html_report_match:
            report_path = html_report_match.group(1).strip()
            scan_info['html_report_path'] = report_path
            logger.info(f"[{scan_id}] 📊 HTML report path: {report_path}")
            return

        # Pattern 6: Extract JSONL report path
        # Example: "📜 report closed :) /Users/.../.../garak.xxx.report.jsonl"
        jsonl_report_match = re.search(r'report closed.*?([/\w\-\.]+\.jsonl)', line)
        if jsonl_report_match:
            report_path = jsonl_report_match.group(1).strip()
            scan_info['jsonl_report_path'] = report_path
            logger.info(f"[{scan_id}] 📝 JSONL report path: {report_path}")
            return

        # Pattern 7: Look for passed/failed counts
        # Example: "passed: 45, failed: 5"
        if 'passed' in line.lower() or 'failed' in line.lower():
            passed_match = re.search(r'passed[:\s]+(\d+)', line, re.IGNORECASE)
            failed_match = re.search(r'failed[:\s]+(\d+)', line, re.IGNORECASE)

            if passed_match:
                scan_info['passed'] = int(passed_match.group(1))
            if failed_match:
                scan_info['failed'] = int(failed_match.group(1))

    def get_scan_status(self, scan_id: str) -> Optional[Dict[str, Any]]:
        """Get current status of a scan (active or historical)"""
        # First check active scans
        scan_info = self.active_scans.get(scan_id)
        if scan_info:
            # Return a copy without the process object (not JSON serializable)
            return {k: v for k, v in scan_info.items() if k != 'process'}

        # If not found in active scans, check historical scans
        if self.garak_reports_dir.exists():
            report_file = self.garak_reports_dir / f"garak.{scan_id}.report.jsonl"
            if report_file.exists():
                return self._parse_report_file(report_file, scan_id)

        return None

    async def cancel_scan(self, scan_id: str) -> bool:
        """Cancel a running scan and all its child processes"""
        scan_info = self.active_scans.get(scan_id)

        if not scan_info:
            logger.warning(f"Cannot cancel scan {scan_id}: not found in active_scans")
            return False

        if scan_info['status'] not in [ScanStatus.RUNNING, ScanStatus.PENDING]:
            logger.warning(f"Cannot cancel scan {scan_id}: status is {scan_info['status']}")
            return False

        process = scan_info.get('process')
        if process:
            try:
                import os
                import signal

                pid = process.pid
                logger.info(f"[{scan_id}] Canceling scan (PID: {pid}, returncode: {process.returncode})")

                # Check if process is still alive
                if process.returncode is not None:
                    logger.info(f"[{scan_id}] Process already exited with code {process.returncode}")
                    scan_info['status'] = ScanStatus.CANCELLED
                    scan_info['completed_at'] = datetime.now().isoformat()
                    return True

                # Try multiple methods to kill the process tree
                killed = False

                # Method 1: Kill process group (Unix/macOS/Linux)
                if hasattr(os, 'killpg'):
                    try:
                        pgid = os.getpgid(pid)
                        logger.info(f"[{scan_id}] Killing process group {pgid}")
                        os.killpg(pgid, signal.SIGTERM)
                        logger.info(f"[{scan_id}] Sent SIGTERM to process group {pgid}")
                        killed = True
                    except (ProcessLookupError, OSError) as e:
                        logger.warning(f"[{scan_id}] killpg failed: {e}, trying direct kill")

                # Method 2: Direct process termination (fallback)
                if not killed or process.returncode is None:
                    try:
                        process.terminate()
                        logger.info(f"[{scan_id}] Sent terminate() to process {pid}")
                    except ProcessLookupError:
                        logger.info(f"[{scan_id}] Process {pid} not found for terminate()")

                # Wait for process to exit
                await asyncio.sleep(1)

                # Force kill if still running
                if process.returncode is None:
                    logger.info(f"[{scan_id}] Process still running after SIGTERM, sending SIGKILL")
                    try:
                        if hasattr(os, 'killpg'):
                            try:
                                pgid = os.getpgid(pid)
                                os.killpg(pgid, signal.SIGKILL)
                                logger.info(f"[{scan_id}] Sent SIGKILL to process group {pgid}")
                            except (ProcessLookupError, OSError):
                                pass
                        process.kill()
                        logger.info(f"[{scan_id}] Sent kill() to process {pid}")
                    except ProcessLookupError:
                        logger.info(f"[{scan_id}] Process {pid} not found for kill()")

                # Wait a bit more and check status
                await asyncio.sleep(0.5)
                logger.info(f"[{scan_id}] Final process returncode: {process.returncode}")

                scan_info['status'] = ScanStatus.CANCELLED
                scan_info['completed_at'] = datetime.now().isoformat()
                logger.info(f"[{scan_id}] Scan cancelled successfully")
                return True
            except Exception as e:
                logger.error(f"[{scan_id}] Error cancelling scan: {e}", exc_info=True)
                # Still mark as cancelled even if kill failed
                scan_info['status'] = ScanStatus.CANCELLED
                scan_info['completed_at'] = datetime.now().isoformat()
                return False

        logger.warning(f"[{scan_id}] Cannot cancel scan: no process found in scan_info")
        return False

    def delete_scan(self, scan_id: str) -> bool:
        """Delete a scan and all its associated reports.

        Always returns True to allow UI to remove entries even if files don't exist.
        This handles cases where files were already deleted or never existed.
        """
        from pathlib import Path

        # Remove from active scans if present
        if scan_id in self.active_scans:
            scan_info = self.active_scans[scan_id]
            # Cancel the process if still running
            if scan_info.get('process'):
                try:
                    import asyncio
                    asyncio.create_task(self.cancel_scan(scan_id))
                except Exception as e:
                    logger.warning(f"Failed to cancel running scan {scan_id}: {e}")

            del self.active_scans[scan_id]
            logger.info(f"Removed scan {scan_id} from active scans")

        # Delete report files if they exist
        if self.garak_reports_dir.exists():
            deleted_files = []
            try:
                # Find and delete all files related to this scan
                for file_pattern in [
                    f"garak.{scan_id}.report.jsonl",
                    f"garak.{scan_id}.report.html",
                    f"garak.{scan_id}.*",  # Catch any other files
                ]:
                    for file_path in self.garak_reports_dir.glob(file_pattern):
                        try:
                            file_path.unlink()
                            deleted_files.append(str(file_path))
                            logger.info(f"Deleted report file: {file_path}")
                        except Exception as e:
                            logger.error(f"Failed to delete file {file_path}: {e}")

                if deleted_files:
                    logger.info(f"Deleted {len(deleted_files)} file(s) for scan {scan_id}")
                else:
                    logger.info(f"No report files found for scan {scan_id} (already deleted or never existed)")

            except Exception as e:
                logger.error(f"Error deleting report files for scan {scan_id}: {e}")

        # Always return True - the scan entry should be removed from history
        # regardless of whether files existed. This allows users to clean up
        # stale entries where files were already deleted.
        logger.info(f"Delete request processed for scan {scan_id}")
        return True

    def get_all_scans(self) -> List[Dict[str, Any]]:
        """
        Get information about all scans (active and historical)
        Reads from configurable garak_reports directory
        """
        all_scans = []

        # Add active scans (excluding non-serializable fields)
        for scan_info in self.active_scans.values():
            # Create a copy without the process object (not JSON serializable)
            scan_copy = {k: v for k, v in scan_info.items() if k != 'process'}
            all_scans.append(scan_copy)

        # Read historical scans from garak_reports directory
        if not self.garak_reports_dir.exists():
            logger.warning(f"Garak reports directory not found: {self.garak_reports_dir}")
            return sorted(all_scans, key=lambda x: x.get('started_at', ''), reverse=True)

        try:
            # Find all report.jsonl files
            report_files = list(self.garak_reports_dir.glob("garak.*.report.jsonl"))

            for report_file in report_files:
                try:
                    # Extract scan ID from filename (e.g., garak.20240101_120000.report.jsonl)
                    scan_id = report_file.stem.replace("garak.", "").replace(".report", "")

                    # Skip if this scan is already in active_scans
                    if scan_id in self.active_scans:
                        continue

                    # Read the report file to extract scan information
                    scan_info = self._parse_report_file(report_file, scan_id)

                    if scan_info:
                        all_scans.append(scan_info)

                except Exception as e:
                    logger.error(f"Error parsing report file {report_file}: {e}")
                    continue

        except Exception as e:
            logger.error(f"Error reading garak runs directory: {e}")

        # Sort by started_at in reverse chronological order (most recent first)
        return sorted(all_scans, key=lambda x: x.get('started_at', ''), reverse=True)

    def _parse_report_file(self, report_file: Path, scan_id: str) -> Optional[Dict[str, Any]]:
        """
        Parse a garak report.jsonl file to extract scan information

        Args:
            report_file: Path to the report.jsonl file
            scan_id: Scan identifier extracted from filename

        Returns:
            Scan information dictionary or None if parsing fails
        """
        try:
            # Read the JSONL file
            with open(report_file, 'r', encoding='utf-8') as f:
                lines = f.readlines()

            if not lines:
                return None

            # Parse first line to get scan metadata
            first_entry = json.loads(lines[0])

            # Initialize scan info using correct garak 0.13.2 field names
            scan_info = {
                'scan_id': scan_id,
                'status': 'completed',  # Historical scans are completed
                'target_type': first_entry.get('plugins.target_type', 'unknown'),
                'target_name': first_entry.get('plugins.target_name', 'unknown'),
                'started_at': first_entry.get('transient.starttime_iso', ''),
                'completed_at': first_entry.get('transient.endtime_iso', ''),
                'passed': 0,
                'failed': 0,
                'total_tests': 0,
                'progress': 100.0,  # Historical scans are completed
            }

            # Add HTML report path if it exists
            html_report_path = report_file.parent / f"garak.{scan_id}.report.html"
            if html_report_path.exists():
                scan_info['html_report_path'] = str(html_report_path)

            # Add JSONL report path
            scan_info['jsonl_report_path'] = str(report_file)

            # Count test results by parsing all entries
            for line in lines:
                try:
                    entry = json.loads(line)

                    # Check if this is a test result entry
                    if 'status' in entry and entry.get('status') in [1, 2]:
                        scan_info['total_tests'] += 1

                        if entry['status'] == 2:  # Pass
                            scan_info['passed'] += 1
                        elif entry['status'] == 1:  # Fail
                            scan_info['failed'] += 1

                except json.JSONDecodeError:
                    continue

            # Get file modification time as fallback for started_at
            if not scan_info['started_at']:
                file_mtime = datetime.fromtimestamp(report_file.stat().st_mtime)
                scan_info['started_at'] = file_mtime.isoformat()

            return scan_info

        except Exception as e:
            logger.error(f"Error parsing report file {report_file}: {e}")
            return None

    def get_scan_results(self, scan_id: str) -> Optional[Dict[str, Any]]:
        """
        Get detailed scan results including probe-level breakdown

        Args:
            scan_id: Unique scan identifier

        Returns:
            Detailed scan results or None if not found
        """
        # Use get_scan_status to support both active and historical scans
        scan_info = self.get_scan_status(scan_id)

        if not scan_info:
            return None

        # Return full scan details with results breakdown
        # Handle config field (may not exist for historical scans)
        config_data = None
        if 'config' in scan_info:
            config = scan_info['config']
            config_data = config.model_dump() if hasattr(config, 'model_dump') else config

        results = {
            'scan_id': scan_id,
            'status': scan_info['status'],
            'config': config_data,
            'created_at': scan_info.get('created_at'),
            'started_at': scan_info.get('started_at'),  # Add started_at for historical scans
            'completed_at': scan_info.get('completed_at'),
            'duration': self._calculate_duration(scan_info),
            'results': {
                'passed': scan_info.get('passed', 0),
                'failed': scan_info.get('failed', 0),
                'total_probes': scan_info.get('total_probes', 0),
                'completed_probes': scan_info.get('completed_probes', 0),
                'current_probe': scan_info.get('current_probe'),
                'progress': scan_info.get('progress', 0.0),
            },
            'summary': {
                'total_tests': scan_info.get('passed', 0) + scan_info.get('failed', 0),
                'pass_rate': self._calculate_pass_rate(scan_info),
                'status': scan_info['status'],
                'error_message': scan_info.get('error_message'),
            },
            'html_report_path': scan_info.get('html_report_path'),
            'jsonl_report_path': scan_info.get('jsonl_report_path'),
            'output_lines': scan_info.get('output_lines', [])
        }

        return results

    def _calculate_duration(self, scan_info: Dict[str, Any]) -> Optional[float]:
        """Calculate scan duration in seconds"""
        if not scan_info.get('started_at') or not scan_info.get('completed_at'):
            return None

        try:
            from datetime import datetime
            start = datetime.fromisoformat(scan_info['started_at'])
            end = datetime.fromisoformat(scan_info['completed_at'])
            return (end - start).total_seconds()
        except:
            return None

    def _calculate_pass_rate(self, scan_info: Dict[str, Any]) -> float:
        """Calculate pass rate percentage"""
        passed = scan_info.get('passed', 0)
        failed = scan_info.get('failed', 0)
        total = passed + failed

        if total == 0:
            return 0.0

        return (passed / total) * 100.0


# Global instance
# Import settings to get custom garak path if specified
try:
    from config import settings
    garak_wrapper = GarakWrapper(garak_path=settings.garak_path)
except ImportError:
    garak_wrapper = GarakWrapper()
