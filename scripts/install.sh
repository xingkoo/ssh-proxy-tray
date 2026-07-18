#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SOURCE="$ROOT/dist/SSH Proxy Tray.app"
DESTINATION="/Applications/SSH Proxy Tray.app"
LAUNCH_ARGUMENTS=(--args --show-window)

if [[ "${1:-}" == "--launch-at-login" ]]; then
    LAUNCH_ARGUMENTS+=(--enable-launch-at-login)
fi

if [[ ! -d "$SOURCE" ]]; then
    "$ROOT/scripts/build-app.sh"
fi

for pid in $(pgrep -x SSHProxyTray 2>/dev/null || true); do
    pkill -TERM -P "$pid" 2>/dev/null || true
    kill -TERM "$pid" 2>/dev/null || true
done
for _ in {1..20}; do
    pgrep -x SSHProxyTray >/dev/null 2>&1 || break
    sleep 0.1
done
rm -rf "$DESTINATION"
ditto "$SOURCE" "$DESTINATION"
open "$DESTINATION" "${LAUNCH_ARGUMENTS[@]}"

echo "Installed $DESTINATION"
