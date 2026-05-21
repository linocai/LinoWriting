# LinoI v1.0 Local State

## Goal

Ship LinoI v1.0 as a local-only production app: no cloud deployment, no accounts, no multi-device sync. The current authority file is `/Users/linotsai/Lino/LinoWriting/v1_final_plan.md`.

## Current Position

- Local backend runs at `http://127.0.0.1:7773` via LaunchAgent `top.linotsai.novelos.local7773`.
- Packaged app is `/Users/linotsai/Lino/LinoWriting/NovelOSMac/dist/LinoI.app`.
- App bundle name/display name is `LinoI`; bundle id is `com.lino.linoi`; icon resource is `LinoI.icns`.
- Active LLM provider is `default` (`deepseek-v4-pro`, timeout 180s). The previous `grok` provider had connection reset failures and is not active.
- Do not change API keys, delete/rebuild local data, tag a final release, or deploy to cloud without explicit user confirmation.

## Completed In This Slice

### Week 1 Backend Foundation

- Implemented the Week 1 backend scope from `v1_final_plan.md`: LLM Gateway retry/error hardening, structured schema validation retry, error envelope, agent run token normalization, Import/Prompt Expander/Extraction schemas, Bootstrap canon idempotency, KM visibility dict migration, and chapter workflow state machine.
- Added `NovelOSBackend/app/llm/errors.py` with typed retryable/non-retryable LLM errors and unified API envelope handling in `NovelOSBackend/app/errors.py` / `NovelOSBackend/app/main.py`.
- Added Alembic revision `20260520_0002_week1_km_visibility_dict.py`; real local DB is at Alembic head `20260520_0002`.
- KM API response is now dict-only `visibility`; legacy request-side `character_knowledge` is still accepted and normalized for short-term frontend compatibility.
- Backend service restarted and health check returned `{"status":"ok"}`.

### Week 2 Frontend Foundation

- Implemented the Week 2 frontend scope from `v1_final_plan.md`: store `loadIfNeeded` caching/inflight protection, KM `visibility` dict support, animation tokens, RootShell sizing/sidebar footer, Inspector 5 sections, Workspace naming, and KM pill/state cleanup.
- `KnowledgeMatrixEntry` now encodes request payloads with `visibility` only; legacy `character_knowledge` is still decoded inside the model for old fixtures or transitional payloads.
- KM store filtering, dynamic character columns, editing, save roundtrip, and mock data now use dict visibility.
- Swift API error parsing now understands the backend `{error:{kind,message,retryable}}` envelope.
- LLM test token usage now decodes mixed JSON values, including the Week 1 `model` string.

### Week 3 Five-Step Workflow Visual Refinement

- Implemented the Week 3 Chapter Studio scope from `v1_final_plan.md`: Step 1 responsive prompt layout, Step 2 TemplateCard prompt review, Step 3 draft review UX, and stronger Stepper done state.
- Step 1 now uses `ViewThatFits`: wide screens show a prompt card plus right-side guidance, narrow screens stack; mini notes show active cast, weak mention budget, and new-character policy from `safetySummary`.
- Step 2 now renders goal, must-happen, must-not-happen, whitelist, and narrative style as TemplateCards with row-level list editing and loading state on draft generation.
- Step 3 now uses a 15pt draft editor with added line spacing, a one-sentence feedback hint, and a `Revision Agent` running state via `ChapterWorkflowStore.isRevisionRunning`.
- Completed steps in the Chapter Studio stepper now show a green filled checkmark and stronger done background.

### Week 4 Streaming, Audit, And Flow Log

- Implemented Week 4 local scope from `v1_final_plan.md`: backend SSE draft generation, frontend streaming draft updates, real Agent run log, Admin agent-runs API, deterministic S0 Audit hardening, and S0 auto Revision capped at 2 attempts.
- Added `POST /api/chapters/{chapter_id}/draft/generate/stream` with `text/event-stream` JSON events: `delta`, `word_count`, `draft_id`, `tokens`, `done`, and `error`.
- `ChapterWorkflowStore.approveStructuredPromptAndGenerateDraft()` now prefers stream, updates Step 3 / Inspector word count progressively, and falls back to synchronous `/draft/generate` when streaming fails.
- `GET /api/admin/agent-runs?novel_id=&chapter_id=` returns full Agent IO fields plus computed `latency_ms`; chapter-scoped `agent-runs` remains available.
- 「本章流程日志」 now uses real `ChapterWorkflowStore.agentRuns`: summary strip, timeline, IO sheet, chapter version card, and raw JSON disclosure.

