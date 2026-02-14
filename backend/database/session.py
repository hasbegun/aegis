"""
Database session management.

Creates a SQLite database in the shared garak reports directory and provides
a session factory for use throughout the backend.
"""
import logging
from pathlib import Path
from contextlib import contextmanager

from sqlalchemy import create_engine, event, text
from sqlalchemy.orm import sessionmaker, Session

from database.models import Base, DBMeta

logger = logging.getLogger(__name__)

# Current schema version — bump when models change
SCHEMA_VERSION = "1"

# Module-level engine and session factory (initialized by init_db)
_engine = None
_SessionFactory = None


def _get_db_path() -> Path:
    """Determine the database file path.

    Stored inside garak_reports_path (the Docker shared volume at
    /data/garak_reports) so it persists across container restarts.
    """
    from config import settings
    db_dir = settings.garak_reports_path
    db_dir.mkdir(parents=True, exist_ok=True)
    return db_dir / "aegis.db"


def init_db(db_path: str | Path | None = None) -> None:
    """Initialize the database: create engine, enable WAL, create tables.

    Args:
        db_path: Optional override for the database file path.
                 If None, uses the default path from settings.
                 Use ":memory:" for in-memory testing.
    """
    global _engine, _SessionFactory

    if db_path is None:
        db_path = _get_db_path()

    db_url = f"sqlite:///{db_path}" if str(db_path) != ":memory:" else "sqlite:///:memory:"

    _engine = create_engine(
        db_url,
        echo=False,
        connect_args={"check_same_thread": False},
    )

    # Enable WAL mode for better concurrent read performance
    @event.listens_for(_engine, "connect")
    def _set_sqlite_pragma(dbapi_connection, connection_record):
        cursor = dbapi_connection.cursor()
        cursor.execute("PRAGMA journal_mode=WAL")
        cursor.execute("PRAGMA foreign_keys=ON")
        cursor.close()

    # Create all tables
    Base.metadata.create_all(_engine)

    _SessionFactory = sessionmaker(bind=_engine)

    # Store schema version
    with get_db() as db:
        existing = db.query(DBMeta).filter_by(key="schema_version").first()
        if not existing:
            db.add(DBMeta(key="schema_version", value=SCHEMA_VERSION))
            db.commit()
            logger.info(f"Database initialized at {db_path} (schema v{SCHEMA_VERSION})")
        else:
            logger.info(f"Database opened at {db_path} (schema v{existing.value})")


@contextmanager
def get_db():
    """Yield a SQLAlchemy session, auto-closing on exit.

    Usage:
        with get_db() as db:
            db.query(Scan).all()
    """
    if _SessionFactory is None:
        raise RuntimeError("Database not initialized. Call init_db() first.")
    session: Session = _SessionFactory()
    try:
        yield session
    finally:
        session.close()


class DatabaseSession:
    """Convenience wrapper for dependency-injection-friendly access."""

    @staticmethod
    def get():
        """Get a context-managed session."""
        return get_db()
