#!/usr/bin/env bash
# Build and package a local Release of dimmi without a signing certificate.
#
# Output:
#   dist/dimmi.app
#   dist/dimmi-macOS.zip
#
# The result is ad-hoc signed with the same explicit designated requirement as
# tools/dev-rebuild.sh. It is suitable for this Mac's local use and testing,
# but is not Developer ID signed or notarized for public distribution.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

SCHEME="dimmi"
CONFIG="Release"
DERIVED_DATA="${DIMMI_RELEASE_BUILD_DIR:-$ROOT/build-release}"
DIST_DIR="${DIMMI_DIST_DIR:-$ROOT/dist}"
BUILD_LOG="$DERIVED_DATA/build.log"
BUILT_APP="$DERIVED_DATA/Build/Products/$CONFIG/dimmi.app"
DIST_APP="$DIST_DIR/dimmi.app"
ZIP_PATH="$DIST_DIR/dimmi-macOS.zip"

log()  { printf '[release-package] %s\n' "$*"; }
fail() { printf '[release-package] ERROR: %s\n' "$*" >&2; exit 1; }

mkdir -p "$DERIVED_DATA" "$DIST_DIR"

log "构建 ${CONFIG}（无证书）…"
xcodebuild \
    -project Frase.xcodeproj \
    -scheme "$SCHEME" \
    -configuration "$CONFIG" \
    -destination "platform=macOS" \
    -derivedDataPath "$DERIVED_DATA" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    ONLY_ACTIVE_ARCH=NO \
    build 2>&1 | tee "$BUILD_LOG" | tail -8

grep -q 'BUILD SUCCEEDED' "$BUILD_LOG" || fail "xcodebuild 未成功"
[ -d "$BUILT_APP" ] || fail "找不到构建产物: $BUILT_APP"

"$ROOT/tools/sign-local.sh" "$BUILT_APP"

rm -rf "$DIST_APP"
rm -f "$ZIP_PATH"
ditto "$BUILT_APP" "$DIST_APP"

codesign --verify --deep --strict --verbose=2 "$DIST_APP"

DR="$(codesign -d -r- "$DIST_APP" 2>&1 | sed -n '/^designated =>/p')"
[ "$DR" = 'designated => identifier "com.frase.app"' ] \
    || fail "dist App 的 DR 不正确: ${DR:-<implicit>}"

ditto -c -k --sequesterRsrc --keepParent "$DIST_APP" "$ZIP_PATH"
unzip -tq "$ZIP_PATH" >/dev/null

ARCHS="$(lipo -archs "$DIST_APP/Contents/MacOS/dimmi")"
log "已验证签名与压缩包"
log "DR: $DR"
log "架构: $ARCHS"
log "App: $DIST_APP"
log "ZIP: $ZIP_PATH"
