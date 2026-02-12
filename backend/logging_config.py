"""
Structured JSON logging and log rotation configuration.

M16: Structured JSON logging — each log line is a JSON object.
M17: Log rotation — optional file handler with size-based rotation.
"""

import logging
import sys
from logging.handlers import RotatingFileHandler

from pythonjsonlogger.json import JsonFormatter


def setup_logging(
    level: str = "INFO",
    log_format: str = "json",
    log_file: str | None = None,
    max_bytes: int = 10_485_760,
    backup_count: int = 5,
) -> None:
    """Configure root logger with JSON or text formatting and optional file rotation.

    Args:
        level: Log level (DEBUG, INFO, WARNING, ERROR, CRITICAL).
        log_format: "json" for structured JSON, "text" for plain text.
        log_file: Optional file path. When set, logs are written to a
                  rotating file *in addition* to console.
        max_bytes: Max log file size before rotation (default 10 MB).
        backup_count: Number of rotated backup files to keep.
    """
    root = logging.getLogger()
    root.setLevel(getattr(logging, level.upper(), logging.INFO))

    # Clear any existing handlers (e.g. from basicConfig)
    root.handlers.clear()

    # Build formatter
    if log_format == "json":
        formatter = JsonFormatter(
            fmt="%(asctime)s %(levelname)s %(name)s %(message)s",
            rename_fields={"asctime": "timestamp", "levelname": "level", "name": "logger"},
            datefmt="%Y-%m-%dT%H:%M:%S",
        )
    else:
        formatter = logging.Formatter(
            "%(asctime)s - %(name)s - %(levelname)s - %(message)s"
        )

    # Console handler (always present — required for Docker log capture)
    console = logging.StreamHandler(sys.stdout)
    console.setFormatter(formatter)
    root.addHandler(console)

    # File handler with rotation (optional)
    if log_file:
        file_handler = RotatingFileHandler(
            log_file,
            maxBytes=max_bytes,
            backupCount=backup_count,
        )
        file_handler.setFormatter(formatter)
        root.addHandler(file_handler)

    # Quiet noisy third-party loggers
    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
    logging.getLogger("httpx").setLevel(logging.WARNING)
    logging.getLogger("httpcore").setLevel(logging.WARNING)
