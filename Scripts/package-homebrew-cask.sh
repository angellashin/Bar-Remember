#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PROJECT_DIR="${SCRIPT_DIR:h}"
OUTPUT_DIR="${1:-${PROJECT_DIR}/dist/homebrew}"
INFO_PLIST="${PROJECT_DIR}/Resources/Info.plist"

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "${INFO_PLIST}")"
BUILD_NUMBER="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "${INFO_PLIST}")"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/barremember-cask.XXXXXX")"
trap 'rm -rf "${STAGING_DIR}"' EXIT

mkdir -p "${OUTPUT_DIR}"
BARREMEMBER_BUILD_PATH="${STAGING_DIR}/swiftpm" \
    "${SCRIPT_DIR}/build-app.sh" "${STAGING_DIR}/app"

APP_PATH="${STAGING_DIR}/app/BarRemember.app"
ARCHITECTURES="$(lipo -archs "${APP_PATH}/Contents/MacOS/BarRemember")"
if [[ "${ARCHITECTURES}" != "arm64" ]]; then
    print -u2 "Expected an arm64-only build, found: ${ARCHITECTURES}"
    exit 1
fi

ARCHIVE_NAME="BarRemember-${VERSION}-macos-arm64.zip"
ARCHIVE_PATH="${OUTPUT_DIR:A}/${ARCHIVE_NAME}"
CHECKSUM_PATH="${ARCHIVE_PATH}.sha256"
if [[ -e "${ARCHIVE_PATH}" || -e "${CHECKSUM_PATH}" ]]; then
    print -u2 "Refusing to overwrite an existing archive or checksum: ${ARCHIVE_PATH}"
    exit 1
fi

# The app has no resource-fork payload. Avoid AppleDouble (._*) entries in the
# release ZIP without mutating the app bundle or its extended attributes.
ditto -c -k --norsrc --keepParent "${APP_PATH}" "${ARCHIVE_PATH}"
CHECKSUM="$(shasum -a 256 "${ARCHIVE_PATH}" | awk '{print $1}')"
print -- "${CHECKSUM}  ${ARCHIVE_NAME}" > "${CHECKSUM_PATH}"

print "Packaged ${ARCHIVE_PATH}"
print "Version ${VERSION} (build ${BUILD_NUMBER}), architecture ${ARCHITECTURES}"
print "SHA-256 ${CHECKSUM}"
