#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "Usage: $0 /path/to/linoi-local-YYYYmmdd-HHMMSS.tar.gz" >&2
  exit 2
fi

if [[ "${LINOI_CONFIRM_RESTORE:-}" != "1" && "${LINOI_DRY_RUN_RESTORE:-}" != "1" ]]; then
  cat >&2 <<'EOF'
Restore is destructive. It replaces the current local database/import files.

Re-run with:
  LINOI_CONFIRM_RESTORE=1 NovelOSBackend/scripts/restore_local.sh <backup.tar.gz>

For a non-destructive validation:
  LINOI_DRY_RUN_RESTORE=1 NovelOSBackend/scripts/restore_local.sh <backup.tar.gz>
EOF
  exit 3
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
ARCHIVE_PATH="$(cd "$(dirname "$1")" && pwd)/$(basename "$1")"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/linoi-restore.XXXXXX")"
STAMP="$(date +%Y%m%d-%H%M%S)"

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

if [[ ! -f "${ARCHIVE_PATH}" ]]; then
  echo "Backup archive not found: ${ARCHIVE_PATH}" >&2
  exit 1
fi

cd "${BACKEND_DIR}"
tar -C "${WORK_DIR}" -xzf "${ARCHIVE_PATH}"

if [[ ! -f "${WORK_DIR}/manifest.json" ]]; then
  echo "Invalid backup: manifest.json is missing." >&2
  exit 1
fi

MANIFEST_KIND="$("${BACKEND_DIR}/.venv/bin/python" -c 'import json,sys; print(json.load(open(sys.argv[1])).get("database_kind", ""))' "${WORK_DIR}/manifest.json")"
if [[ "${MANIFEST_KIND}" == "sqlite" && ! -f "${WORK_DIR}/database.sqlite" ]]; then
  echo "Invalid SQLite backup: database.sqlite is missing." >&2
  exit 1
fi
if [[ "${MANIFEST_KIND}" == "postgres" && ! -f "${WORK_DIR}/database.sql" ]]; then
  echo "Invalid PostgreSQL backup: database.sql is missing." >&2
  exit 1
fi
if [[ "${LINOI_DRY_RUN_RESTORE:-}" == "1" ]]; then
  echo "Restore dry run OK for ${ARCHIVE_PATH} (${MANIFEST_KIND})."
  exit 0
fi

CURRENT_JSON="$("${BACKEND_DIR}/.venv/bin/python" - <<'PY'
from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import urlparse

from app.config import load_environment
from app.database import database_url
from app.services import import_storage_dir

load_environment()
url = database_url()
parsed = urlparse(url)
sqlite_path = None
if url.startswith("sqlite:///"):
    sqlite_path = str(Path(url.removeprefix("sqlite:///")).resolve())
elif url.startswith("sqlite://"):
    sqlite_path = str(Path(parsed.path).resolve())

print(json.dumps({
    "database_kind": "sqlite" if sqlite_path else "postgres",
    "sqlite_path": sqlite_path,
    "database_url": url,
    "import_storage_dir": str(import_storage_dir().resolve()),
}, ensure_ascii=False))
PY
)"

DATABASE_KIND="$(printf '%s' "${CURRENT_JSON}" | "${BACKEND_DIR}/.venv/bin/python" -c 'import json,sys; print(json.load(sys.stdin)["database_kind"])')"
SQLITE_PATH="$(printf '%s' "${CURRENT_JSON}" | "${BACKEND_DIR}/.venv/bin/python" -c 'import json,sys; print(json.load(sys.stdin).get("sqlite_path") or "")')"
DATABASE_URL_VALUE="$(printf '%s' "${CURRENT_JSON}" | "${BACKEND_DIR}/.venv/bin/python" -c 'import json,sys; print(json.load(sys.stdin)["database_url"])')"
PG_TOOL_URL="${DATABASE_URL_VALUE/postgresql+psycopg/postgresql}"
IMPORT_DIR="$(printf '%s' "${CURRENT_JSON}" | "${BACKEND_DIR}/.venv/bin/python" -c 'import json,sys; print(json.load(sys.stdin)["import_storage_dir"])')"

if [[ -d "${IMPORT_DIR}" ]]; then
  mv "${IMPORT_DIR}" "${IMPORT_DIR}.pre-restore-${STAMP}"
fi
if [[ -d "${WORK_DIR}/data/imports" ]]; then
  mkdir -p "$(dirname "${IMPORT_DIR}")"
  ditto "${WORK_DIR}/data/imports" "${IMPORT_DIR}"
fi

if [[ "${DATABASE_KIND}" == "sqlite" ]]; then
  if [[ ! -f "${WORK_DIR}/database.sqlite" ]]; then
    echo "Invalid SQLite backup: database.sqlite is missing." >&2
    exit 1
  fi
  mkdir -p "$(dirname "${SQLITE_PATH}")"
  if [[ -f "${SQLITE_PATH}" ]]; then
    cp "${SQLITE_PATH}" "${SQLITE_PATH}.pre-restore-${STAMP}"
  fi
  cp "${WORK_DIR}/database.sqlite" "${SQLITE_PATH}"
else
  if [[ ! -f "${WORK_DIR}/database.sql" ]]; then
    echo "Invalid PostgreSQL backup: database.sql is missing." >&2
    exit 1
  fi
  if ! command -v psql >/dev/null 2>&1; then
    echo "psql is required for PostgreSQL restore." >&2
    exit 1
  fi
  psql "${PG_TOOL_URL}" < "${WORK_DIR}/database.sql"
fi

echo "Restore completed from ${ARCHIVE_PATH}"
