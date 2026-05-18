# Phase 5 Audit

Date: 2026-05-18

## Scope

This audit compares the current SwiftUI mock app and API skeleton against:

- `novel_macos_frontend_prototype_v1.html`
- `novel_macos_frontend_codex_handbook_v1.md`
- `novel_ai_backend_plan_v1.md`

Phase 5 remains a frontend/debugging and packaging slice. It does not add a real backend, LLM agent runtime, database, DMG, notarization, or Apple Developer signing.

## Phase 1-4 Results

| Phase | Planned Scope | Current Result |
| --- | --- | --- |
| Phase 1 | macOS 14+ SwiftUI mock app, three-column shell, six workspaces, Chapter Studio five-step flow, Inspector safety/status only | Implemented. Default content shows `雨夜旧码头 / 第 4 章 / Canon v12`; left navigation has six workspaces; Chapter Studio has five steps only. |
| Phase 2 | Chapter Workflow API skeleton with Mock/Live switch via `NOVEL_OS_API_BASE_URL` | Implemented. Live endpoints use `/api/chapters/{chapterId}/...`; Mock remains default. UI actions stay on the five-step flow. |
| Phase 3 | Base Documents API skeleton while retaining local editing | Implemented for World Bible, Characters, and Memory. Phase 5 removed the undocumented live Character DELETE dependency. |
| Phase 4 | Knowledge Matrix API skeleton and endpoint tests | Implemented for GET/POST/PATCH/DELETE `/api/novels/{novelId}/knowledge-matrix...`; snake_case fixture tests pass. |
| Phase 5 | Debug export, chapter version list, planning audit, packaging scripts and `.app` output | Implemented in source; packaging script creates the local `.app` artifact under `dist/`. |

## Main Workflow Boundary

The main Chapter Studio workflow still has exactly five user-facing steps:

1. Submit chapter intent.
2. Review structured prompt.
3. Review draft and request revision if needed.
4. Approve final text.
5. Confirm Canon Patch and complete the chapter.

Context Pack, Agent Run history, audit details, and version history remain debug or inspector information. They are not approval steps and cannot unlock the main workflow.

## Forbidden Item Check

| Item | Result |
| --- | --- |
| Chat UI | Not present. |
| Scene Plan | Not present. |
| Context Pack approval step | Not present. Context Pack is read-only in Version & Debug. |
| Agent Plan / Revision Plan approval step | Not present. |
| Audit Report as required main-flow approval | Not present. Audit summaries only gate S0 safety and show diagnostics. |
| Relationship Graph | Not present. Relationships remain embedded in character cards. |
| Foreshadowing / suspense table | Not present. |
| Standalone Style Bible page | Not present. Style guidance remains in Base Documents / Writing Settings context. |

## Frontend and Backend API Alignment

### Chapter Workflow

Aligned with the planning docs:

- `POST /api/chapters/{chapterId}/user-prompt`
- `GET /api/chapters/{chapterId}/structured-prompt`
- `PATCH /api/chapters/{chapterId}/structured-prompt`
- `POST /api/chapters/{chapterId}/structured-prompt/approve`
- `POST /api/chapters/{chapterId}/draft/generate`
- `GET /api/chapters/{chapterId}/draft/latest`
- `POST /api/chapters/{chapterId}/draft/review`
- `POST /api/chapters/{chapterId}/approve-final-text`
- `GET /api/chapters/{chapterId}/canon-update-patch`
- `PATCH /api/chapters/{chapterId}/canon-update-patch`
- `POST /api/chapters/{chapterId}/canon-update-patch/confirm`

### Base Documents

Aligned with the planning docs after Phase 5:

- World Bible supports GET/POST/PATCH/DELETE.
- Character cards support GET/POST/PATCH.
- Memory supports GET/POST/PATCH/DELETE.

Phase 5 correction: `DELETE /api/novels/{novelId}/characters/{characterId}` was removed from Live API, Mock API, Store, UI, and tests because the backend plan does not define it.

### Knowledge Matrix

Aligned with the planning docs:

- `GET /api/novels/{novelId}/knowledge-matrix`
- `POST /api/novels/{novelId}/knowledge-matrix`
- `PATCH /api/novels/{novelId}/knowledge-matrix/{entryId}`
- `DELETE /api/novels/{novelId}/knowledge-matrix/{entryId}`

### Wire Format

Live DTO tests still verify snake_case decoding/encoding for Chapter Workflow, Base Documents, and Knowledge Matrix resources. Debug export also uses snake_case JSON keys, including `context_pack_json`, `agent_runs`, and `chapter_versions`.

## Phase 5 Debug Additions

- Version & Debug now exports a local JSON file through `NSSavePanel` with default name `NovelOSMac-DebugLog.json`.
- Export payload contains Context Pack JSON, Agent Run history, chapter versions, and current chapter state.
- Chapter version list shows draft, mock revision, and approved final candidate records.
- Context Pack stays read-only with text selection enabled.
- Agent Run history remains Debug Only and cannot trigger new agent execution.

## Residual Limits

- Runtime still defaults to Mock mode unless `NOVEL_OS_API_BASE_URL` is set.
- There is no real backend validation in this repository.
- There is no persistence for Base Documents or Knowledge Matrix beyond Mock in-memory clients.
- `.app` signing is ad-hoc only; DMG, notarization, and Developer ID signing are outside this phase.
