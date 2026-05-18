#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
APP_NAME="NovelOSMac"
BUNDLE_ID="com.lino.novelosmac"
VERSION="0.1.0"

DIST_DIR="${ROOT_DIR}/dist"
APP_DIR="${DIST_DIR}/${APP_NAME}.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
ICON_DIR="${ROOT_DIR}/Resources/AppIcon"
ICONSET_DIR="${ICON_DIR}/AppIcon.iconset"
SOURCE_ICON="${ICON_DIR}/AppIcon-1024.png"
ICNS_PATH="${ICON_DIR}/${APP_NAME}.icns"
CUSTOM_ICON_SOURCE="${NOVEL_OS_ICON_SOURCE:-${1:-}}"

mkdir -p "${ICON_DIR}" "${DIST_DIR}"

if [[ -n "${CUSTOM_ICON_SOURCE}" ]]; then
  if [[ ! -f "${CUSTOM_ICON_SOURCE}" ]]; then
    echo "Custom icon source not found: ${CUSTOM_ICON_SOURCE}" >&2
    exit 1
  fi
  sips -z 1024 1024 "${CUSTOM_ICON_SOURCE}" --out "${SOURCE_ICON}" >/dev/null
else
  swift "${SCRIPT_DIR}/generate_app_icon.swift" "${SOURCE_ICON}"
fi

rm -rf "${ICONSET_DIR}"
mkdir -p "${ICONSET_DIR}"
sips -z 16 16 "${SOURCE_ICON}" --out "${ICONSET_DIR}/icon_16x16.png" >/dev/null
sips -z 32 32 "${SOURCE_ICON}" --out "${ICONSET_DIR}/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "${SOURCE_ICON}" --out "${ICONSET_DIR}/icon_32x32.png" >/dev/null
sips -z 64 64 "${SOURCE_ICON}" --out "${ICONSET_DIR}/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "${SOURCE_ICON}" --out "${ICONSET_DIR}/icon_128x128.png" >/dev/null
sips -z 256 256 "${SOURCE_ICON}" --out "${ICONSET_DIR}/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "${SOURCE_ICON}" --out "${ICONSET_DIR}/icon_256x256.png" >/dev/null
sips -z 512 512 "${SOURCE_ICON}" --out "${ICONSET_DIR}/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "${SOURCE_ICON}" --out "${ICONSET_DIR}/icon_512x512.png" >/dev/null
sips -z 1024 1024 "${SOURCE_ICON}" --out "${ICONSET_DIR}/icon_512x512@2x.png" >/dev/null
iconutil -c icns "${ICONSET_DIR}" -o "${ICNS_PATH}"

swift build --package-path "${ROOT_DIR}" -c release
BIN_DIR="$(swift build --package-path "${ROOT_DIR}" -c release --show-bin-path)"
BIN_PATH="${BIN_DIR}/${APP_NAME}"

if [[ ! -x "${BIN_PATH}" ]]; then
  echo "Release executable not found: ${BIN_PATH}" >&2
  exit 1
fi

rm -rf "${APP_DIR}"
mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"
cp "${BIN_PATH}" "${MACOS_DIR}/${APP_NAME}"
cp "${ICNS_PATH}" "${RESOURCES_DIR}/${APP_NAME}.icns"

cat > "${CONTENTS_DIR}/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>zh_CN</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>${APP_NAME}</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>${VERSION}</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>14.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
</dict>
</plist>
PLIST

chmod +x "${MACOS_DIR}/${APP_NAME}"
plutil -lint "${CONTENTS_DIR}/Info.plist" >/dev/null
codesign --force --sign - --timestamp=none "${APP_DIR}" >/dev/null
codesign --verify --deep --strict "${APP_DIR}"

echo "Packaged ${APP_DIR}"
