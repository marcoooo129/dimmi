#!/usr/bin/env bash
# Give a certificate-less local build a stable code identity.
#
# This is intentionally an ad-hoc signature for local development/testing. It
# is not a substitute for Developer ID signing and notarization when shipping
# the app to other Macs.

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUNDLE_ID="com.frase.app"
ENTITLEMENTS="$ROOT/Resources/dimmi.entitlements"
EXPECTED_DR="designated => identifier \"$BUNDLE_ID\""

fail() { printf '[sign-local] ERROR: %s\n' "$*" >&2; exit 1; }
log()  { printf '[sign-local] %s\n' "$*"; }

[ "$#" -eq 1 ] || fail "用法: $0 /path/to/dimmi.app"

APP="$1"
if [[ "$APP" != /* ]]; then
    APP="$PWD/$APP"
fi

[ -d "$APP" ] || fail "App 不存在: $APP"
[ -f "$APP/Contents/Info.plist" ] || fail "缺少 Info.plist: $APP"
[ -f "$ENTITLEMENTS" ] || fail "缺少 entitlements: $ENTITLEMENTS"

ACTUAL_BUNDLE_ID="$(plutil -extract CFBundleIdentifier raw -o - "$APP/Contents/Info.plist")"
[ "$ACTUAL_BUNDLE_ID" = "$BUNDLE_ID" ] \
    || fail "Bundle ID 不匹配（期望 ${BUNDLE_ID}，实际 ${ACTUAL_BUNDLE_ID}）"

# `-r=<requirement>` must be one argv item. With no explicit DR, codesign
# synthesizes a cdhash-only DR for an ad-hoc signature, which changes whenever
# the executable changes. The explicit identifier DR remains identical across
# local rebuilds while the CodeDirectory hash is still free to change.
codesign \
    --force \
    --sign - \
    --timestamp=none \
    --options runtime \
    --entitlements "$ENTITLEMENTS" \
    "-r=$EXPECTED_DR" \
    "$APP"

codesign --verify --deep --strict --verbose=2 "$APP"

# An explicit DR is printed without the leading '#'. An implicit synthesized
# DR is commented, so this check also guards against accidentally regressing to
# a cdhash-based identity.
ACTUAL_DR="$(codesign -d -r- "$APP" 2>&1 | sed -n '/^designated =>/p')"
[ "$ACTUAL_DR" = "$EXPECTED_DR" ] \
    || fail "Designated Requirement 不稳定（期望 '$EXPECTED_DR'，实际 '${ACTUAL_DR:-<implicit>}'）"

log "已应用稳定的本地 ad-hoc DR: $ACTUAL_DR"
