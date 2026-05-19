# NovelOS HZ Deployment State

## Goal

Run NovelOS locally while HZ cloud deployment is blocked, with the macOS app temporarily pointed at `http://127.0.0.1:7773`.

## Codebase Orientation

- Product shape: NovelOS is a macOS + backend "novel operating system", not a chat UI. The user-facing chapter workflow must stay at five actions: prompt input, structured prompt review, draft review/revision, final approval, and canon patch confirmation.
- Current roadmap phase: `roadmap.md` defines Phase A as the active deterministic mock runtime. Phase B swaps mock internals for real LLM agents; Phase C adds retrieval/canon services; Phase D adds production operations.
- Frontend: `NovelOSMac` is a Swift 6.3, macOS 14 SwiftUI app using Observation stores, async APIs, and a three-column shell. Main entry points are `NovelOSMac/Sources/NovelOSMac/NovelOSMac.swift`, `Views/RootShellView.swift`, `Views/ChapterStudio/*`, and stores in `NovelOSMacCore/Stores.swift`.
- Backend: `NovelOSBackend` is FastAPI + SQLAlchemy + Alembic. Current APIs cover novels, bootstrap import/analyze, five-step chapter workflow, base documents, knowledge matrix, admin LLM provider settings, owner-token protection, and OpenAI-compatible live gateway plumbing.
- API wiring: Swift `APIClient` implements all protocol APIs in `NovelOSMacCore/Networking/*`; backend route implementations live under `NovelOSBackend/app/routers/*`, with orchestration in `app/orchestrator.py` and persistence/workflow helpers in `app/services.py`.
- Important historical note: `audit_report_v1.md` is older than the latest backend commits. Treat it as historical context; current code already includes many items that report listed as missing.

## Verified Baseline

- Backend tests: `cd NovelOSBackend && .venv/bin/python -m pytest` => 14 passed.
- Swift tests: `cd NovelOSMac && swift test` => 22 passed.
- Local backend service: `curl -fsS http://127.0.0.1:7773/healthz` => `{"status":"ok"}`; LaunchAgent `top.linotsai.novelos.local7773` is running.
- Git state while orienting: `main` is ahead of `origin/main` by 5 commits, with no tracked working-tree changes.

## Latest Fix

- Fixed bootstrap analysis for newly imported books: `POST /api/novels/{novel_id}/bootstrap/analyze` now runs `ImportAgent` through the configured LLM gateway in live mode, stores generated World Bible sections, Character Cards, Memory facts, and Knowledge Matrix entries, and keeps a deterministic fallback for tests/mock mode.
- Updated Swift decoding so live backend JSON objects such as `current_state`, `dialogue_style`, and `allowed_narration` display correctly in the macOS app.
- Re-ran analysis for local book `novel_c9703207`; it now has World Bible, Character Cards, Memory, and Knowledge Matrix records.
- Repackaged `/Users/linotsai/Lino/LinoWriting/NovelOSMac/dist/NovelOSMac.app` after the decoding fix.
- Renamed the packaged macOS app to `LinoI`, changed its bundle id to `com.lino.linoi`, set the default package icon source to `/Users/linotsai/Pictures/GPT Image/rounded-i-appicon-v1.png`, and produced `/Users/linotsai/Lino/LinoWriting/NovelOSMac/dist/LinoI.app`.

## Completed

- Read `/Users/linotsai/HZ云使用手册.md`.
- Switched production domain references from `write.neluvee.top` to `write.linotsai.top`.
- Backend production config and app source were prepared locally.
- Local backend tests passed with `.venv/bin/pytest`: 13 passed.
- Local Swift tests passed after the domain switch: 18 passed.
- Repackaged macOS app: `/Users/linotsai/Lino/LinoWriting/NovelOSMac/dist/NovelOSMac.app`.
- Synced `NovelOSBackend` and the ignored production `.env` to HZ:
  - Remote app dir: `/home/deploy/novelos`
  - Remote env: `/home/deploy/novelos/deploy/.env`
- Switched macOS default backend URL to `http://127.0.0.1:7773`.
- Wrote the current macOS user default `com.lino.novelosmac NovelOSBackendURL` to `http://127.0.0.1:7773`.
- Started local backend as LaunchAgent `top.linotsai.novelos.local7773`.
- Verified local backend:
  - `GET http://127.0.0.1:7773/healthz`
  - `GET http://127.0.0.1:7773/api/novels`
- Repackaged macOS app after local URL switch.
- Added macOS book library support:
  - Sidebar can list/switch books from `GET /api/novels`.
  - Sidebar can create a new book via `POST /api/novels`.
  - Switching books reloads Chapter Studio, Base Files, and Knowledge Matrix for the selected novel.
- Corrected the new-book bootstrap workflow:
  - New books no longer jump straight into Chapter Studio.
  - Chapters List shows a first-three-chapters import panel when bootstrap is not ready.
  - Import calls `POST /api/novels/{novel_id}/bootstrap/import-first-three-chapters`.
  - Analyze calls `POST /api/novels/{novel_id}/bootstrap/analyze`.
  - After import/analyze, the app creates chapter 4 and switches to Chapter Studio.
- Swift tests passed after book library/bootstrap work: 21 tests.

## Current Blocker

- `docker compose -f docker-compose.prod.yml up -d --build` on HZ failed while pulling `postgres:16-alpine` from Docker Hub due to network timeout.
- After attempting `sudo systemctl restart docker`, SSH to `deploy@118.178.122.194` began timing out during banner exchange.
- Public homepage health (`https://linotsai.top/health`) still returned `ok`, so the host is at least partially reachable; SSH is the active blocker.
- This cloud blocker is parked for now; local service is the active route.

## Next Action

For local work, use:

```bash
curl -fsS http://127.0.0.1:7773/healthz
launchctl print gui/$(id -u)/top.linotsai.novelos.local7773
```

To stop the local service:

```bash
launchctl bootout gui/$(id -u) top.linotsai.novelos.local7773
```

When returning to cloud, first check when SSH recovers:

```bash
ssh -o ConnectTimeout=20 deploy@118.178.122.194 'hostname && uptime && systemctl is-active docker || true'
```

Then continue:

1. Restore Docker responsiveness.
2. Configure a usable image mirror or otherwise make Postgres/API image pulls reliable.
3. Run `/home/deploy/novelos/deploy/docker-compose.prod.yml`.
4. Install Nginx site for `write.linotsai.top`, issue/reuse the certificate, test, and reload.
5. Verify `https://write.linotsai.top/healthz` and token-protected API calls.

## Notes

- Do not print `.env` or owner token contents.
- Do not local ping the new domain; DNS was already configured by the user.
