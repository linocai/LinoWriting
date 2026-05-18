# NovelOSBackend

FastAPI + PostgreSQL backend MVP for the NovelOS macOS app.

This phase is a persistent Mock API. It implements the REST surface already used by the SwiftUI frontend and keeps deterministic workflow behavior. It does not call a real LLM, run Agent orchestration, or implement auth.

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

- Chapter Workflow endpoints under `/api/chapters/{chapter_id}/...`
- World Bible, Characters, and Memory under `/api/novels/{novel_id}/...`
- Knowledge Matrix under `/api/novels/{novel_id}/knowledge-matrix`
- `GET /healthz`

Character cards intentionally do not expose DELETE, matching `novel_ai_backend_plan_v1.md`.
