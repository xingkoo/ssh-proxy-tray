#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="SSH Proxy Tray"
APP="$ROOT/dist/$APP_NAME.app"
BIN_DIR="$APP/Contents/MacOS"
RESOURCES_DIR="$APP/Contents/Resources"

cd "$ROOT"
if [[ ! -f "$ROOT/Resources/AppIcon.icns" ]]; then
    "$ROOT/scripts/generate-icon.sh"
fi

swift build -c release --product SSHProxyTray
swift build -c release --product SSHAskPass
swift build -c release --product ssh-proxy-trayctl

rm -rf "$APP"
mkdir -p "$BIN_DIR" "$RESOURCES_DIR"
cp "$ROOT/.build/release/SSHProxyTray" "$BIN_DIR/SSHProxyTray"
cp "$ROOT/.build/release/SSHAskPass" "$BIN_DIR/SSHAskPass"
cp "$ROOT/Config/Info.plist" "$APP/Contents/Info.plist"
cp "$ROOT/Resources/AppIcon.icns" "$RESOURCES_DIR/AppIcon.icns"

chmod 755 "$BIN_DIR/SSHProxyTray" "$BIN_DIR/SSHAskPass"
codesign --force --deep --sign - "$APP"

rm -f "$ROOT/dist/ssh-proxy-tray-macos.zip"
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ROOT/dist/ssh-proxy-tray-macos.zip"

echo "Built $APP"
