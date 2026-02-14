"""
Tests for H1: Database backend for persistence.

Covers:
- Database initialization (in-memory and file-based)
- SQLAlchemy ORM models (Scan, ConfigTemplateRow, CustomProbeRow)
- Session management (get_db context manager)
- Schema version tracking (DBMeta)
- Backfill migrations (scans, templates, custom probes)
- DB-backed ConfigTemplateStore CRUD
- DB-backed CustomProbeService metadata
"""
import json
import os
import sys
import time
from datetime import datetime
from pathlib import Path
from unittest.mock import patch, MagicMock

import pytest

sys.path.insert(0, os.path.join(os.path.dirname(__file__), ".."))

from database.models import Base, Scan, ConfigTemplateRow, CustomProbeRow, DBMeta
from database.session import init_db, get_db, _SessionFactory, SCHEMA_VERSION


# ---------------------------------------------------------------------------
# Fixtures
# ---------------------------------------------------------------------------

@pytest.fixture(autouse=True)
def reset_db():
    """Reset the database module-level state between tests."""
    import database.session as sess
    old_engine = sess._engine
    old_factory = sess._SessionFactory
    yield
    sess._engine = old_engine
    sess._SessionFactory = old_factory


@pytest.fixture
def db():
    """Initialize an in-memory DB and yield a session context manager."""
    init_db(":memory:")
    return get_db


@pytest.fixture
def db_session(db):
    """Yield an actual session for direct DB manipulation."""
    with db() as session:
        yield session


# ---------------------------------------------------------------------------
# Database initialization
# ---------------------------------------------------------------------------

class TestDatabaseInit:

    def test_init_creates_tables(self, db):
        with db() as session:
            # Should be able to query all tables without error
            assert session.query(Scan).all() == []
            assert session.query(ConfigTemplateRow).all() == []
            assert session.query(CustomProbeRow).all() == []

    def test_init_sets_schema_version(self, db):
        with db() as session:
            meta = session.query(DBMeta).filter_by(key="schema_version").first()
            assert meta is not None
            assert meta.value == SCHEMA_VERSION

    def test_init_file_based(self, tmp_path):
        db_path = tmp_path / "test.db"
        init_db(db_path)
        assert db_path.exists()

    def test_get_db_raises_without_init(self):
        import database.session as sess
        sess._SessionFactory = None
        with pytest.raises(RuntimeError, match="not initialized"):
            with get_db() as _:
                pass


# ---------------------------------------------------------------------------
# Scan model
# ---------------------------------------------------------------------------

class TestScanModel:

    def test_create_scan(self, db_session):
        scan = Scan(
            id="test-001",
            target_type="ollama",
            target_name="llama3",
            status="pending",
            started_at="2025-01-01T00:00:00",
            created_at="2025-01-01T00:00:00",
        )
        db_session.add(scan)
        db_session.commit()

        result = db_session.query(Scan).filter_by(id="test-001").first()
        assert result is not None
        assert result.target_type == "ollama"
        assert result.target_name == "llama3"
        assert result.status == "pending"

    def test_scan_to_dict(self, db_session):
        scan = Scan(
            id="test-002",
            target_type="openai",
            target_name="gpt-4",
            status="completed",
            passed=10,
            failed=5,
            started_at="2025-01-01T00:00:00",
            completed_at="2025-01-01T00:05:00",
        )
        db_session.add(scan)
        db_session.commit()

        d = scan.to_dict()
        assert d["scan_id"] == "test-002"
        assert d["status"] == "completed"
        assert d["passed"] == 10
        assert d["failed"] == 5
        assert d["total_tests"] == 15
        assert d["progress"] == 100.0

    def test_scan_to_dict_defaults(self, db_session):
        scan = Scan(id="test-003", target_type="x", target_name="y", status="pending")
        db_session.add(scan)
        db_session.commit()

        d = scan.to_dict()
        assert d["passed"] == 0
        assert d["failed"] == 0
        assert d["total_tests"] == 0
        assert d["progress"] == 0.0

    def test_scan_unique_id(self, db_session):
        db_session.add(Scan(id="dup", target_type="a", target_name="b"))
        db_session.commit()

        from sqlalchemy.exc import IntegrityError
        db_session.add(Scan(id="dup", target_type="c", target_name="d"))
        with pytest.raises(IntegrityError):
            db_session.commit()

    def test_scan_query_by_status(self, db_session):
        db_session.add(Scan(id="s1", target_type="a", target_name="b", status="completed"))
        db_session.add(Scan(id="s2", target_type="a", target_name="b", status="failed"))
        db_session.add(Scan(id="s3", target_type="a", target_name="b", status="completed"))
        db_session.commit()

        completed = db_session.query(Scan).filter_by(status="completed").all()
        assert len(completed) == 2

    def test_scan_query_by_target(self, db_session):
        db_session.add(Scan(id="s1", target_type="ollama", target_name="llama3"))
        db_session.add(Scan(id="s2", target_type="openai", target_name="gpt-4"))
        db_session.add(Scan(id="s3", target_type="ollama", target_name="llama3"))
        db_session.commit()

        ollama = db_session.query(Scan).filter_by(
            target_type="ollama", target_name="llama3"
        ).all()
        assert len(ollama) == 2


