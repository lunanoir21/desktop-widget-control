#!/bin/sh
# Adds a Hyprland key that opens the editor. The first-run tour runs this when
# asked to; it can also be run by hand:   sh bind.sh
#
# A Lua config (hyprland.lua) gets a Lua line, a .conf config gets a .conf line.
# Prints one line, STATUS|KEYS|FILE, and changes nothing unless STATUS is ok.
#   ok      added; KEYS is the key, FILE the file it went into
#   exists  a Desktop Widget Control key is already set up
#   nohypr  no Hyprland config found
#   taken   every key it tries is already bound
#   fail    could not write
# SUPER + G is used when free, else SUPER SHIFT + G, SUPER ALT + G, SUPER CTRL + G,
# SUPER + F12, SUPER SHIFT + F12: the first that nothing else uses.
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
    hyprctl binds -j 2>/dev/null | jq -e --argjson m "$1" --arg k "$2" 'any(.[]; .modmask == $m and (.key | ascii_downcase) == $k)' >/dev/null 2>&1
}
# The first free one of these: modifier mask, modifiers, key.
MODS=""
KEY=""
for c in "64 SUPER g" "65 SUPER_SHIFT g" "72 SUPER_ALT g" "68 SUPER_CTRL g" "64 SUPER f12" "65 SUPER_SHIFT f12"; do
    # shellcheck disable=SC2086
    set -- $c
    if ! taken "$1" "$3"; then MODS=$(printf '%s' "$2" | tr _ ' '); KEY=$(printf '%s' "$3" | tr '[:lower:]' '[:upper:]'); break; fi
done
[ -n "$KEY" ] || { echo "taken||"; exit 0; }

if [ "$KIND" = lua ]; then
    # "SUPER SHIFT" is written "SUPER + SHIFT" in Lua.
    LUAKEYS=$(printf '%s' "$MODS" | sed 's/ / + /g')
    printf '\n-- Desktop Widget Control: open the editor with a key. (%s)\nhl.bind("%s + %s", hl.dsp.exec_cmd("%s"))\n' "$MARK" "$LUAKEYS" "$KEY" "$CMD" >> "$TARGET" || { echo "fail||$TARGET"; exit 0; }
else
    printf '\n# Desktop Widget Control: open the editor with a key. (%s)\nbind = %s, %s, exec, %s\n' "$MARK" "$MODS" "$KEY" "$CMD" >> "$TARGET" || { echo "fail||$TARGET"; exit 0; }
fi
hyprctl reload >/dev/null 2>&1
echo "ok|$MODS + $KEY|$TARGET"
