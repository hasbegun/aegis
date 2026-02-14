"""
Tests for H1.1: Object store abstraction and Minio integration.

Covers:
- LocalStorage backend (get, put, put_file, exists, delete, list_keys, get_stream)
- MinioStorage backend (mocked)
- init_object_store() factory with config-driven selection
- Object store integration in garak_wrapper (Minio reads, immutable cache)
- Schema migrations (_add_column_if_missing, _run_schema_migrations)
- Scan model new columns (report_key, html_report_key, probe_stats_json)
- Materialized probe stats
- Object store delete in delete_scan
"""
import json
import os
import sys
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from services.object_store import (
    LocalStorage,
    MinioStorage,
    init_object_store,
    get_object_store,
    object_store_available,
)


# ---------------------------------------------------------------------------
# LocalStorage tests
# ---------------------------------------------------------------------------

class TestLocalStorage:

    @pytest.fixture
    def store(self, tmp_path):
        return LocalStorage(tmp_path)

    def test_put_and_get(self, store):
        store.put("test.txt", b"hello world")
        data = store.get("test.txt")
        assert data == b"hello world"

    def test_get_nonexistent_returns_none(self, store):
        assert store.get("missing.txt") is None

    def test_put_creates_nested_dirs(self, store):
        store.put("a/b/c/file.txt", b"nested")
        assert store.get("a/b/c/file.txt") == b"nested"

    def test_put_file(self, store, tmp_path):
        src = tmp_path / "source.txt"
        src.write_bytes(b"from file")
        store.put_file("uploaded.txt", str(src))
        assert store.get("uploaded.txt") == b"from file"

    def test_put_file_missing_raises(self, store):
        with pytest.raises(FileNotFoundError):
            store.put_file("key", "/nonexistent/file.txt")

    def test_exists(self, store):
        assert store.exists("nope") is False
        store.put("yep", b"data")
        assert store.exists("yep") is True

    def test_delete(self, store):
        store.put("to_delete", b"data")
        assert store.delete("to_delete") is True
        assert store.exists("to_delete") is False

    def test_delete_nonexistent(self, store):
        assert store.delete("ghost") is False

    def test_list_keys(self, store):
        store.put("a/file1.txt", b"1")
        store.put("a/file2.txt", b"2")
        store.put("b/file3.txt", b"3")

        all_keys = store.list_keys()
        assert len(all_keys) == 3

        a_keys = store.list_keys(prefix="a/")
        assert len(a_keys) == 2
        assert all(k.startswith("a/") for k in a_keys)

    def test_get_stream(self, store):
        store.put("stream.txt", b"stream data")
        stream = store.get_stream("stream.txt")
        assert stream is not None
        try:
            assert stream.read() == b"stream data"
        finally:
            stream.close()

    def test_get_stream_nonexistent(self, store):
        assert store.get_stream("missing") is None


# ---------------------------------------------------------------------------
# MinioStorage tests (mocked — construct with __new__ to avoid real Minio)
# ---------------------------------------------------------------------------

class TestMinioStorageMocked:

    @pytest.fixture
    def mock_client(self):
        client = MagicMock()
        client.bucket_exists.return_value = True
        return client

    @pytest.fixture
    def store(self, mock_client):
        s = MinioStorage.__new__(MinioStorage)
        s._client = mock_client
        s._bucket = "test-bucket"
        return s

    def test_get_success(self, store, mock_client):
        response = MagicMock()
        response.read.return_value = b"minio data"
        mock_client.get_object.return_value = response

        data = store.get("key")
        assert data == b"minio data"
        response.close.assert_called_once()
        response.release_conn.assert_called_once()

    def test_get_not_found(self, store, mock_client):
        mock_client.get_object.side_effect = Exception("NoSuchKey")
        assert store.get("missing") is None

    def test_put(self, store, mock_client):
        store.put("key", b"data", content_type="text/plain")
        mock_client.put_object.assert_called_once()
        args = mock_client.put_object.call_args
        assert args[0][0] == "test-bucket"
        assert args[0][1] == "key"

    def test_exists_true(self, store, mock_client):
        mock_client.stat_object.return_value = MagicMock()
        assert store.exists("key") is True

    def test_exists_false(self, store, mock_client):
        mock_client.stat_object.side_effect = Exception("not found")
        assert store.exists("key") is False

    def test_delete(self, store, mock_client):
        mock_client.stat_object.return_value = MagicMock()
        assert store.delete("key") is True
        mock_client.remove_object.assert_called_once()

    def test_list_keys(self, store, mock_client):
        obj1 = MagicMock()
        obj1.object_name = "a/file1"
        obj2 = MagicMock()
        obj2.object_name = "a/file2"
        mock_client.list_objects.return_value = [obj1, obj2]

        keys = store.list_keys(prefix="a/")
        assert keys == ["a/file1", "a/file2"]


