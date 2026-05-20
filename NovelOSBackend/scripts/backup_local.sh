#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
BACKUP_ROOT="${BACKEND_DIR}/backups"
STAMP="$(date +%Y%m%d-%H%M%S)"
WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/linoi-backup-${STAMP}.XXXXXX")"
ARCHIVE_PATH="${BACKUP_ROOT}/linoi-local-${STAMP}.tar.gz"

cleanup() {
  rm -rf "${WORK_DIR}"
}
trap cleanup EXIT

mkdir -p "${BACKUP_ROOT}"
cd "${BACKEND_DIR}"

METADATA_JSON="$("${BACKEND_DIR}/.venv/bin/python" - <<'PY'
from __future__ import annotations

import json
from pathlib import Path
from urllib.parse import urlparse

from app.config import env_file_path, load_environment
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
redacted = url
if parsed.password:
    redacted = url.replace(f":{parsed.password}@", ":***@")

print(json.dumps({
    "database_kind": "sqlite" if sqlite_path else "postgres",
    "sqlite_path": sqlite_path,
    "database_url": url,
    "database_url_redacted": redacted,
    "import_storage_dir": str(import_storage_dir().resolve()),
    "env_file": str(env_file_path().resolve()),
}, ensure_ascii=False))
PY
)"

DATABASE_KIND="$(printf '%s' "${METADATA_JSON}" | "${BACKEND_DIR}/.venv/bin/python" -c 'import json,sys; print(json.load(sys.stdin)["database_kind"])')"
SQLITE_PATH="$(printf '%s' "${METADATA_JSON}" | "${BACKEND_DIR}/.venv/bin/python" -c 'import json,sys; print(json.load(sys.stdin).get("sqlite_path") or "")')"
DATABASE_URL_VALUE="$(printf '%s' "${METADATA_JSON}" | "${BACKEND_DIR}/.venv/bin/python" -c 'import json,sys; print(json.load(sys.stdin)["database_url"])')"
PG_TOOL_URL="${DATABASE_URL_VALUE/postgresql+psycopg/postgresql}"
IMPORT_DIR="$(printf '%s' "${METADATA_JSON}" | "${BACKEND_DIR}/.venv/bin/python" -c 'import json,sys; print(json.load(sys.stdin)["import_storage_dir"])')"
ENV_FILE="$(printf '%s' "${METADATA_JSON}" | "${BACKEND_DIR}/.venv/bin/python" -c 'import json,sys; print(json.load(sys.stdin)["env_file"])')"

mkdir -p "${WORK_DIR}/payload"

cat > "${WORK_DIR}/payload/README.txt" <<EOF
LinoI local backup created at ${STAMP}.

This archive intentionally does not include .env, API keys, or owner tokens.
Original env file path: ${ENV_FILE}
Restore with: NovelOSBackend/scripts/restore_local.sh ${ARCHIVE_PATH}
EOF

printf '%s\n' "${METADATA_JSON}" | "${BACKEND_DIR}/.venv/bin/python" -c 'import json,sys; data=json.load(sys.stdin); data.pop("database_url", None); print(json.dumps(data, ensure_ascii=False, indent=2))' > "${WORK_DIR}/payload/manifest.json"

if [[ -d "${IMPORT_DIR}" ]]; then
  mkdir -p "${WORK_DIR}/payload/data"
  ditto "${IMPORT_DIR}" "${WORK_DIR}/payload/data/imports"
fi

if [[ "${DATABASE_KIND}" == "sqlite" ]]; then
  if [[ ! -f "${SQLITE_PATH}" ]]; then
    echo "SQLite database not found: ${SQLITE_PATH}" >&2
    exit 1
  fi
  cp "${SQLITE_PATH}" "${WORK_DIR}/payload/database.sqlite"
else
  if ! command -v pg_dump >/dev/null 2>&1; then
    echo "pg_dump is required for PostgreSQL backups." >&2
    exit 1
  fi
  pg_dump --no-owner --no-privileges --file "${WORK_DIR}/payload/database.sql" "${PG_TOOL_URL}"
fi

tar -C "${WORK_DIR}/payload" -czf "${ARCHIVE_PATH}" .
chmod 600 "${ARCHIVE_PATH}"
echo "${ARCHIVE_PATH}"