### Week 5 Base Files And Local Finish

- Canceled Command Palette for v1.0 per user instruction: `v1_final_plan.md` now marks it canceled, no `⌘K` registration was added, and Inspector no longer shows `⌘K`.
- BaseFiles now uses `TemplateCard` for World Bible and Character Cards. World Bible respects optional `sectionKey`; Character Cards split into basic info, stable traits, structured current state, dialogue style, relationships, and derived Know/Unknown chips from KM `visibility`.
- Swift `CharacterCard.currentState` is now structured `{physical, emotional, goal, summary}` with backward-compatible string/object decoding; encoding sends the structured dict.
- Writing Settings now includes a local data card with backend/backup paths, one-click backup, Finder access, and restore dry-run command display/copy. The app does not execute destructive restore.

### Post Week 5 Frontend State Fix

- Fixed a visible Chapter Studio regression reported from `/Users/linotsai/Desktop/截屏2026-05-21 15.03.11.png`: completed/canon-pending chapters could reopen at Step 5 while `canonPatch` and `structuredPrompt` were not reloaded, causing the main panel to say the Canon update was not ready while Inspector marked prior steps complete.
- `ChapterWorkflowStore` now reloads current chapter artifacts on switch/initial load: structured prompt, latest draft/audit, canon patch, and agent runs. Step 5 also attempts to load Canon Patch on entry if needed.
- Added Swift regression test `completedChapterReloadsCanonPatchAndPromptArtifacts`.
- Fixed the follow-up layout bug where workspace/Inspector panels could be clipped with no scroll when the window height was reduced. RootShell now constrains the detail `HStack` to the actual viewport height, and all workspace root `ScrollView`s explicitly fill the viewport with visible scroll indicators.

- Fixed live LLM errors so backend returns retryable 502 details and records failed `AgentRunModel` rows instead of silently stalling.
- Reduced Prompt Pipeline live calls: Intent Parser and Context Compiler are local deterministic steps; Prompt Expander remains the LLM structured prompt step.
- Fixed live Canon Patch flow:
  - Extraction Agent now uses the injected live gateway.
  - Real novels no longer receive `mock_data.CANON_PATCH`.
  - Approve-final runs extraction before patch creation.
  - Confirming a patch writes accepted items into Memory, Knowledge Matrix, World Bible, and character current state where matchable, plus edit history.
- Fixed production data risks:
  - Live draft IDs now include `chapter.id`, avoiding collisions across books.
  - Live audit reruns start from a clean summary instead of inheriting stale S0/S1/S2 issues.
  - Single-letter forbidden names no longer flag geometry phrases like `D点`.
- Added local scripts:
  - `NovelOSBackend/scripts/local_service.sh`
  - `NovelOSBackend/scripts/backup_local.sh`
  - `NovelOSBackend/scripts/restore_local.sh`
- Backup archives now exclude `.env`, API keys, owner tokens, and unredacted database URLs. Restore supports `LINOI_DRY_RUN_RESTORE=1`.
- Updated backend README and `v1.0上线步骤.md` with local service and backup/restore commands.

## Real Acceptance Sample

Novel: `novel_c9703207` / `骁扬的青春`

- Bootstrap status: `analyzed`
- Current canon version: `4`
- Chapters 1-3: imported and completed
- Chapter 4: completed, approved draft `novel_c9703207_chapter_004_draft_v3`, chars 4266, audit S0/S1/S2 = 0/0/0
- Chapter 5: completed, approved draft `novel_c9703207_chapter_005_draft_v1`, chars 5108, audit S0/S1/S2 = 0/0/0
- Chapter 6: completed, approved draft `novel_c9703207_chapter_006_draft_v1`, chars 3525, audit S0/S1/S2 = 0/0/0
- Base file counts after restart: World Bible 22, Character Cards 5, Memory 42, Knowledge Matrix 26
- A real failed Prompt Pipeline run for chapter 4 is recorded as `status=failed`, `payload.retryable=true`, then later workflow retry succeeded.

