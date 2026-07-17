#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/dist/SSH Proxy Tray.app"
DESTINATION="/Applications/SSH Proxy Tray.app"
LAUNCH_ARGUMENTS=()

if [[ "${1:-}" == "--launch-at-login" ]]; then
    LAUNCH_ARGUMENTS=(--args --enable-launch-at-login)
fi

if [[ ! -d "$SOURCE" ]]; then
    "$ROOT/scripts/build-app.sh"
fi

pkill -x SSHProxyTray 2>/dev/null || true
rm -rf "$DESTINATION"
ditto "$SOURCE" "$DESTINATION"
open "$DESTINATION" "${LAUNCH_ARGUMENTS[@]}"

echo "Installed $DESTINATION"
