#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
OUTPUT_DIR="${1:-${PROJECT_DIR}/dist}"
APP_DIR="${OUTPUT_DIR}/BarRemember.app"
CONTENTS_DIR="${APP_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"
BARREMEMBER_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
BARREMEMBER_SWIFT="${BARREMEMBER_DEVELOPER_DIR}/Toolchains/XcodeDefault.xctoolchain/usr/bin/swift"
BARREMEMBER_MODULE_CACHE="${PROJECT_DIR}/.build/ModuleCache"

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
chmod +x "${MACOS_DIR}/BarRemember"

codesign --force --deep --sign - "${APP_DIR}"

echo "Built ${APP_DIR}"