# ---------------------------------------------------------------------------
# init_object_store factory
# ---------------------------------------------------------------------------

class TestInitObjectStore:

    def test_local_backend(self, tmp_path):
        import services.object_store as mod
        old_store = mod._store
        try:
            with patch("config.settings") as mock_settings:
                mock_settings.storage_backend = "local"
                mock_settings.garak_reports_path = tmp_path
                store = init_object_store()
                assert isinstance(store, LocalStorage)
                assert object_store_available() is True
        finally:
            mod._store = old_store

    def test_get_object_store_raises_when_not_initialized(self):
        import services.object_store as mod
        old_store = mod._store
        try:
            mod._store = None
            assert object_store_available() is False
            with pytest.raises(RuntimeError, match="not initialized"):
                get_object_store()
        finally:
            mod._store = old_store


# ---------------------------------------------------------------------------
# Scan model new columns
# ---------------------------------------------------------------------------

class TestScanModelNewColumns:

    @pytest.fixture(autouse=True)
    def reset_db(self):
        import database.session as sess
        old_engine = sess._engine
        old_factory = sess._SessionFactory
        yield
        sess._engine = old_engine
        sess._SessionFactory = old_factory

    @pytest.fixture
    def db(self):
        from database.session import init_db, get_db
        init_db(":memory:")
        return get_db

    def test_report_key_columns_exist(self, db):
        from database.models import Scan
        with db() as session:
            scan = Scan(
                id="key-test",
                target_type="ollama",
                target_name="llama3",
                status="completed",
                report_key="key-test/garak.key-test.report.jsonl",
                html_report_key="key-test/garak.key-test.report.html",
            )
            session.add(scan)
            session.commit()

            result = session.query(Scan).filter_by(id="key-test").first()
            assert result.report_key == "key-test/garak.key-test.report.jsonl"
            assert result.html_report_key == "key-test/garak.key-test.report.html"

    def test_probe_stats_json_column(self, db):
        from database.models import Scan
        stats = {"dan": {"passed": 5, "failed": 3}, "encoding": {"passed": 2, "failed": 0}}
        with db() as session:
            scan = Scan(
                id="stats-test",
                target_type="ollama",
                target_name="llama3",
                status="completed",
                probe_stats_json=json.dumps(stats),
            )
            session.add(scan)
            session.commit()

            result = session.query(Scan).filter_by(id="stats-test").first()
            loaded = json.loads(result.probe_stats_json)
            assert loaded == stats

    def test_to_dict_includes_keys(self, db):
        from database.models import Scan
        with db() as session:
            scan = Scan(
                id="dict-test",
                target_type="ollama",
                target_name="llama3",
                status="completed",
                report_key="rk",
                html_report_key="hrk",
            )
            session.add(scan)
            session.commit()

            d = scan.to_dict()
            assert d["report_key"] == "rk"
            assert d["html_report_key"] == "hrk"


# ---------------------------------------------------------------------------
# Schema migrations
# ---------------------------------------------------------------------------

class TestSchemaMigrations:

    @pytest.fixture(autouse=True)
    def reset_db(self):
        import database.session as sess
        old_engine = sess._engine
        old_factory = sess._SessionFactory
        yield
        sess._engine = old_engine
        sess._SessionFactory = old_factory

    def test_add_column_if_missing(self):
        """Verify _add_column_if_missing is idempotent."""
        from database.session import init_db
        from database.migrations import _add_column_if_missing
        import database.session as sess

        init_db(":memory:")

        # Column already exists (added by model definition)
        added = _add_column_if_missing(sess._engine, "scans", "report_key", "VARCHAR")
        assert added is False  # already present

    def test_run_schema_migrations_idempotent(self):
        """Running migrations twice should not raise."""
        from database.session import init_db
        from database.migrations import _run_schema_migrations
        import database.session as sess

        init_db(":memory:")

        # Run twice — should not raise
        _run_schema_migrations(sess._engine)
        _run_schema_migrations(sess._engine)


# ---------------------------------------------------------------------------
# Object store integration in garak_wrapper
# ---------------------------------------------------------------------------

SCAN_ID = "objstore-test-001"


def _sample_entries():
    return [
        {
            "entry_type": "config",
            "plugins.target_type": "ollama",
            "plugins.target_name": "llama3.2:3b",
            "transient.starttime_iso": "2025-01-01T00:00:00",
            "transient.endtime_iso": "2025-01-01T00:05:00",
        },
        {
            "entry_type": "attempt",
            "probe_classname": "dan.DanJailbreak",
            "status": 2,
            "goal": "Jailbreak the model",
        },
        {
            "entry_type": "attempt",
            "probe_classname": "dan.DanJailbreak",
            "status": 1,
            "goal": "Jailbreak the model",
        },
    ]


