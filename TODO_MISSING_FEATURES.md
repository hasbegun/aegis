# Aegis - Missing Features & Improvements

A comprehensive list of missing features organized from easy to hard.

---

## Quick Stats
- **Easy (1-2 hours)**: 20 items (20 completed)
- **Medium (2-8 hours)**: 25 items (24 completed)
- **Hard (1-3 days)**: 16 items (3 completed)
- **Very Hard (1+ week)**: 10 items
- **Architecture**: 1 major item (completed)

---

## COMPLETED - Major Architecture

### Multi-Container Architecture (2026-02)
Decoupled garak from the backend into its own container with a thin REST/SSE API. This was a multi-day effort spanning the entire stack.

**What was done:**
- Created garak service (`aegis-garak`) running on port 9090 with FastAPI + SSE
- Rewrote backend `garak_wrapper.py` from subprocess manager to HTTP/SSE client
- Built progress streaming chain: garak stdout → Garak Service (parse+SSE) → Backend (SSE client) → Frontend (WebSocket)
- Created `Dockerfile.garak` (Python 3.11 + Rust + garak + thin API)
- Simplified `Dockerfile` (removed garak/Rust, image much smaller)
- Updated docker-compose for multi-service setup (dev, prod overlays)
- Implemented Ollama host injection via `--generator_options` to solve container networking
- Added scan failure diagnostics (last 20 lines of output on crash)
- Fixed error reporting chain (3 bugs in WebSocket/progress parser)

**Files created:** `services/garak_service/{app.py, scan_manager.py, progress_parser.py, requirements.txt}`, `Dockerfile.garak`, `docker-compose.prod.yml`, `docs/ARCHITECTURE.md`
**Files rewritten:** `services/garak_wrapper.py`, `Dockerfile`, `docker-compose.yml`, `docker-compose.dev.yml`, `Makefile`
**Files fixed:** `api/routes/scan.py`, `frontend/lib/services/websocket_service.dart`

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for full details.

### M18 — Scan Statistics Endpoint (2026-02-11)
Added `GET /api/v1/scan/statistics?days=30` for aggregate analytics across all scans: scan counts by status, total/average/min/max pass rates, daily trend data (configurable window), top 10 failing probe categories, and per-target breakdowns. Iterates all scan reports, aggregates JSONL attempt data for probe failure stats. 18 tests.

**Files created:** `tests/test_scan_statistics.py`
**Files modified:** `services/garak_wrapper.py` (added `get_scan_statistics()`), `api/routes/scan.py` (new route), `models/schemas.py` (5 new models)

### M19 — Config Save/Load Endpoints (2026-02-11)
Added full CRUD for user config templates, stored as JSON files on disk alongside garak reports. Templates are separate from built-in presets (fast/default/full/owasp), which remain read-only. Name validation prevents conflicts with reserved preset names. Endpoints: `POST /config/templates` (create), `GET /config/templates` (list), `GET /config/templates/{name}` (get), `PUT /config/templates/{name}` (update), `DELETE /config/templates/{name}` (delete). 45 tests.

**Files created:** `services/config_template_store.py`, `tests/test_config_templates.py`
**Files modified:** `api/routes/config.py` (5 new endpoints), `models/schemas.py` (3 new models)

### M20 — Enforce Max Concurrent Scans Limit (2026-02-11)
Enforces the existing `max_concurrent_scans` setting (default 5) that was previously defined but never checked. `start_scan()` now counts PENDING and RUNNING scans and raises `MaxConcurrentScansError` if at or over the limit. The scan route catches this and returns HTTP 429 (Too Many Requests) with a descriptive message including current count and limit. Completed/failed/cancelled scans don't count against the limit. 18 tests.

**Files created:** `tests/test_concurrent_scans.py`
**Files modified:** `services/garak_wrapper.py` (added `MaxConcurrentScansError`, `_count_running_scans()`), `api/routes/scan.py` (429 handler)

### M21-M24 — Advanced Garak CLI Flags (2026-02-11)
Exposed four additional garak CLI flags through the scan config schema and command builder:
- **M21** `--config_file`: Load scan configuration from a YAML/JSON file (`--config` in CLI)
- **M22** `--report_threshold`: Only report results above a threshold (0.0-1.0)
- **M23** `--hit_rate`: Stop scanning a probe after reaching a vulnerability hit rate (0.0-1.0)
- **M24** `--collect_timing`: Collect timing metrics for each probe (boolean flag)

