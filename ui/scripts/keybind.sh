#!/bin/sh
# Offered by the first-run tour: add a Hyprland key that opens the editor.
# Prints one line, STATUS|KEYS|FILE, and changes nothing unless STATUS is ok.
#   ok      added; KEYS is the key, FILE the config that now sources our snippet
#   exists  a Desktop Widget Control key is already set up
#   lua     the config is Lua, which this script does not edit; KEYS is the line to add
#   nohypr  no hyprland.conf to add it to
#   fail    could not write
# SUPER + G is used when free, else SUPER SHIFT + G, else SUPER ALT + G.
CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
HDIR=$CONFIG_HOME/hypr
MAIN=$HDIR/hyprland.conf
MARK="# desktop-widget-control"

if command -v dwc >/dev/null 2>&1; then CMD="dwc toggle"; else CMD="qs ipc call desktopWidgets toggle"; fi

if [ -f "$HDIR/hyprland.lua" ]; then
    echo "lua|hl.bind(\"SUPER + G\", hl.dsp.exec_cmd(\"$CMD\"))|$HDIR/hyprland.lua"
    exit 0
fi
[ -f "$MAIN" ] || { echo "nohypr||"; exit 0; }

# Omarchy keeps the user's own bindings in bindings.conf.
TARGET=$MAIN
[ -f "$HDIR/bindings.conf" ] && TARGET=$HDIR/bindings.conf
if grep -q "desktop-widget-control" "$MAIN" "$TARGET" 2>/dev/null; then
    echo "exists||$TARGET"
    exit 0
fi

# Is this modifier mask + key already bound? (Needs jq; without it we go ahead.)
taken() {
    command -v hyprctl >/dev/null 2>&1 && command -v jq >/dev/null 2>&1 || return 1
    hyprctl binds -j 2>/dev/null | jq -e --argjson m "$1" 'any(.[]; .modmask == $m and (.key | ascii_downcase) == "g")' >/dev/null 2>&1
}
MODS="SUPER ALT"
if ! taken 64; then MODS="SUPER"; elif ! taken 65; then MODS="SUPER SHIFT"; fi

SNIPDIR=$CONFIG_HOME/desktop-widget-control
mkdir -p "$SNIPDIR" || { echo "fail||$SNIPDIR"; exit 0; }
printf '# Desktop Widget Control: open the editor with a key.\nbind = %s, G, exec, %s\n' "$MODS" "$CMD" > "$SNIPDIR/hyprland.conf" || { echo "fail||$SNIPDIR"; exit 0; }
printf '\nsource = %s %s\n' "$SNIPDIR/hyprland.conf" "$MARK" >> "$TARGET" || { echo "fail||$TARGET"; exit 0; }
hyprctl reload >/dev/null 2>&1
echo "ok|$MODS + G|$TARGET"