def _make_jsonl(entries):
    return "\n".join(json.dumps(e) for e in entries)


class TestObjectStoreIntegration:

    @pytest.fixture
    def store_dir(self, tmp_path):
        return tmp_path / "store"

    @pytest.fixture
    def local_store(self, store_dir):
        return LocalStorage(store_dir)

    @pytest.fixture
    def wrapper(self, tmp_path):
        from services.garak_wrapper import GarakWrapper
        reports_dir = tmp_path / "reports"
        reports_dir.mkdir()
        with patch("services.garak_wrapper.settings") as mock_settings:
            mock_settings.garak_service_url = "http://localhost:9090"
            mock_settings.garak_reports_path = reports_dir
            w = GarakWrapper(cache_ttl=2)
        return w

    def test_reads_from_object_store(self, wrapper, local_store):
        """If JSONL is in object store, _get_report_entries should find it."""
        jsonl = _make_jsonl(_sample_entries())
        key = f"{SCAN_ID}/garak.{SCAN_ID}.report.jsonl"
        local_store.put(key, jsonl.encode("utf-8"))

        # Patch at the source module where the imports happen
        with patch("services.object_store.object_store_available", return_value=True), \
             patch("services.object_store.get_object_store", return_value=local_store), \
             patch("services.object_store._store", local_store):
            entries = wrapper._read_entries_from_object_store(SCAN_ID)

        assert entries is not None
        assert len(entries) == 3

    def test_object_store_cache_is_immutable(self, wrapper, local_store):
        """Entries from object store should be cached as immutable."""
        jsonl = _make_jsonl(_sample_entries())
        key = f"{SCAN_ID}/garak.{SCAN_ID}.report.jsonl"
        local_store.put(key, jsonl.encode("utf-8"))

        import services.object_store as mod
        old_store = mod._store
        try:
            mod._store = local_store
            entries = wrapper._get_report_entries(SCAN_ID)
        finally:
            mod._store = old_store

        assert entries is not None
        assert SCAN_ID in wrapper._report_cache
        assert wrapper._report_cache[SCAN_ID].get("immutable") is True

    def test_falls_back_to_local_file(self, wrapper, tmp_path):
        """If object store has nothing, falls back to local filesystem."""
        reports_dir = tmp_path / "reports"
        report_file = reports_dir / f"garak.{SCAN_ID}.report.jsonl"
        report_file.write_text(_make_jsonl(_sample_entries()))

        # Object store returns None — set _store to None so object_store_available is False
        import services.object_store as mod
        old_store = mod._store
        try:
            mod._store = None
            entries = wrapper._get_report_entries(SCAN_ID)
        finally:
            mod._store = old_store

        assert entries is not None
        assert len(entries) == 3

    def test_object_store_unavailable_falls_to_local(self, wrapper, tmp_path):
        """If object store is not initialized, read from local."""
        reports_dir = tmp_path / "reports"
        report_file = reports_dir / f"garak.{SCAN_ID}.report.jsonl"
        report_file.write_text(_make_jsonl(_sample_entries()))

        import services.object_store as mod
        old_store = mod._store
        try:
            mod._store = None
            entries = wrapper._get_report_entries(SCAN_ID)
        finally:
            mod._store = old_store

        assert entries is not None
        assert len(entries) == 3


# ---------------------------------------------------------------------------
# Materialized probe stats
# ---------------------------------------------------------------------------

class TestMaterializedProbeStats:

    @pytest.fixture
    def wrapper(self, tmp_path):
        from services.garak_wrapper import GarakWrapper
        reports_dir = tmp_path / "reports"
        reports_dir.mkdir()

        # Write sample JSONL
        report_file = reports_dir / f"garak.{SCAN_ID}.report.jsonl"
        report_file.write_text(_make_jsonl(_sample_entries()))

        with patch("services.garak_wrapper.settings") as mock_settings:
            mock_settings.garak_service_url = "http://localhost:9090"
            mock_settings.garak_reports_path = reports_dir
            w = GarakWrapper(cache_ttl=2)
        return w

    def test_compute_probe_stats(self, wrapper):
        stats = wrapper._compute_probe_stats(SCAN_ID)
        assert stats is not None
        assert "dan" in stats
        assert stats["dan"]["passed"] == 1
        assert stats["dan"]["failed"] == 1

    def test_compute_probe_stats_missing_scan(self, wrapper):
        stats = wrapper._compute_probe_stats("nonexistent")
        assert stats is None

    def test_get_materialized_computes_when_no_db(self, wrapper):
        """If DB is not available, compute from JSONL."""
        with patch("services.garak_wrapper._db_available", return_value=False):
            stats = wrapper._get_materialized_probe_stats(SCAN_ID)

        assert stats is not None
        assert stats["dan"]["passed"] == 1
        assert stats["dan"]["failed"] == 1

    def test_get_materialized_reads_from_db_when_available(self):
        """If DB has cached stats, return them without parsing JSONL."""
        from services.garak_wrapper import GarakWrapper

        cached_stats = {"dan": {"passed": 99, "failed": 0}}

        with patch("services.garak_wrapper.settings") as mock_settings, \
             patch("services.garak_wrapper._db_available", return_value=True):
            mock_settings.garak_service_url = "http://localhost:9090"
            mock_settings.garak_reports_path = Path("/tmp/test")
            w = GarakWrapper()

            # Mock the DB query
            mock_session = MagicMock()
            mock_row = (json.dumps(cached_stats),)
            mock_session.query.return_value.filter_by.return_value.first.return_value = mock_row

            from database import session as sess_mod
            with patch.object(sess_mod, "get_db") as mock_get_db:
                mock_get_db.return_value.__enter__ = MagicMock(return_value=mock_session)
                mock_get_db.return_value.__exit__ = MagicMock(return_value=False)

                stats = w._get_materialized_probe_stats(SCAN_ID)

        assert stats == cached_stats


