#!/usr/bin/env bash
# Pack the .app into a standard .dmg for drag-and-drop installation

set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="dimmi"
DIST_DIR="${DIMMI_DIST_DIR:-$ROOT/dist}"
APP_PATH="$DIST_DIR/$APP_NAME.app"
DMG_PATH="$DIST_DIR/$APP_NAME.dmg"
DMG_ROOT="$DIST_DIR/dmg_root"

log()  { printf '[package-dmg] %s\n' "$*"; }
fail() { printf '[package-dmg] ERROR: %s\n' "$*" >&2; exit 1; }

[ -d "$APP_PATH" ] || fail "Cannot find $APP_PATH. Build the app first."

log "Preparing DMG root..."
rm -rf "$DMG_ROOT"
mkdir -p "$DMG_ROOT"

# Copy app into DMG root
cp -R "$APP_PATH" "$DMG_ROOT/"

# Create symlink to /Applications for drag-and-drop
ln -s /Applications "$DMG_ROOT/Applications"

log "Creating DMG..."
rm -f "$DMG_PATH"
hdiutil create -volname "$APP_NAME" -srcfolder "$DMG_ROOT" -ov -format UDZO "$DMG_PATH" > /dev/null

log "Cleaning up..."
rm -rf "$DMG_ROOT"

log "DMG created successfully: $DMG_PATH"
