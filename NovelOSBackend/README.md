# NovelOSBackend

FastAPI + PostgreSQL backend for the NovelOS macOS app.

This phase is still deterministic and does not call a real LLM, but the mock behavior now runs behind replaceable Agent, LLM gateway, and workflow orchestration interfaces. The SwiftUI five-step chapter workflow remains API-compatible while the backend grows toward production. The repo-level `roadmap.md` tracks Phase A mock runtime through Phase D production operations.

Phase 2 adds a deterministic chapter-generation pipeline: submitting a chapter prompt now persists Intent Parser, Context Compiler, and Prompt Expander runs plus a Context Pack snapshot; draft generation persists a Writing Agent run.

Phase 3 adds deterministic draft review support: Writing and Revision output now produces Named Entity, Knowledge, and Continuity audit runs plus a persisted Audit Report. Draft approval is blocked with `409` when the latest draft has S0 audit issues.

Phase 4 adds Novel CRUD, first-three-chapter bootstrap import/analyze placeholders with local import storage, Alembic migrations, enriched Agent Run trace fields, Audit Report pass/highest-severity fields, Knowledge Matrix visibility storage, structured prompt and canon patch tables, and canon edit history.

## Run With Docker Compose

```bash
cd NovelOSBackend
docker compose up --build
```

Then verify:

```bash
curl http://127.0.0.1:8000/healthz
```

Connect the macOS app:

```bash
NOVEL_OS_API_BASE_URL=http://127.0.0.1:8000 swift run --package-path ../NovelOSMac NovelOSMac
```

## Local Tests

```bash
cd NovelOSBackend
python3 -m venv .venv
. .venv/bin/activate
pip install -r requirements.txt
pytest
```

Tests use SQLite for speed and isolation; Docker Compose is the default Postgres runtime path.

## Local v1.0 Runtime

The local-first v1.0 target is tracked in the repo-level `v1.0上线步骤.md`.
For local use, run the API on `http://127.0.0.1:7773` and point `LinoI.app` at that address.
Cloud deployment, domain setup, and multi-user auth are intentionally outside the v1.0 gate.

Manage the local LaunchAgent:

```bash
cd NovelOSBackend
scripts/local_service.sh install
scripts/local_service.sh status
scripts/local_service.sh health
scripts/local_service.sh restart
```

## Local Backup And Restore

Create a local backup:

```bash
cd NovelOSBackend
scripts/backup_local.sh
```

Restore is intentionally protected because it replaces the active local database/import files:

```bash
cd NovelOSBackend
LINOI_DRY_RUN_RESTORE=1 scripts/restore_local.sh /path/to/linoi-local-YYYYmmdd-HHMMSS.tar.gz
LINOI_CONFIRM_RESTORE=1 scripts/restore_local.sh /path/to/linoi-local-YYYYmmdd-HHMMSS.tar.gz
```

Backups include the database dump/copy and imported chapter files. They intentionally do not include `.env`,
API keys, owner tokens, or unredacted database URLs.

## Implemented API

- Novel CRUD at `/api/novels`
- Bootstrap import/analyze/status at `/api/novels/{novel_id}/bootstrap/...`
- Chapter Workflow endpoints under `/api/chapters/{chapter_id}/...`
- Debuggable workflow artifacts at `/api/chapters/{chapter_id}/context-pack` and `/api/chapters/{chapter_id}/agent-runs`
- Latest draft audit report at `/api/chapters/{chapter_id}/audit/latest`
- World Bible, Characters, and Memory under `/api/novels/{novel_id}/...`
- Knowledge Matrix under `/api/novels/{novel_id}/knowledge-matrix`
- `GET /healthz`

Character cards intentionally do not expose DELETE, matching `novel_ai_backend_plan_v1.md`.
Once a character appears in approved canon, physical deletion is unsafe; later phases should retire/hide characters instead of deleting them.

## Migrations

Alembic is configured in `alembic.ini`.

```bash
alembic upgrade head
alembic downgrade base
```

Startup table creation is disabled by default. For one-off local bootstrapping, set:

```bash
NOVEL_OS_CREATE_TABLES_ON_STARTUP=true
NOVEL_OS_SEED_MODE=completed_mock
```

Use `NOVEL_OS_SEED_MODE=empty_bootstrap` to seed only an empty novel shell for bootstrap-flow testing. Runtime imports are written under `NOVEL_OS_IMPORT_STORAGE_DIR` or `data/imports`.

## CORS

Allowed origins are read from `NOVEL_OS_CORS_ALLOW_ORIGINS` as a comma-separated list. The default is restricted to local origins instead of `*`.

## OpenAI-Compatible LLM

Copy `.env.example` to `.env` and fill:

```bash
NOVEL_OS_LLM_MODE=live
OPENAI_COMPATIBLE_API_KEY=...
OPENAI_COMPATIBLE_BASE_URL=https://your-compatible-endpoint/v1
OPENAI_COMPATIBLE_MODEL=your-model
```

The backend uses `/chat/completions` and records `model`, `input_json`, `output_json`, and `token_usage` into `agent_runs`.

After starting the API, run a manual live smoke:

```bash
python scripts/live_smoke.py
```

The smoke creates a temporary novel, imports three sample chapters, creates chapter 4, runs structured prompt generation, draft generation, audit, final approval, and canon merge.