# ---------------------------------------------------------------------------
# _update_scan_from_event: report_keys handling
# ---------------------------------------------------------------------------

class TestReportKeysFromEvent:

    @pytest.fixture
    def wrapper(self, tmp_path):
        from services.garak_wrapper import GarakWrapper
        with patch("services.garak_wrapper.settings") as mock_settings:
            mock_settings.garak_service_url = "http://localhost:9090"
            mock_settings.garak_reports_path = tmp_path
            w = GarakWrapper()
        return w

    def test_complete_event_stores_report_keys(self, wrapper):
        scan_id = "rk-test"
        wrapper.active_scans[scan_id] = {
            "scan_id": scan_id,
            "status": "running",
            "passed": 5,
            "failed": 2,
            "progress": 90.0,
        }

        with patch.object(wrapper, "_sync_scan_to_db"):
            wrapper._update_scan_from_event(scan_id, {
                "event_type": "complete",
                "passed": 5,
                "failed": 2,
                "report_keys": {
                    "jsonl": f"{scan_id}/garak.{scan_id}.report.jsonl",
                    "html": f"{scan_id}/garak.{scan_id}.report.html",
                },
            })

        info = wrapper.active_scans[scan_id]
        assert info["report_key"] == f"{scan_id}/garak.{scan_id}.report.jsonl"
        assert info["html_report_key"] == f"{scan_id}/garak.{scan_id}.report.html"

    def test_complete_event_without_report_keys(self, wrapper):
        scan_id = "no-rk"
        wrapper.active_scans[scan_id] = {
            "scan_id": scan_id,
            "status": "running",
            "passed": 0,
            "failed": 0,
            "progress": 50.0,
        }

        with patch.object(wrapper, "_sync_scan_to_db"):
            wrapper._update_scan_from_event(scan_id, {
                "event_type": "complete",
                "passed": 1,
                "failed": 0,
            })

        info = wrapper.active_scans[scan_id]
        assert "report_key" not in info
        assert "html_report_key" not in info


# ---------------------------------------------------------------------------
# delete_scan: object store cleanup
# ---------------------------------------------------------------------------

class TestDeleteScanObjectStore:

    @pytest.fixture
    def wrapper(self, tmp_path):
        from services.garak_wrapper import GarakWrapper
        reports_dir = tmp_path / "reports"
        reports_dir.mkdir()

        with patch("services.garak_wrapper.settings") as mock_settings:
            mock_settings.garak_service_url = "http://localhost:9090"
            mock_settings.garak_reports_path = reports_dir
            w = GarakWrapper()
        return w

    def test_delete_removes_from_object_store(self, wrapper):
        scan_id = "del-test"
        mock_store = MagicMock()
        mock_store.list_keys.return_value = [
            f"{scan_id}/garak.{scan_id}.report.jsonl",
            f"{scan_id}/garak.{scan_id}.report.html",
        ]

        import services.object_store as mod
        old_store = mod._store
        try:
            mod._store = mock_store
            with patch("services.garak_wrapper._db_available", return_value=False):
                wrapper.delete_scan(scan_id)
        finally:
            mod._store = old_store

        assert mock_store.list_keys.called
        assert mock_store.delete.call_count == 2

    def test_delete_handles_store_error_gracefully(self, wrapper):
        scan_id = "del-err"

        import services.object_store as mod
        old_store = mod._store
        try:
            # Set _store to a mock that raises on list_keys
            bad_store = MagicMock()
            bad_store.list_keys.side_effect = Exception("store down")
            mod._store = bad_store

            with patch("services.garak_wrapper._db_available", return_value=False):
                result = wrapper.delete_scan(scan_id)
        finally:
            mod._store = old_store

        assert result is True