Each flag has schema validation (type, range), serialization roundtrip, and CLI command builder tests. 21 new tests (44 total in `test_cli_flags.py`).

**Files modified:** `models/schemas.py` (2 new fields), `services/garak_service/scan_manager.py` (2 new CLI mappings), `tests/test_cli_flags.py` (21 new tests)

---

## EASY (1-2 hours each)

### UI Polish
- [x] **E1.** Add language selector dropdown in Settings with persistence (completed 2026-01-15)
- [x] **E2.** Add "unsaved changes" warning dialog when navigating away from config screens (completed 2026-01-15)
- [x] **E3.** Add character count indicators for text fields (system prompt, report prefix) (completed 2026-01-15)
- [x] **E4.** Add keyboard shortcut hints/tooltips throughout UI (completed 2026-01-15)
- [x] **E5.** Add recent scans shortcut on home screen (last 3-5 scans) (completed 2026-01-17)
- [x] **E6.** Add empty state illustrations for scan history, results lists (completed 2026-01-17)

### Garak CLI Flags
- [x] **E7.** Expose `--output_dir` - Custom output directory selection (completed 2026-01-17)
- [x] **E8.** Expose `--no_report` - Option to skip report generation (completed 2026-01-17)
- [x] **E9.** Expose `--continue_on_error` - Skip failed probes toggle (completed 2026-01-17)
- [x] **E10.** Expose `--exclude_probes` - Text field to exclude specific probes (completed 2026-01-17)
- [x] **E11.** Expose `--exclude_detectors` - Text field to exclude specific detectors (completed 2026-01-17)
- [x] **E12.** Expose `--timeout_per_probe` - Timeout slider for probes (completed 2026-01-17)

### Backend Quick Fixes
- [x] **E13.** Add response compression (gzip) middleware (completed 2026-01-17)
- [x] **E14.** Add request logging middleware with timing (completed 2026-01-17)
- [x] **E15.** Add health check endpoint (`/health`) (already exists)
- [x] **E16.** Add version endpoint (`/version`) (completed 2026-01-17)
- [x] **E17.** Cache probe/detector lists (5 min TTL like Ollama) (completed 2026-01-17)
- [x] **E18.** Add ETag headers for cacheable responses (completed 2026-01-17)

### Documentation
- [x] **E19.** Add keyboard shortcuts reference to README (completed 2026-01-17)
- [x] **E20.** Create API error codes reference document (completed 2026-01-17)

---

## MEDIUM (2-8 hours each)

### UI Features
- [x] **M1.** Add skeleton loaders for data-heavy screens (results, history) (completed 2026-01-17)
- [x] **M2.** Add offline mode detection with user notification (completed 2026-01-17)
- [x] **M3.** Add scan history search (by name, date, status) (completed 2026-01-17)
- [x] **M4.** Add scan history filters (date range, vulnerability type, status) (completed 2026-01-17)
- [x] **M5.** Add bulk delete for scan history (completed 2026-01-17)
- [x] **M6.** Add bulk export for multiple scan results (completed 2026-01-17)
- [x] **M7.** Add scan comparison view (side-by-side two scans) (completed 2026-01-17)
- [x] **M8.** Add probe-level vulnerability breakdown chart (completed 2026-01-17)
- [x] **M9.** Add vulnerability severity heatmap visualization (completed 2026-01-17)
- [x] **M10.** Add breadcrumb navigation for deep screens (completed 2026-01-17)
- [x] **M11.** Real-time API key validation before scan starts (completed 2026-01-21)
- [x] **M12.** Add progress ETAs for running scans (completed 2026-01-21)

### Backend Features
- [x] **M13.** Add pagination for history and results endpoints (completed 2026-01-21)
- [x] **M14.** Add date range query params for history endpoint (completed 2026-02-08)
- [x] **M15.** Add scan result caching layer (completed 2026-02-11)
- [x] **M16.** Add structured JSON logging (completed 2026-02-11)
- [x] **M17.** Add log rotation configuration (completed 2026-02-11)
- [x] **M18.** Add scan statistics endpoint (pass rates, trends) (completed 2026-02-11)
- [x] **M19.** Add config save/load endpoints (user templates) (completed 2026-02-11)
- [x] **M20.** Enforce `max_concurrent_scans` limit with queue (completed 2026-02-11)

