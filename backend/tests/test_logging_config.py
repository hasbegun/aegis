"""
Tests for M16 (structured JSON logging) and M17 (log rotation).

Covers:
- JSON formatter output
- Text formatter fallback
- Extra fields merged into JSON
- Log rotation (RotatingFileHandler) setup
- Console-only when no log_file
- Noisy logger suppression
"""

import json
import logging
import os
import sys
import tempfile
from pathlib import Path

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from logging_config import setup_logging


@pytest.fixture(autouse=True)
def reset_root_logger():
    """Reset the root logger between tests."""
    root = logging.getLogger()
    yield
    root.handlers.clear()
    root.setLevel(logging.WARNING)


# ---------------------------------------------------------------------------
# JSON format (M16)
# ---------------------------------------------------------------------------

class TestJSONFormat:

    def test_json_output_is_valid_json(self, capsys):
        setup_logging(level="INFO", log_format="json")
        logger = logging.getLogger("test.json_valid")
        logger.info("hello world")

        output = capsys.readouterr().out.strip()
        data = json.loads(output)
        assert data["message"] == "hello world"

    def test_json_has_standard_fields(self, capsys):
        setup_logging(level="INFO", log_format="json")
        logger = logging.getLogger("test.json_fields")
        logger.warning("check fields")

        data = json.loads(capsys.readouterr().out.strip())
        assert "timestamp" in data
        assert data["level"] == "WARNING"
        assert data["logger"] == "test.json_fields"
        assert data["message"] == "check fields"

    def test_json_extra_fields_merged(self, capsys):
        setup_logging(level="INFO", log_format="json")
        logger = logging.getLogger("test.json_extra")
        logger.info("request", extra={"scan_id": "abc-123", "status_code": 200})

        data = json.loads(capsys.readouterr().out.strip())
        assert data["scan_id"] == "abc-123"
        assert data["status_code"] == 200

    def test_json_timestamp_format(self, capsys):
        setup_logging(level="INFO", log_format="json")
        logger = logging.getLogger("test.json_ts")
        logger.info("ts check")

        data = json.loads(capsys.readouterr().out.strip())
        ts = data["timestamp"]
        # Should be ISO-8601 like "2026-02-11T22:16:44"
        assert "T" in ts
        assert len(ts) >= 19  # YYYY-MM-DDTHH:MM:SS

    def test_json_debug_not_shown_at_info_level(self, capsys):
        setup_logging(level="INFO", log_format="json")
        logger = logging.getLogger("test.json_level")
        logger.debug("should not appear")

        output = capsys.readouterr().out.strip()
        assert output == ""


# ---------------------------------------------------------------------------
# Text format fallback
# ---------------------------------------------------------------------------

class TestTextFormat:

    def test_text_output_is_plain(self, capsys):
        setup_logging(level="INFO", log_format="text")
        logger = logging.getLogger("test.text_plain")
        logger.info("plain message")

        output = capsys.readouterr().out.strip()
        assert "plain message" in output
        assert "test.text_plain" in output
        assert "INFO" in output
        # Should NOT be parseable as JSON
        with pytest.raises(json.JSONDecodeError):
            json.loads(output)

    def test_text_format_includes_timestamp(self, capsys):
        setup_logging(level="INFO", log_format="text")
        logger = logging.getLogger("test.text_ts")
        logger.info("check")

        output = capsys.readouterr().out.strip()
        # Standard format: "2026-02-11 22:16:44,510 - ..."
        assert " - " in output


# ---------------------------------------------------------------------------
# Log level configuration
# ---------------------------------------------------------------------------

class TestLogLevel:

    def test_debug_level_shows_debug(self, capsys):
        setup_logging(level="DEBUG", log_format="json")
        logger = logging.getLogger("test.level_debug")
        logger.debug("debug msg")

        output = capsys.readouterr().out.strip()
        assert output != ""
        data = json.loads(output)
        assert data["level"] == "DEBUG"

    def test_error_level_hides_info(self, capsys):
        setup_logging(level="ERROR", log_format="json")
        logger = logging.getLogger("test.level_error")
        logger.info("should be hidden")

        output = capsys.readouterr().out.strip()
        assert output == ""

    def test_case_insensitive_level(self, capsys):
        setup_logging(level="info", log_format="json")
        logger = logging.getLogger("test.level_case")
        logger.info("works")

        output = capsys.readouterr().out.strip()
        assert output != ""


# ---------------------------------------------------------------------------
# Log rotation (M17)
# ---------------------------------------------------------------------------

