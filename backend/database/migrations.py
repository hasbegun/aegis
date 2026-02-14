"""
Database migration helpers.

On first startup, backfills the scans table from existing JSONL report files
and the config_templates table from existing JSON template files.
"""
import json
import logging
from pathlib import Path
from datetime import datetime

from database.models import Scan, ConfigTemplateRow, CustomProbeRow, DBMeta
from database.session import get_db

logger = logging.getLogger(__name__)


def backfill_scans_from_reports(reports_dir: Path) -> int:
    """Parse existing JSONL report files and insert scan rows.

    Skips scans that already exist in the DB. Returns count of inserted rows.
    """
    if not reports_dir.exists():
        logger.info(f"Reports directory not found, skipping backfill: {reports_dir}")
        return 0

    report_files = list(reports_dir.glob("garak.*.report.jsonl"))
    if not report_files:
        return 0

    inserted = 0
    with get_db() as db:
        # Get existing scan IDs to avoid duplicates
        existing_ids = {row[0] for row in db.query(Scan.id).all()}

        for report_file in report_files:
            try:
                scan_id = report_file.stem.replace("garak.", "").replace(".report", "")
                if scan_id in existing_ids:
                    continue

                # Parse JSONL first entry for metadata
                entries = []
                with open(report_file, "r", encoding="utf-8") as f:
                    for line in f:
                        try:
                            entries.append(json.loads(line))
                        except json.JSONDecodeError:
                            continue

                if not entries:
                    continue

                first = entries[0]
                passed = 0
                failed = 0
                for entry in entries:
                    if entry.get("entry_type") == "attempt":
                        status_val = entry.get("status")
                        if status_val == 2:
                            passed += 1
                        elif status_val == 1:
                            failed += 1

                total = passed + failed
                pass_rate = (passed / total * 100.0) if total > 0 else None

                started_at = first.get("transient.starttime_iso", "")
                if not started_at:
                    try:
                        started_at = datetime.fromtimestamp(report_file.stat().st_mtime).isoformat()
                    except OSError:
                        started_at = ""

                html_path = report_file.parent / f"garak.{scan_id}.report.html"

                scan = Scan(
                    id=scan_id,
                    target_type=first.get("plugins.target_type", "unknown"),
                    target_name=first.get("plugins.target_name", "unknown"),
                    status="completed",
                    started_at=started_at,
                    completed_at=first.get("transient.endtime_iso", ""),
                    passed=passed,
                    failed=failed,
                    pass_rate=pass_rate,
                    report_path=str(report_file),
                    html_report_path=str(html_path) if html_path.exists() else None,
                    created_at=started_at,
                )
                db.add(scan)
                inserted += 1

            except Exception as e:
                logger.warning(f"Error backfilling scan from {report_file.name}: {e}")

        if inserted:
            db.commit()
            logger.info(f"Backfilled {inserted} scans from existing report files")

    return inserted


def backfill_templates(templates_dir: Path) -> int:
    """Import existing JSON template files into the DB.

    Skips templates that already exist in the DB. Returns count of inserted rows.
    """
    if not templates_dir.exists():
        return 0

    json_files = list(templates_dir.glob("*.json"))
    if not json_files:
        return 0

    inserted = 0
    with get_db() as db:
        existing_names = {row[0] for row in db.query(ConfigTemplateRow.name).all()}

        for path in json_files:
            try:
                data = json.loads(path.read_text(encoding="utf-8"))
                name = data.get("name", "")
                if not name or name in existing_names:
                    continue

                row = ConfigTemplateRow(
                    name=name,
                    description=data.get("description"),
                    config_json=json.dumps(data.get("config", {})),
                    created_at=data.get("created_at", datetime.now().isoformat()),
                    updated_at=data.get("updated_at", datetime.now().isoformat()),
                )
                db.add(row)
                existing_names.add(name)
                inserted += 1

            except Exception as e:
                logger.warning(f"Error backfilling template from {path.name}: {e}")

        if inserted:
            db.commit()
            logger.info(f"Backfilled {inserted} config templates from existing files")

    return inserted


def backfill_custom_probes(probes_dir: Path) -> int:
    """Import existing metadata.json entries into the DB.

    Skips probes that already exist in the DB. Returns count of inserted rows.
    """
    metadata_file = probes_dir / "metadata.json"
    if not metadata_file.exists():
        return 0

    try:
        metadata = json.loads(metadata_file.read_text(encoding="utf-8"))
    except (json.JSONDecodeError, OSError):
        return 0

    probes = metadata.get("probes", {})
    if not probes:
        return 0

    inserted = 0
    with get_db() as db:
        existing_names = {row[0] for row in db.query(CustomProbeRow.name).all()}

        for name, data in probes.items():
            if name in existing_names:
                continue
            try:
                row = CustomProbeRow(
                    name=name,
                    description=data.get("description"),
                    file_path=data.get("file_path", ""),
                    goal=data.get("goal"),
                    created_at=data.get("created_at", datetime.now().isoformat()),
                    updated_at=data.get("updated_at", datetime.now().isoformat()),
                )
                db.add(row)
                existing_names.add(name)
                inserted += 1
            except Exception as e:
                logger.warning(f"Error backfilling probe {name}: {e}")

        if inserted:
            db.commit()
            logger.info(f"Backfilled {inserted} custom probes from metadata.json")

    return inserted


def run_backfill_if_needed() -> None:
    """Run all backfill operations if the DB was just created (empty scans table)."""
    from config import settings

    with get_db() as db:
        # Check if backfill already ran
        marker = db.query(DBMeta).filter_by(key="backfill_completed").first()
        if marker:
            return

    # Run backfills
    reports_dir = settings.garak_reports_path
    templates_dir = reports_dir.parent / "config_templates"
    probes_dir = Path.home() / ".garak" / "custom_probes"

    scans = backfill_scans_from_reports(reports_dir)
    templates = backfill_templates(templates_dir)
    probes = backfill_custom_probes(probes_dir)

    # Mark backfill as complete
    with get_db() as db:
        db.add(DBMeta(key="backfill_completed", value=datetime.now().isoformat()))
        db.commit()

    logger.info(f"Backfill complete: {scans} scans, {templates} templates, {probes} probes")