# ---------------------------------------------------------------------------
# ConfigTemplateRow model
# ---------------------------------------------------------------------------

class TestConfigTemplateModel:

    def test_create_template(self, db_session):
        row = ConfigTemplateRow(
            name="test-tmpl",
            description="A test template",
            config_json='{"target_type": "ollama"}',
            created_at="2025-01-01T00:00:00",
            updated_at="2025-01-01T00:00:00",
        )
        db_session.add(row)
        db_session.commit()

        result = db_session.query(ConfigTemplateRow).filter_by(name="test-tmpl").first()
        assert result is not None
        assert result.description == "A test template"

    def test_template_to_dict(self, db_session):
        config = {"target_type": "openai", "probes": ["dan"]}
        row = ConfigTemplateRow(
            name="tmpl",
            description="desc",
            config_json=json.dumps(config),
            created_at="2025-01-01T00:00:00",
            updated_at="2025-01-01T00:00:00",
        )
        db_session.add(row)
        db_session.commit()

        d = row.to_dict()
        assert d["name"] == "tmpl"
        assert d["description"] == "desc"
        assert d["config"] == config
        assert "created_at" in d
        assert "updated_at" in d

    def test_template_unique_name(self, db_session):
        db_session.add(ConfigTemplateRow(
            name="dup", config_json="{}", created_at="", updated_at=""
        ))
        db_session.commit()

        from sqlalchemy.exc import IntegrityError
        db_session.add(ConfigTemplateRow(
            name="dup", config_json="{}", created_at="", updated_at=""
        ))
        with pytest.raises(IntegrityError):
            db_session.commit()


# ---------------------------------------------------------------------------
# CustomProbeRow model
# ---------------------------------------------------------------------------

class TestCustomProbeModel:

    def test_create_probe(self, db_session):
        row = CustomProbeRow(
            name="MyProbe",
            description="A custom probe",
            file_path="/path/to/probe.py",
            goal="Test for vulnerabilities",
            created_at="2025-01-01T00:00:00",
            updated_at="2025-01-01T00:00:00",
        )
        db_session.add(row)
        db_session.commit()

        result = db_session.query(CustomProbeRow).filter_by(name="MyProbe").first()
        assert result is not None
        assert result.file_path == "/path/to/probe.py"
        assert result.goal == "Test for vulnerabilities"

    def test_probe_to_dict(self, db_session):
        row = CustomProbeRow(
            name="Probe1",
            description="desc",
            file_path="/tmp/probe.py",
            goal="goal",
            created_at="2025-01-01T00:00:00",
            updated_at="2025-01-01T00:00:00",
        )
        db_session.add(row)
        db_session.commit()

        d = row.to_dict()
        assert d["name"] == "Probe1"
        assert d["description"] == "desc"
        assert d["file_path"] == "/tmp/probe.py"
        assert d["goal"] == "goal"

    def test_probe_unique_name(self, db_session):
        db_session.add(CustomProbeRow(
            name="dup", file_path="a.py", created_at="", updated_at=""
        ))
        db_session.commit()

        from sqlalchemy.exc import IntegrityError
        db_session.add(CustomProbeRow(
            name="dup", file_path="b.py", created_at="", updated_at=""
        ))
        with pytest.raises(IntegrityError):
            db_session.commit()


# ---------------------------------------------------------------------------
# DB-backed ConfigTemplateStore
# ---------------------------------------------------------------------------

SAMPLE_CONFIG = {
    "target_type": "ollama",
    "target_name": "llama3.2:3b",
    "probes": ["dan", "encoding"],
}


class TestDBConfigTemplateStore:
    """Test ConfigTemplateStore with an active in-memory DB."""

    @pytest.fixture
    def store(self, tmp_path, db):
        """Create a store with DB available."""
        from services.config_template_store import ConfigTemplateStore
        with patch("services.config_template_store.settings") as mock:
            mock.garak_reports_path = tmp_path / "reports"
            mock.garak_reports_path.mkdir()
            s = ConfigTemplateStore(templates_dir=tmp_path / "templates")
        return s

    def test_save_and_get(self, store):
        t = store.save_template("test", SAMPLE_CONFIG, description="desc")
        assert t["name"] == "test"
        assert t["config"] == SAMPLE_CONFIG

        got = store.get_template("test")
        assert got is not None
        assert got["name"] == "test"

    def test_list(self, store):
        store.save_template("one", SAMPLE_CONFIG)
        time.sleep(0.01)
        store.save_template("two", SAMPLE_CONFIG)

        templates = store.list_templates()
        assert len(templates) == 2
        assert templates[0]["name"] == "two"  # most recent first

    def test_update(self, store):
        store.save_template("test", SAMPLE_CONFIG, description="old")
        t = store.update_template("test", description="new")
        assert t["description"] == "new"
        assert t["config"] == SAMPLE_CONFIG

    def test_delete(self, store):
        store.save_template("test", SAMPLE_CONFIG)
        assert store.delete_template("test") is True
        assert store.get_template("test") is None

    def test_duplicate_rejected(self, store):
        store.save_template("test", SAMPLE_CONFIG)
        with pytest.raises(ValueError, match="already exists"):
            store.save_template("test", SAMPLE_CONFIG)

    def test_update_nonexistent_raises(self, store):
        with pytest.raises(ValueError, match="not found"):
            store.update_template("ghost", config=SAMPLE_CONFIG)

    def test_delete_nonexistent(self, store):
        assert store.delete_template("ghost") is False

    def test_no_file_created_when_db_available(self, store):
        """When DB is active, no JSON file should be created on disk."""
        store.save_template("test", SAMPLE_CONFIG)
        assert not store._file_for("test").exists()