class TestLogRotation:

    def test_file_handler_created_when_log_file_set(self):
        with tempfile.NamedTemporaryFile(suffix=".log", delete=False) as f:
            log_path = f.name

        try:
            setup_logging(level="INFO", log_format="json", log_file=log_path)
            root = logging.getLogger()

            # Should have 2 handlers: console + file
            assert len(root.handlers) == 2
            from logging.handlers import RotatingFileHandler
            file_handlers = [h for h in root.handlers if isinstance(h, RotatingFileHandler)]
            assert len(file_handlers) == 1
        finally:
            os.unlink(log_path)

    def test_no_file_handler_when_log_file_none(self):
        setup_logging(level="INFO", log_format="json", log_file=None)
        root = logging.getLogger()

        from logging.handlers import RotatingFileHandler
        file_handlers = [h for h in root.handlers if isinstance(h, RotatingFileHandler)]
        assert len(file_handlers) == 0
        assert len(root.handlers) == 1  # console only

    def test_file_handler_uses_configured_rotation(self):
        with tempfile.NamedTemporaryFile(suffix=".log", delete=False) as f:
            log_path = f.name

        try:
            setup_logging(
                level="INFO", log_format="json",
                log_file=log_path, max_bytes=5_000_000, backup_count=3,
            )
            root = logging.getLogger()
            from logging.handlers import RotatingFileHandler
            file_handler = [h for h in root.handlers if isinstance(h, RotatingFileHandler)][0]

            assert file_handler.maxBytes == 5_000_000
            assert file_handler.backupCount == 3
        finally:
            os.unlink(log_path)

    def test_file_receives_log_output(self):
        with tempfile.NamedTemporaryFile(suffix=".log", delete=False, mode="w") as f:
            log_path = f.name

        try:
            setup_logging(level="INFO", log_format="json", log_file=log_path)
            logger = logging.getLogger("test.file_output")
            logger.info("written to file")

            # Flush handlers
            for h in logging.getLogger().handlers:
                h.flush()

            content = Path(log_path).read_text().strip()
            assert content != ""
            data = json.loads(content)
            assert data["message"] == "written to file"
        finally:
            os.unlink(log_path)

    def test_file_uses_same_formatter_as_console(self):
        with tempfile.NamedTemporaryFile(suffix=".log", delete=False) as f:
            log_path = f.name

        try:
            setup_logging(level="INFO", log_format="text", log_file=log_path)
            logger = logging.getLogger("test.file_format")
            logger.info("text format in file")

            for h in logging.getLogger().handlers:
                h.flush()

            content = Path(log_path).read_text().strip()
            # Text format: should NOT be JSON
            with pytest.raises(json.JSONDecodeError):
                json.loads(content)
            assert "text format in file" in content
        finally:
            os.unlink(log_path)


# ---------------------------------------------------------------------------
# Noisy logger suppression
# ---------------------------------------------------------------------------

class TestNoisyLoggers:

    def test_uvicorn_access_suppressed(self):
        setup_logging(level="DEBUG", log_format="json")
        uvicorn_access = logging.getLogger("uvicorn.access")
        assert uvicorn_access.level >= logging.WARNING

    def test_httpx_suppressed(self):
        setup_logging(level="DEBUG", log_format="json")
        httpx_logger = logging.getLogger("httpx")
        assert httpx_logger.level >= logging.WARNING

    def test_httpcore_suppressed(self):
        setup_logging(level="DEBUG", log_format="json")
        httpcore_logger = logging.getLogger("httpcore")
        assert httpcore_logger.level >= logging.WARNING


# ---------------------------------------------------------------------------
# Handler cleanup
# ---------------------------------------------------------------------------

class TestHandlerCleanup:

    def test_no_duplicate_handlers_on_repeated_setup(self, capsys):
        """Calling setup_logging twice should not double handlers."""
        setup_logging(level="INFO", log_format="json")
        setup_logging(level="INFO", log_format="json")

        root = logging.getLogger()
        assert len(root.handlers) == 1  # console only, not duplicated

    def test_format_switch_replaces_handlers(self, capsys):
        """Switching from text to json should replace the handler."""
        setup_logging(level="INFO", log_format="text")
        setup_logging(level="INFO", log_format="json")

        logger = logging.getLogger("test.switch")
        logger.info("after switch")

        output = capsys.readouterr().out.strip()
        data = json.loads(output)  # should be JSON now
        assert data["message"] == "after switch"
