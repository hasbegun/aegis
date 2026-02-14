"""
Upload garak report files to Minio after scan completion.

After garak finishes and the report files have been renamed locally
(with the correct scan_id), this module uploads them to the configured
Minio bucket under the key pattern: {scan_id}/report.jsonl, etc.

If Minio is not configured, this is a no-op.
"""
import logging
import os
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)

# Max upload retries on transient failures
MAX_RETRIES = 3


def _get_minio_client():
    """Create a Minio client from env vars. Returns None if not configured."""
    endpoint = os.environ.get("MINIO_ENDPOINT")
    access_key = os.environ.get("MINIO_ACCESS_KEY")
    secret_key = os.environ.get("MINIO_SECRET_KEY")

    if not endpoint or not access_key or not secret_key:
        return None

    try:
        from minio import Minio
        secure = os.environ.get("MINIO_SECURE", "false").lower() == "true"
        return Minio(endpoint, access_key=access_key, secret_key=secret_key, secure=secure)
    except ImportError:
        logger.warning("minio package not installed, skipping upload")
        return None


def _get_bucket() -> str:
    return os.environ.get("MINIO_BUCKET", "aegis-reports")


def _ensure_bucket(client, bucket: str) -> None:
    """Create bucket if it doesn't exist."""
    if not client.bucket_exists(bucket):
        client.make_bucket(bucket)
        logger.info(f"Created Minio bucket: {bucket}")


def upload_report_files(scan_id: str, reports_dir: Path) -> dict[str, Optional[str]]:
    """Upload all report files for a scan to Minio.

    Looks for these files in reports_dir:
      - garak.{scan_id}.report.jsonl
      - garak.{scan_id}.hitlog.jsonl
      - garak.{scan_id}.report.html

    Returns a dict mapping report type → Minio object key (or None if not found/failed).
    """
    client = _get_minio_client()
    if client is None:
        logger.debug("Minio not configured, skipping upload")
        return {}

    bucket = _get_bucket()
    _ensure_bucket(client, bucket)

    file_map = {
        "jsonl": f"garak.{scan_id}.report.jsonl",
        "hitlog": f"garak.{scan_id}.hitlog.jsonl",
        "html": f"garak.{scan_id}.report.html",
    }

    content_types = {
        "jsonl": "application/jsonl",
        "hitlog": "application/jsonl",
        "html": "text/html",
    }

    results: dict[str, Optional[str]] = {}

    for report_type, filename in file_map.items():
        local_path = reports_dir / filename
        if not local_path.exists():
            results[report_type] = None
            continue

        object_key = f"{scan_id}/{filename}"

        for attempt in range(1, MAX_RETRIES + 1):
            try:
                client.fput_object(
                    bucket,
                    object_key,
                    str(local_path),
                    content_type=content_types.get(report_type, "application/octet-stream"),
                )
                results[report_type] = object_key
                logger.info(f"Uploaded {filename} → s3://{bucket}/{object_key}")
                break
            except Exception as e:
                if attempt < MAX_RETRIES:
                    logger.warning(
                        f"Upload attempt {attempt}/{MAX_RETRIES} failed for {filename}: {e}"
                    )
                else:
                    logger.error(f"Upload failed after {MAX_RETRIES} attempts for {filename}: {e}")
                    results[report_type] = None

    return results
