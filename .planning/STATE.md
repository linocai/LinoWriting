# LinoI v1.0 Local State

## Goal

Ship LinoI v1.0 as a local-only production app: no cloud deployment, no accounts, no multi-device sync. The current authority file is `/Users/linotsai/Lino/LinoWriting/v1.0上线步骤.md`.

## Current Position

- Local backend runs at `http://127.0.0.1:7773` via LaunchAgent `top.linotsai.novelos.local7773`.
- Packaged app is `/Users/linotsai/Lino/LinoWriting/NovelOSMac/dist/LinoI.app`.
- App bundle name/display name is `LinoI`; bundle id is `com.lino.linoi`; icon resource is `LinoI.icns`.
- Active LLM provider is `default` (`deepseek-v4-pro`, timeout 180s). The previous `grok` provider had connection reset failures and is not active.
- Do not change API keys, delete/rebuild local data, tag a final release, or deploy to cloud without explicit user confirmation.

## Completed In This Slice

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

- Backend: `cd NovelOSBackend && .venv/bin/python -m pytest` -> 17 passed.
- Swift: `cd NovelOSMac && swift test` -> 23 passed.
- Package: `cd NovelOSMac && Scripts/package_app.sh` -> packaged `dist/LinoI.app`.
- Signature: `cd NovelOSMac && codesign --verify --deep --strict dist/LinoI.app` -> passed.
- App launch: `open dist/LinoI.app` started process `dist/LinoI.app/Contents/MacOS/LinoI`.
- Persistence: backend restart preserved chapters 4-6, canon version 4, and base file counts.
- Backup: created `/Users/linotsai/Lino/LinoWriting/NovelOSBackend/backups/linoi-local-20260520-161908.tar.gz`.
- Restore dry run: `LINOI_DRY_RUN_RESTORE=1 scripts/restore_local.sh ...` -> OK.

## Known Risks And Next Actions

- Full destructive restore to the active local database was not executed because it replaces current data and requires separate explicit confirmation.
- Final release freeze, Git tag, credential rotation, and any cloud deployment remain blocked pending user confirmation.
- LLM latency is still high. The workflow is functional with timeout 180s, but provider/model choice may need later tuning.
- First command to inspect on resume:

```bash
git status --short && curl -fsS http://127.0.0.1:7773/healthz
```
