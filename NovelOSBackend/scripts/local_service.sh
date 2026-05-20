#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BACKEND_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
LABEL="top.linotsai.novelos.local7773"
PLIST_PATH="${HOME}/Library/LaunchAgents/${LABEL}.plist"
PYTHON_BIN="${BACKEND_DIR}/.venv/bin/python"
PORT="${NOVEL_OS_LOCAL_PORT:-7773}"

usage() {
  echo "Usage: $0 {install|start|stop|restart|status|health}" >&2
  exit 2
}

write_plist() {
  mkdir -p "$(dirname "${PLIST_PATH}")" "${BACKEND_DIR}/.local-run"
  cat > "${PLIST_PATH}" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${PYTHON_BIN}</string>
    <string>-m</string>
    <string>uvicorn</string>
    <string>app.main:app</string>
    <string>--host</string>
    <string>127.0.0.1</string>
    <string>--port</string>
    <string>${PORT}</string>
  </array>
  <key>WorkingDirectory</key>
  <string>${BACKEND_DIR}</string>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
  <key>StandardOutPath</key>
  <string>${BACKEND_DIR}/.local-run/novelos-${PORT}.log</string>
  <key>StandardErrorPath</key>
  <string>${BACKEND_DIR}/.local-run/novelos-${PORT}.err.log</string>
  <key>EnvironmentVariables</key>
  <dict>
    <key>NOVEL_OS_REQUIRE_OWNER_TOKEN</key>
    <string>false</string>
    <key>NOVEL_OS_CORS_ALLOW_ORIGINS</key>
    <string>http://127.0.0.1:${PORT},http://localhost:${PORT}</string>
  </dict>
</dict>
</plist>
PLIST
}

domain_target="gui/$(id -u)/${LABEL}"

case "${1:-}" in
  install)
    if [[ ! -x "${PYTHON_BIN}" ]]; then
      echo "Python venv missing: ${PYTHON_BIN}" >&2
      exit 1
    fi
    write_plist
    launchctl bootstrap "gui/$(id -u)" "${PLIST_PATH}" 2>/dev/null || true
    launchctl kickstart -k "${domain_target}"
    ;;
  start)
    [[ -f "${PLIST_PATH}" ]] || write_plist
    launchctl bootstrap "gui/$(id -u)" "${PLIST_PATH}" 2>/dev/null || true
    launchctl kickstart -k "${domain_target}"
    ;;
  stop)
    launchctl bootout "gui/$(id -u)" "${PLIST_PATH}" 2>/dev/null || launchctl bootout "${domain_target}" 2>/dev/null || true
    ;;
  restart)
    [[ -f "${PLIST_PATH}" ]] || write_plist
    launchctl bootstrap "gui/$(id -u)" "${PLIST_PATH}" 2>/dev/null || true
    launchctl kickstart -k "${domain_target}"
    ;;
  status)
    launchctl print "${domain_target}"
    ;;
  health)
    curl -fsS "http://127.0.0.1:${PORT}/healthz"
    ;;
  *)
    usage
    ;;
esac