## Verification

- Week 1 backend: `cd NovelOSBackend && .venv/bin/python -m pytest` -> 24 passed.
- Week 1 migration: `cd NovelOSBackend && .venv/bin/python -m alembic upgrade head` -> passed.
- Week 1 migration rollback/forward: `cd NovelOSBackend && .venv/bin/python -m alembic downgrade -1 && .venv/bin/python -m alembic upgrade head` -> passed.
- Week 1 DB current: `cd NovelOSBackend && .venv/bin/python -m alembic current` -> `20260520_0002 (head)`.
- Week 1 KM smoke check: `/api/novels/novel_c9703207/knowledge-matrix` returned entries with dict `visibility` and no response-side `character_knowledge`.
- Week 2 Swift: `cd NovelOSMac && swift test` -> 26 passed.
- Week 2 package: `cd NovelOSMac && Scripts/package_app.sh` -> packaged `dist/LinoI.app`.
- Week 2 signature: `cd NovelOSMac && codesign --verify --deep --strict dist/LinoI.app` -> passed.
- Week 2 backend/KM smoke: health returned `{"status":"ok"}`; `novel_c9703207` KM returned 26 entries, dict `visibility`, no response-side `character_knowledge`.
- Week 3 Swift: `cd NovelOSMac && swift test` -> 28 passed.
- Week 3 package: `cd NovelOSMac && Scripts/package_app.sh` -> packaged `dist/LinoI.app`.
- Week 3 signature: `cd NovelOSMac && codesign --verify --deep --strict dist/LinoI.app` -> passed.
- Week 4/5 backend: `cd NovelOSBackend && .venv/bin/python -m pytest` -> 26 passed.
- Week 4/5 Swift: `cd NovelOSMac && swift test` -> 33 passed.
- Week 4/5 package: `cd NovelOSMac && Scripts/package_app.sh` -> packaged `dist/LinoI.app`.
- Week 4/5 signature: `cd NovelOSMac && codesign --verify --deep --strict dist/LinoI.app` -> passed.
- Week 4/5 backup: `cd NovelOSBackend && Scripts/backup_local.sh` -> `/Users/linotsai/Lino/LinoWriting/NovelOSBackend/backups/linoi-local-20260521-142145.tar.gz`.
- Week 4/5 restore dry run: `cd NovelOSBackend && LINOI_DRY_RUN_RESTORE=1 Scripts/restore_local.sh /Users/linotsai/Lino/LinoWriting/NovelOSBackend/backups/linoi-local-20260521-142145.tar.gz` -> OK.
- Post Week 5 frontend fix: `cd NovelOSMac && swift test` -> 34 passed.
- Post Week 5 frontend fix: `cd NovelOSMac && Scripts/package_app.sh && codesign --verify --deep --strict dist/LinoI.app` -> passed.
- Post Week 5 clipping fix: `cd NovelOSMac && swift test` -> 34 passed.
- Post Week 5 clipping fix: `cd NovelOSMac && Scripts/package_app.sh && codesign --verify --deep --strict dist/LinoI.app` -> passed.

- App launch: `open dist/LinoI.app` started process `dist/LinoI.app/Contents/MacOS/LinoI`.
- Persistence: backend restart preserved chapters 4-6, canon version 4, and base file counts.

## Known Risks And Next Actions

- Full destructive restore to the active local database was not executed because it replaces current data and requires separate explicit confirmation.
- Final release freeze, Git tag, credential rotation, and any cloud deployment remain blocked pending user confirmation.
- LLM latency is still high. The workflow is functional with timeout 180s, but provider/model choice may need later tuning.
- Week 1-5 construction is complete. Next useful action is v1.0 local final acceptance/freeze: run the packaged app against `novel_c9703207`, generate or inspect the current Chapter Studio flow, and prepare a release summary. Do not begin cloud, tag, destructive restore, credential rotation, or final release freeze without explicit user confirmation.
- First command to inspect on resume:

```bash
git status --short && curl -fsS http://127.0.0.1:7773/healthz
```
