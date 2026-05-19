# NovelOSBackend

FastAPI + PostgreSQL backend for the NovelOS macOS app.

This phase is still deterministic and does not call a real LLM, but the mock behavior now runs behind replaceable Agent, LLM gateway, and workflow orchestration seams. The SwiftUI five-step chapter workflow remains API-compatible while the backend grows toward production.

Phase 2 adds a deterministic chapter-generation pipeline: submitting a chapter prompt now persists Intent Parser, Context Compiler, and Prompt Expander runs plus a Context Pack snapshot; draft generation persists a Writing Agent run.

Phase 3 adds deterministic draft review support: Writing and Revision output now produces Named Entity, Knowledge, and Continuity audit runs plus a persisted Audit Report. Draft approval is blocked with `409` when the latest draft has S0 audit issues.

Phase 4 adds Novel CRUD, first-three-chapter bootstrap import/analyze placeholders, Alembic migrations, enriched Agent Run trace fields, Audit Report pass/highest-severity fields, and Knowledge Matrix visibility storage.

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

## Migrations

Alembic is configured in `alembic.ini`.

```bash
alembic upgrade head
alembic downgrade base
```
