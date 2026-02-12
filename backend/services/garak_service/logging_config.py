"""
Structured JSON logging and log rotation for the garak service container.

Configuration via environment variables:
  LOG_LEVEL       — DEBUG, INFO (default), WARNING, ERROR, CRITICAL
  LOG_FORMAT      — "json" (default) or "text"
  LOG_FILE        — optional file path (console-only when unset)
  LOG_MAX_BYTES   — max file size before rotation (default 10 MB)
  LOG_BACKUP_COUNT — rotated files to keep (default 5)
"""

import logging
import os
import sys
from logging.handlers import RotatingFileHandler

from pythonjsonlogger.json import JsonFormatter


def setup_logging() -> None:
    level = os.environ.get("LOG_LEVEL", "INFO").upper()
    log_format = os.environ.get("LOG_FORMAT", "json")
    log_file = os.environ.get("LOG_FILE")
    max_bytes = int(os.environ.get("LOG_MAX_BYTES", 10_485_760))
    backup_count = int(os.environ.get("LOG_BACKUP_COUNT", 5))

    root = logging.getLogger()
    root.setLevel(getattr(logging, level, logging.INFO))
    root.handlers.clear()

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

    console = logging.StreamHandler(sys.stdout)
    console.setFormatter(formatter)
    root.addHandler(console)

    if log_file:
        file_handler = RotatingFileHandler(
            log_file, maxBytes=max_bytes, backupCount=backup_count,
        )
        file_handler.setFormatter(formatter)
        root.addHandler(file_handler)

    logging.getLogger("uvicorn.access").setLevel(logging.WARNING)
