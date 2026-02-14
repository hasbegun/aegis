"""
Database package for Aegis backend.

Provides SQLite-backed persistence via SQLAlchemy for scan metadata,
config templates, and custom probe metadata.
"""
from database.session import get_db, init_db, DatabaseSession

__all__ = ["get_db", "init_db", "DatabaseSession"]
