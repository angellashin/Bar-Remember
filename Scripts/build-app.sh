#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
OUTPUT_DIR="${1:-${PROJECT_DIR}/dist}"
APP_DIR="${OUTPUT_DIR}/BarRemember.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
BARREMEMBER_DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
BARREMEMBER_XCODEBUILD="${BARREMEMBER_DEVELOPER_DIR}/usr/bin/xcodebuild"
BARREMEMBER_SWIFT="$(env DEVELOPER_DIR="${BARREMEMBER_DEVELOPER_DIR}" xcrun --find swift)"
BARREMEMBER_MODULE_CACHE="${PROJECT_DIR}/.build/ModuleCache"

if [[ ! -x "${BARREMEMBER_XCODEBUILD}" ]]; then
  print -u2 "BarRemember requires a full Xcode 26.0+ installation."
  exit 1
fi

BARREMEMBER_XCODE_VERSION="$("${BARREMEMBER_XCODEBUILD}" -version | awk '/^Xcode / { print $2; exit }')"
BARREMEMBER_XCODE_MAJOR="${BARREMEMBER_XCODE_VERSION%%.*}"
if [[ -z "${BARREMEMBER_XCODE_MAJOR}" || "${BARREMEMBER_XCODE_MAJOR}" -lt 26 ]]; then
  print -u2 "BarRemember requires Xcode 26.0+ (Swift 6.2); found ${BARREMEMBER_XCODE_VERSION:-unknown}."
  exit 1
fi

mkdir -p "${MACOS_DIR}" "${RESOURCES_DIR}"

env \
    DEVELOPER_DIR="${BARREMEMBER_DEVELOPER_DIR}" \
    CLANG_MODULE_CACHE_PATH="${BARREMEMBER_MODULE_CACHE}" \
    SWIFTPM_MODULECACHE_OVERRIDE="${BARREMEMBER_MODULE_CACHE}" \
    "${BARREMEMBER_SWIFT}" build \
    --package-path "${PROJECT_DIR}" \
    --configuration release \
    --scratch-path "${PROJECT_DIR}/.build"

BIN_DIR="$(env DEVELOPER_DIR="${BARREMEMBER_DEVELOPER_DIR}" "${BARREMEMBER_SWIFT}" build --package-path "${PROJECT_DIR}" --configuration release --scratch-path "${PROJECT_DIR}/.build" --show-bin-path)"

cp "${BIN_DIR}/BarRemember" "${MACOS_DIR}/BarRemember"
cp "${PROJECT_DIR}/Resources/Info.plist" "${CONTENTS_DIR}/Info.plist"
cp "${PROJECT_DIR}/Resources/AppIcon.icns" "${RESOURCES_DIR}/AppIcon.icns"
for localization in en.lproj ko.lproj; do
    if [[ -d "${PROJECT_DIR}/Resources/${localization}" ]]; then
        cp -R "${PROJECT_DIR}/Resources/${localization}" "${RESOURCES_DIR}/${localization}"
    fi
done
chmod +x "${MACOS_DIR}/BarRemember"

codesign --force --deep --sign - "${APP_DIR}"

echo "Built ${APP_DIR}"