# ---------------------------------------------------------------------------
# Backfill migrations
# ---------------------------------------------------------------------------

class TestBackfillMigrations:

    def test_backfill_templates(self, db, tmp_path):
        """Backfill should import JSON template files into the DB."""
        from database.migrations import backfill_templates

        templates_dir = tmp_path / "config_templates"
        templates_dir.mkdir()
        tmpl = {
            "name": "my-tmpl",
            "description": "A template",
            "config": {"probes": ["dan"]},
            "created_at": "2025-01-01T00:00:00",
            "updated_at": "2025-01-01T00:00:00",
        }
        (templates_dir / "my_tmpl.json").write_text(json.dumps(tmpl))

        backfill_templates(templates_dir)

        with db() as session:
            rows = session.query(ConfigTemplateRow).all()
            assert len(rows) == 1
            assert rows[0].name == "my-tmpl"

    def test_backfill_custom_probes(self, db, tmp_path):
        """Backfill should import metadata.json entries into the DB."""
        from database.migrations import backfill_custom_probes

        probes_dir = tmp_path / "custom_probes"
        probes_dir.mkdir()
        metadata = {
            "probes": {
                "TestProbe": {
                    "name": "TestProbe",
                    "file_path": str(probes_dir / "test_probe.py"),
                    "description": "A test probe",
                    "created_at": "2025-01-01T00:00:00",
                    "updated_at": "2025-01-01T00:00:00",
                }
            }
        }
        (probes_dir / "metadata.json").write_text(json.dumps(metadata))

        backfill_custom_probes(probes_dir)

        with db() as session:
            rows = session.query(CustomProbeRow).all()
            assert len(rows) == 1
            assert rows[0].name == "TestProbe"

    def test_backfill_scans(self, db, tmp_path):
        """Backfill should import JSONL report files into the DB."""
        from database.migrations import backfill_scans_from_reports

        scan_id = "abc123"
        report = tmp_path / f"garak.{scan_id}.report.jsonl"
        entries = [
            {
                "entry_type": "config",
                "plugins.target_type": "ollama",
                "plugins.target_name": "llama3",
                "transient.starttime_iso": "2025-01-01T00:00:00",
                "transient.endtime_iso": "2025-01-01T00:05:00",
            },
            {"entry_type": "attempt", "status": 2, "probe_classname": "dan.Dan"},
            {"entry_type": "attempt", "status": 1, "probe_classname": "dan.Dan"},
        ]
        report.write_text("\n".join(json.dumps(e) for e in entries))

        backfill_scans_from_reports(tmp_path)

        with db() as session:
            rows = session.query(Scan).all()
            assert len(rows) == 1
            assert rows[0].id == scan_id
            assert rows[0].target_type == "ollama"
            assert rows[0].passed == 1
            assert rows[0].failed == 1

    def test_backfill_idempotent(self, db, tmp_path):
        """Running backfill twice should not create duplicates."""
        from database.migrations import backfill_templates

        templates_dir = tmp_path / "config_templates"
        templates_dir.mkdir()
        tmpl = {
            "name": "tmpl",
            "config": {},
            "created_at": "2025-01-01T00:00:00",
            "updated_at": "2025-01-01T00:00:00",
        }
        (templates_dir / "tmpl.json").write_text(json.dumps(tmpl))

        backfill_templates(templates_dir)
        backfill_templates(templates_dir)  # second run

        with db() as session:
            rows = session.query(ConfigTemplateRow).all()
            assert len(rows) == 1


# ---------------------------------------------------------------------------
# DBMeta version tracking
# ---------------------------------------------------------------------------

class TestDBMeta:

    def test_schema_version_stored(self, db):
        with db() as session:
            meta = session.query(DBMeta).filter_by(key="schema_version").first()
            assert meta is not None
            assert meta.value == SCHEMA_VERSION

    def test_custom_key_value(self, db):
        with db() as session:
            session.add(DBMeta(key="test_key", value="test_value"))
            session.commit()

        with db() as session:
            meta = session.query(DBMeta).filter_by(key="test_key").first()
            assert meta.value == "test_value"
