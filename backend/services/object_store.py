"""
Object storage abstraction for report artifacts (JSONL, HTML, hitlog).

Two backends:
  - LocalStorage: reads/writes files on a local/shared filesystem (legacy)
  - MinioStorage: reads/writes objects via S3-compatible Minio API

Selected by the STORAGE_BACKEND env var ("local" or "minio").
"""
import io
import logging
import os
from abc import ABC, abstractmethod
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)


class StorageBackend(ABC):
    """Abstract interface for object/file storage."""

    @abstractmethod
    def get(self, key: str) -> Optional[bytes]:
        """Retrieve an object by key. Returns None if not found."""

    @abstractmethod
    def get_stream(self, key: str):
        """Return a file-like readable stream for the given key.

        Returns None if the object does not exist.
        Caller is responsible for closing the stream.
        """

    @abstractmethod
    def put(self, key: str, data: bytes, content_type: str = "application/octet-stream") -> None:
        """Store an object."""

    @abstractmethod
    def put_file(self, key: str, file_path: str, content_type: str = "application/octet-stream") -> None:
        """Upload a local file to the store."""

    @abstractmethod
    def exists(self, key: str) -> bool:
        """Check if an object exists."""

    @abstractmethod
    def delete(self, key: str) -> bool:
        """Delete an object. Returns True if deleted, False if not found."""

    @abstractmethod
    def list_keys(self, prefix: str = "") -> list[str]:
        """List object keys matching a prefix."""


class LocalStorage(StorageBackend):
    """File-system-backed storage (legacy shared volume)."""

    def __init__(self, base_dir: str | Path):
        self._base = Path(base_dir)
        self._base.mkdir(parents=True, exist_ok=True)
        logger.info(f"LocalStorage initialized: {self._base}")

    def _path(self, key: str) -> Path:
        # Flatten key: "abc123/report.jsonl" → "abc123/report.jsonl" as nested dir
        # But for backward compat, also support flat keys like "garak.abc123.report.jsonl"
        return self._base / key

    def get(self, key: str) -> Optional[bytes]:
        p = self._path(key)
        if not p.exists():
            return None
        return p.read_bytes()

    def get_stream(self, key: str):
        p = self._path(key)
        if not p.exists():
            return None
        return open(p, "rb")

    def put(self, key: str, data: bytes, content_type: str = "application/octet-stream") -> None:
        p = self._path(key)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_bytes(data)

    def put_file(self, key: str, file_path: str, content_type: str = "application/octet-stream") -> None:
        src = Path(file_path)
        if not src.exists():
            raise FileNotFoundError(f"Source file not found: {file_path}")
        self.put(key, src.read_bytes(), content_type)

    def exists(self, key: str) -> bool:
        return self._path(key).exists()

    def delete(self, key: str) -> bool:
        p = self._path(key)
        if not p.exists():
            return False
        p.unlink()
        return True

    def list_keys(self, prefix: str = "") -> list[str]:
        keys = []
        for p in self._base.rglob("*"):
            if p.is_file():
                rel = str(p.relative_to(self._base))
                if rel.startswith(prefix):
                    keys.append(rel)
        return sorted(keys)


class MinioStorage(StorageBackend):
    """S3-compatible Minio object storage."""

    def __init__(
        self,
        endpoint: str,
        access_key: str,
        secret_key: str,
        bucket: str,
        secure: bool = False,
    ):
        from minio import Minio

        self._client = Minio(
            endpoint,
            access_key=access_key,
            secret_key=secret_key,
            secure=secure,
        )
        self._bucket = bucket
        self._ensure_bucket()
        logger.info(f"MinioStorage initialized: {endpoint}/{bucket}")

    def _ensure_bucket(self) -> None:
        """Create the bucket if it doesn't exist."""
        if not self._client.bucket_exists(self._bucket):
            self._client.make_bucket(self._bucket)
            logger.info(f"Created Minio bucket: {self._bucket}")

    def get(self, key: str) -> Optional[bytes]:
        try:
            response = self._client.get_object(self._bucket, key)
            data = response.read()
            response.close()
            response.release_conn()
            return data
        except Exception as e:
            if "NoSuchKey" in str(e) or "not found" in str(e).lower():
                return None
            logger.error(f"MinioStorage.get error for key '{key}': {e}")
            raise

    def get_stream(self, key: str):
        try:
            response = self._client.get_object(self._bucket, key)
            return response
        except Exception as e:
            if "NoSuchKey" in str(e) or "not found" in str(e).lower():
                return None
            logger.error(f"MinioStorage.get_stream error for key '{key}': {e}")
            raise

    def put(self, key: str, data: bytes, content_type: str = "application/octet-stream") -> None:
        self._client.put_object(
            self._bucket,
            key,
            io.BytesIO(data),
            length=len(data),
            content_type=content_type,
        )

    def put_file(self, key: str, file_path: str, content_type: str = "application/octet-stream") -> None:
        self._client.fput_object(
            self._bucket,
            key,
            file_path,
            content_type=content_type,
        )

    def exists(self, key: str) -> bool:
        try:
            self._client.stat_object(self._bucket, key)
            return True
        except Exception:
            return False

    def delete(self, key: str) -> bool:
        if not self.exists(key):
            return False
        self._client.remove_object(self._bucket, key)
        return True

    def list_keys(self, prefix: str = "") -> list[str]:
        objects = self._client.list_objects(self._bucket, prefix=prefix, recursive=True)
        return sorted(obj.object_name for obj in objects)


# ---------------------------------------------------------------------------
# Singleton: initialized once at startup, used by all services
# ---------------------------------------------------------------------------

_store: Optional[StorageBackend] = None


def init_object_store() -> StorageBackend:
    """Initialize the global object store based on configuration.

    Called once at application startup (in main.py lifespan).
    """
    global _store

    from config import settings

    backend = settings.storage_backend.lower()

    if backend == "minio":
        _store = MinioStorage(
            endpoint=settings.minio_endpoint,
            access_key=settings.minio_access_key,
            secret_key=settings.minio_secret_key,
            bucket=settings.minio_bucket,
            secure=settings.minio_secure,
        )
    else:
        _store = LocalStorage(settings.garak_reports_path)

    return _store


def get_object_store() -> StorageBackend:
    """Get the initialized object store. Raises if not initialized."""
    if _store is None:
        raise RuntimeError("Object store not initialized. Call init_object_store() first.")
    return _store


def object_store_available() -> bool:
    """Check if the object store has been initialized."""
    return _store is not None
