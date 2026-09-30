#!/bin/sh
# Adds a Hyprland key that opens the editor. The first-run tour runs this when
# asked to; it can also be run by hand:
#   sh bind.sh                 in a terminal it asks which key; Enter picks one for you
#   sh bind.sh SUPER_ALT A     that key (modifiers joined by _), nothing else is tried
#   sh bind.sh auto            pick a free one without asking
#
# A Lua config (hyprland.lua) gets a Lua line, a .conf config gets a .conf line.
# Prints one line, STATUS|KEYS|FILE, and changes nothing unless STATUS is ok.
#   ok      added; KEYS is the key, FILE the file it went into
#   exists  a Desktop Widget Control key is already set up
#   nohypr  no Hyprland config found
#   taken   the key asked for (or every key it tries) is already bound
#   bad     the key asked for is not something it understands
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
# Which key? Asked for in the arguments, typed in a terminal, or the first free
# of a list. Each candidate is "modifier-mask MODIFIERS key".
ASK=""
if [ "$#" -ge 2 ]; then
    ASK="$1 $2"
elif [ "$#" -eq 0 ] && [ -t 0 ] && [ -t 1 ]; then
    printf 'Key to open the editor, e.g. SUPER ALT, A  (Enter = pick a free one): ' >&2
    read -r line
    if [ -n "$line" ]; then
        # "SUPER ALT, A" / "SUPER + ALT + A": the last word is the key, the rest modifiers.
        line=$(printf '%s' "$line" | tr ',+' '  ')
        ASK="$(printf '%s' "$line" | awk '{ $NF = ""; print }' | tr -s ' ' '_' | sed 's/_$//') $(printf '%s' "$line" | awk '{ print $NF }')"
    fi
fi

CANDIDATES="64 SUPER g|65 SUPER_SHIFT g|72 SUPER_ALT g|68 SUPER_CTRL g|64 SUPER f12|65 SUPER_SHIFT f12"
if [ -n "$ASK" ]; then
    # shellcheck disable=SC2086
    set -- $ASK
    MODS_IN=$(printf '%s' "$1" | tr '[:lower:]' '[:upper:]')
    KEY_IN=$2
    case "$KEY_IN" in *[!A-Za-z0-9_]*|"") echo "bad||"; exit 0 ;; esac
    mask=0
    for m in $(printf '%s' "$MODS_IN" | tr '_' ' '); do
        case "$m" in
            SUPER) mask=$((mask + 64)) ;;
            SHIFT) mask=$((mask + 1)) ;;
            CTRL|CONTROL) mask=$((mask + 4)) ;;
            ALT) mask=$((mask + 8)) ;;
            *) echo "bad||"; exit 0 ;;
        esac
    done
    [ "$mask" -gt 0 ] || { echo "bad||"; exit 0; }   # a bare letter would swallow typing
    CANDIDATES="$mask $MODS_IN $(printf '%s' "$KEY_IN" | tr '[:upper:]' '[:lower:]')"
fi

MODS=""
KEY=""
IFS='|'
for c in $CANDIDATES; do
    IFS=' '
    # shellcheck disable=SC2086
    set -- $c
    if ! taken "$1" "$3"; then MODS=$(printf '%s' "$2" | tr _ ' '); KEY=$(printf '%s' "$3" | tr '[:lower:]' '[:upper:]'); break; fi
    IFS='|'
done
IFS=' 	
'
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
