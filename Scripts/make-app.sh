#!/bin/bash
#
# make-app.sh — package the Runtahio SPM executable into a real, launchable macOS .app
# bundle with a stable identity for Full Disk Access (TCC).
#
# Why a bundle? A bare `swift run` binary launches as a BackgroundOnly process (no menu
# bar, never frontmost) and its path changes every build, so TCC's Full Disk Access grant
# never sticks. A signed .app with a fixed CFBundleIdentifier + stable path fixes both.
#
# Usage:
#   ./Scripts/make-app.sh [--debug] [--no-sign] [--run]
#
#   --debug    build the debug configuration (default: release)
#   --no-sign  skip the ad-hoc codesign step
#   --run      open the app after building
#
set -euo pipefail

CONFIG="release"
SIGN=1
RUN=0
BUNDLE_ID="com.runtahio.app"
APP_NAME="Runtahio"

for arg in "$@"; do
  case "$arg" in
    --debug)   CONFIG="debug" ;;
    --no-sign) SIGN=0 ;;
    --run)     RUN=1 ;;
    *) echo "Unknown option: $arg"; exit 2 ;;
  esac
done

# Resolve paths relative to the repo root (parent of this script's dir).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$ROOT_DIR"

echo "==> Building $APP_NAME ($CONFIG)…"
swift build -c "$CONFIG" --product "$APP_NAME"

BIN_DIR="$(swift build -c "$CONFIG" --show-bin-path)"
BIN_PATH="$BIN_DIR/$APP_NAME"
if [[ ! -x "$BIN_PATH" ]]; then
  echo "error: built binary not found at $BIN_PATH" >&2
  exit 1
fi

APP_DIR="$ROOT_DIR/$APP_NAME.app"
CONTENTS="$APP_DIR/Contents"
MACOS="$CONTENTS/MacOS"
RESOURCES="$CONTENTS/Resources"

# Derive the version from git so the bundle matches the release tag.
# CFBundleShortVersionString must be up to three dot-separated integers (e.g. 0.1.0):
# take the nearest reachable tag, strip a leading "v", and keep the X[.Y[.Z]] run.
# CFBundleVersion uses the total commit count as a monotonic build number.
# Both fall back to sane defaults when building outside a git checkout (e.g. a tarball).
SHORT_VERSION="0.0.0"
BUILD_VERSION="1"
if git -C "$ROOT_DIR" rev-parse --git-dir >/dev/null 2>&1; then
  TAG="$(git -C "$ROOT_DIR" describe --tags --abbrev=0 2>/dev/null || true)"
  CLEAN="${TAG#[vV]}"
  CLEAN="${CLEAN%%-*}"
  if [[ "$CLEAN" =~ ^[0-9]+(\.[0-9]+){0,2}$ ]]; then
    SHORT_VERSION="$CLEAN"
  fi
  COUNT="$(git -C "$ROOT_DIR" rev-list --count HEAD 2>/dev/null || true)"
  if [[ "$COUNT" =~ ^[0-9]+$ ]]; then
    BUILD_VERSION="$COUNT"
  fi
fi
echo "==> Version: $SHORT_VERSION (build $BUILD_VERSION)"

echo "==> Assembling $APP_NAME.app…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS" "$RESOURCES"
cp "$BIN_PATH" "$MACOS/$APP_NAME"

# Info.plist
cat > "$CONTENTS/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>           <string>en</string>
    <key>CFBundleExecutable</key>                  <string>$APP_NAME</string>
    <key>CFBundleIconFile</key>                    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>                  <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>                        <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>                 <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>                 <string>APPL</string>
    <key>CFBundleShortVersionString</key>          <string>$SHORT_VERSION</string>
    <key>CFBundleVersion</key>                     <string>$BUILD_VERSION</string>
    <key>LSMinimumSystemVersion</key>              <string>26.0</string>
    <key>LSApplicationCategoryType</key>           <string>public.app-category.utilities</string>
    <key>NSHighResolutionCapable</key>             <true/>
    <key>NSHumanReadableCopyright</key>            <string>Runtahio — Find the clutter. Free your Mac.</string>
    <key>NSPrincipalClass</key>                    <string>NSApplication</string>
</dict>
</plist>
PLIST

# Validate the plist (fails loudly if malformed).
plutil -lint "$CONTENTS/Info.plist" >/dev/null

# PkgInfo
printf 'APPL????' > "$CONTENTS/PkgInfo"

# Optional app icon (only if an iconset has been provided).
if [[ -d "$ROOT_DIR/Sources/Runtahio/Resources/AppIcon.iconset" ]]; then
  echo "==> Building app icon…"
  iconutil -c icns "$ROOT_DIR/Sources/Runtahio/Resources/AppIcon.iconset" -o "$RESOURCES/AppIcon.icns" || true
fi

if [[ "$SIGN" -eq 1 ]]; then
  echo "==> Ad-hoc signing (identifier $BUNDLE_ID)…"
  # Explicit --identifier pins what TCC remembers; ad-hoc (-) needs no certificate.
  codesign --force --sign - --identifier "$BUNDLE_ID" --timestamp=none "$APP_DIR"
  codesign --verify --verbose=2 "$APP_DIR" || echo "warning: codesign verify reported issues"
fi

echo "==> Done: $APP_DIR"
echo "    Launch with:  open \"$APP_DIR\""
echo "    For protected folders, grant Full Disk Access to this app in"
echo "    System Settings → Privacy & Security → Full Disk Access."

if [[ "$RUN" -eq 1 ]]; then
  echo "==> Launching…"
  open "$APP_DIR"
fi