### Garak CLI Flags
- [x] **M21.** Expose `--config_file` - Load config from YAML/JSON file (completed 2026-02-11)
- [x] **M22.** Expose `--report_threshold` - Only report above threshold (completed 2026-02-11)
- [x] **M23.** Expose `--hit_rate` - Stop after N vulnerabilities (completed 2026-02-11)
- [x] **M24.** Expose `--collect_timing` - Timing metrics per probe (completed 2026-02-11)

### Testing
- [ ] **M25.** Add widget tests for main screens (home, config, results) — *only 1 basic smoke test exists*

---

## HARD (1-3 days each)

### Major Features
- [ ] **H1.** Add SQLite/PostgreSQL database backend for persistence
- [ ] **H2.** Add scan scheduling/recurring scans (cron-style)
- [ ] **H3.** Add webhook support for scan events (start, complete, fail)
- [x] **H4.** Add desktop notifications for scan completion (completed) — *ScanNotificationService with iOS/macOS/Android support*
- [ ] **H5.** Add email notifications (requires SMTP config)
- [ ] **H6.** Complete workflow viewer integration (graph visualization)
- [ ] **H7.** Add mobile-responsive UI adaptations
- [x] **H8.** Add result streaming (incremental updates during scan) (completed 2026-02) — *WebSocket streams progress, probe, pass/fail counts in real-time*
- [ ] **H16.** Per-probe test details with security context (see plan below)

### Backend Infrastructure
- [ ] **H9.** Add API rate limiting per IP/user
- [x] ~~**H10.** Add async task queue (Celery/RQ) for background scans~~ — *Superseded by multi-container architecture: garak service handles scans as async subprocesses*
- [ ] **H11.** Add metrics collection endpoint (Prometheus format)
- [ ] **H12.** Add error tracking integration (Sentry)

### Testing & CI/CD
- [ ] **H13.** Set up CI/CD pipeline (GitHub Actions)
- [ ] **H14.** Add E2E tests for full scan workflow
- [ ] **H15.** Add API contract/schema validation tests

---

## VERY HARD (1+ week each)

### Security (Critical)
- [ ] **VH1.** Add API authentication (JWT/API key)
- [ ] **VH2.** Add user management & RBAC
- [ ] **VH3.** Add audit logging for compliance
- [ ] **VH4.** Add HTTPS/TLS enforcement with certificate management

### Major Infrastructure
- [ ] **VH5.** Add horizontal scaling support (load balancing)
- [ ] **VH6.** Add batch scan endpoint (multiple targets)
- [ ] **VH7.** Build mobile app version (iOS/Android)
- [ ] **VH8.** Build web version deployment

### Analytics & Reporting
- [ ] **VH9.** Add scan analytics dashboard (trends, comparisons)
- [ ] **VH10.** Add report templates with customization

---

## By Category

### Frontend (UI/UX)
| ID | Feature | Difficulty | Status |
|----|---------|------------|--------|
| E1-E6 | UI Polish items | Easy | All done |
| M1-M12 | UI Feature items | Medium | All done |
| H4 | Desktop notifications | Hard | Done |
| H6-H7 | Major UI features | Hard | Open |
| H16 | Probe details + security context | Hard | Planned |
| VH7-VH8 | Platform expansion | Very Hard | Open |

### Backend (API/Services)
| ID | Feature | Difficulty | Status |
|----|---------|------------|--------|
| E13-E18 | Quick backend fixes | Easy | All done |
| M13-M20 | Backend features | Medium | All done |
| H8-H10 | Streaming & async | Hard | Done (arch) |
| H9, H11-H12 | Infrastructure | Hard | Open |
| VH1-VH6 | Security & scaling | Very Hard | Open |

### Garak Integration
| ID | Feature | Difficulty | Status |
|----|---------|------------|--------|
| E7-E12 | Basic CLI flags | Easy | All done |
| M21-M24 | Advanced CLI flags | Medium | All done |

### Testing & Documentation
| ID | Feature | Difficulty | Status |
|----|---------|------------|--------|
| E19-E20 | Documentation | Easy | All done |
| M25 | Widget tests | Medium | Open |
| H13-H15 | CI/CD & E2E tests | Hard | Open |

### Architecture
| ID | Feature | Difficulty | Status |
|----|---------|------------|--------|
| — | Multi-container (garak service) | Major | Done (2026-02) |

---

## Priority Recommendations

### For Production Readiness (Do First)
1. **VH1** - API Authentication (security critical)
2. **H1** - Database backend (data persistence)
3. **H9** - Rate limiting (DOS protection)
4. **M16-M17** - Structured logging & rotation
5. **H13** - CI/CD pipeline

