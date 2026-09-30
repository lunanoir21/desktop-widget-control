#!/bin/sh
# Adds a Hyprland key that opens the editor. The first-run tour runs this when
# asked to; it can also be run by hand:   sh bind.sh
#
# A Lua config (hyprland.lua) gets a Lua line, a .conf config gets a .conf line.
# Prints one line, STATUS|KEYS|FILE, and changes nothing unless STATUS is ok.
#   ok      added; KEYS is the key, FILE the file it went into
#   exists  a Desktop Widget Control key is already set up
#   nohypr  no Hyprland config found
#   fail    could not write
# SUPER + G is used when free, else SUPER SHIFT + G, else SUPER ALT + G.
CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
HDIR=$CONFIG_HOME/hypr
MARK="desktop-widget-control"

if command -v dwc >/dev/null 2>&1; then CMD="dwc toggle"; else CMD="qs ipc call desktopWidgets toggle"; fi

# Which config? Lua wins when there is one; Omarchy keeps the user's own
# bindings in bindings.conf / bindings.lua.
if [ -f "$HDIR/hyprland.lua" ]; then
    KIND=lua
    TARGET=$HDIR/hyprland.lua
    [ -f "$HDIR/bindings.lua" ] && TARGET=$HDIR/bindings.lua
elif [ -f "$HDIR/hyprland.conf" ]; then
    KIND=conf
    TARGET=$HDIR/hyprland.conf
    [ -f "$HDIR/bindings.conf" ] && TARGET=$HDIR/bindings.conf
else
    echo "nohypr||"
    exit 0
fi

if grep -qs "$MARK" "$HDIR/hyprland.$KIND" "$TARGET"; then
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

if [ "$KIND" = lua ]; then
    # "SUPER SHIFT" is written "SUPER + SHIFT" in Lua.
    LUAKEYS=$(printf '%s' "$MODS" | sed 's/ / + /g')
    printf '\n-- Desktop Widget Control: open the editor with a key. (%s)\nhl.bind("%s + G", hl.dsp.exec_cmd("%s"))\n' "$MARK" "$LUAKEYS" "$CMD" >> "$TARGET" || { echo "fail||$TARGET"; exit 0; }
else
    printf '\n# Desktop Widget Control: open the editor with a key. (%s)\nbind = %s, G, exec, %s\n' "$MARK" "$MODS" "$CMD" >> "$TARGET" || { echo "fail||$TARGET"; exit 0; }
fi
hyprctl reload >/dev/null 2>&1
echo "ok|$MODS + G|$TARGET"
