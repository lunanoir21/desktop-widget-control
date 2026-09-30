#!/bin/sh
# Take a clean screenshot of the widgets.
#
#     tools/capture.sh OUT.png [--layout DIR] [--edit] [--wait SECONDS]
#
#   --layout DIR   use DIR/layout.json (default: a throwaway dir, so the
#                  first-run layout; tools/showcase.py writes a fuller one)
#   --edit         open the editor before capturing
#   --select ID    with --edit: select a widget first (e.g. media-1)
#   --wait N       seconds to let widgets load and animate (default 7)
#
# It starts its own instance, goes to an empty Hyprland workspace so none of
# your windows are in the picture, grabs the screen with grim, closes the
# instance and puts you back on the workspace you were on. On another
# compositor the workspace step is skipped: close your windows first.
#
# Needs: quickshell, grim. Optional: hyprctl, jq (for the workspace switch).
set -u

ROOT=$(cd "$(dirname "$0")/.." && pwd)
OUT=""
LAYOUT=""
EDIT=0
SELECT=""
WAIT=7

while [ $# -gt 0 ]; do
    case "$1" in
        --layout) LAYOUT=$2; shift 2 ;;
        --edit) EDIT=1; shift ;;
        --select) SELECT=$2; shift 2 ;;
        --wait) WAIT=$2; shift 2 ;;
        -h|--help) sed -n '2,20p' "$0"; exit 0 ;;
        *) OUT=$1; shift ;;
    esac
done
[ -n "$OUT" ] || { sed -n '2,20p' "$0"; exit 1; }

TMP=$(mktemp -d)
[ -n "$LAYOUT" ] || LAYOUT="$TMP/state"
PID=""
BACK=""

cleanup() {
    [ -n "$PID" ] && kill "$PID" 2>/dev/null
    # Always go home, even when the capture failed half way.
    [ -n "$BACK" ] && hyprctl dispatch workspace "$BACK" >/dev/null 2>&1
    rm -rf "$TMP"
}
trap cleanup EXIT INT TERM

if command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1; then
    BACK=$(hyprctl activeworkspace -j | jq -r '.id')
    hyprctl dispatch workspace empty >/dev/null 2>&1
    sleep 0.6
fi

DWC_CONFIG_DIR=$LAYOUT quickshell -p "$ROOT" >"$TMP/log" 2>&1 &
PID=$!
sleep "$WAIT"

if [ "$EDIT" = 1 ]; then
    quickshell -p "$ROOT" ipc call desktopWidgets edit >/dev/null 2>&1
    [ -n "$SELECT" ] && quickshell -p "$ROOT" ipc call desktopWidgets select "$SELECT" >/dev/null 2>&1
    sleep 2
fi

OUTPUT=""
command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 && OUTPUT=$(hyprctl monitors -j | jq -r '.[] | select(.focused) | .name')
if [ -n "$OUTPUT" ]; then
    grim -o "$OUTPUT" "$OUT"
else
    grim "$OUT"
fi
echo "wrote $OUT"