### For Better UX (High Impact, Quick Wins)
1. ~~**M14** - Date range query params~~ (done)
2. ~~**M18** - Scan statistics endpoint~~ (done)
3. ~~**M19** - Config templates~~ (done)
4. ~~**M20** - Enforce concurrent scan limit~~ (done)

### For Power Users
1. ~~**M21** - Config file loading~~ (done)
2. **H2** - Scheduled scans
3. ~~**M22-M24** - Advanced CLI flags~~ (done)

---

## H16 Plan: Per-Probe Test Details with Security Context

### Problem
Scan results show only "50% pass rate, 29 passed, 22 failed" — no way to see which probes failed, what the prompts/responses were, or what the security implications are. The JSONL report files have all this data but it's not exposed.

### Solution Overview
```
JSONL Report → Backend parses + enriches with security knowledge → New API endpoints
Frontend adds "Probes" tab → probe list view → drill-down to individual attempts
```

### Backend (3 steps)

**Step 1: Feed digest data to existing Charts tab**
- Modify `_parse_report_file()` in `garak_wrapper.py` to extract the `digest` entry from JSONL
- Include it in `get_scan_results()` response — this immediately enables the existing `_buildProbeBreakdownChart()` and `_buildSeverityHeatmap()` in the Charts tab

**Step 2: Create probe knowledge base**
- New file `backend/services/probe_knowledge.py`
- Python dict mapping ~20 probe categories → security metadata:
  - category name, severity (critical/high/medium/low), description, risk explanation, mitigation advice, CWE IDs, OWASP LLM Top 10 refs
- Two-tier lookup: category-level + optional probe-level overrides
- Graceful fallback for unmapped probes

**Step 3: Two new API endpoints**
- `GET /scan/{id}/probes` — per-probe summary list (classname, pass/fail, pass_rate, goal, security metadata). Sorted worst-first. Paginated.
- `GET /scan/{id}/probes/{classname}/attempts` — individual test attempts (full prompt, all model outputs, detector results, triggers). Filter by status. Paginated.

### Frontend (3 steps)

**Step 4: Add "Probes" tab to results screen**
- 4th tab: Summary | Charts | **Probes** | Workflow
- ProbeListView: scrollable cards with probe name, category badge, severity color, pass/fail bar, goal text. Tap to drill in.

**Step 5: Probe detail screen**
- Security context card: "What is this vulnerability?", risk, severity, mitigation, CWE/OWASP refs
- Filter tabs: All | Failed | Passed
- Attempts list: expandable cards with prompt, model output, status, triggers

**Step 6: AttemptCard widget**
- Collapsed: preview text + status icon
- Expanded: full prompt, all outputs, detector info

### Files to Create
| File | Purpose |
|------|---------|
| `backend/services/probe_knowledge.py` | Static security knowledge base |
| `frontend/lib/screens/results/probe_list_view.dart` | Probe list tab |
| `frontend/lib/screens/results/probe_detail_screen.dart` | Probe drill-down |
| `frontend/lib/widgets/attempt_card.dart` | Expandable attempt card |

### Files to Modify
| File | Change |
|------|--------|
| `backend/services/garak_wrapper.py` | Add digest extraction, `get_probe_details()`, `get_probe_attempts()` |
| `backend/api/routes/scan.py` | Register 2 new endpoints |
| `backend/models/schemas.py` | Add Pydantic response models |
| `frontend/lib/services/api_service.dart` | Add 2 new API methods |
| `frontend/lib/screens/results/enhanced_results_screen.dart` | Add 4th tab |
| `frontend/lib/widgets/breadcrumb_nav.dart` | Add probe breadcrumb paths |

---

## Completed Features Reference

See `TODO_LOW_HANGING_FRUITS.md` for the 10 low-hanging-fruit features completed 2026-01-12:
1. Probe Tag Filtering (OWASP LLM Top 10)
2. Missing Generator Types (Groq, Mistral, Azure, Bedrock)
3. System Prompt Override
4. Config Export to JSON
5. Extended Detectors Toggle
6. Deprefix Option
7. Verbose Mode Toggle
8. Skip Unknown Plugins Toggle
9. Buff Options: Include Original Prompt
10. Increase Max Generations Limit

---

*Created: 2026-01-15*
*Last Updated: 2026-02-11*
