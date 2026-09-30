#!/bin/sh
# Lets the usage-limits widget see Claude Code's 5-hour and weekly limits.
#
# Claude Code keeps those percentages in memory and hands them only to its status
# line command. Point `statusLine` in ~/.claude/settings.json at this script and
# it saves that payload for the widget, then runs your real status line command:
#
#   "statusLine": { "type": "command",
#                   "command": "sh /path/to/ui/scripts/claude-statusline.sh <your current command>" }
#
# With no command after it, it saves the payload and prints nothing. It writes
# one file, ~/.local/state/desktop-widget-control/claude-statusline.json, never
# uses the network, and a failure to save never stops the status line.
input=$(cat)
dir=${XDG_STATE_HOME:-$HOME/.local/state}/desktop-widget-control
if mkdir -p "$dir" 2>/dev/null && tmp=$(mktemp "$dir/.claude-statusline.XXXXXX" 2>/dev/null); then
    if printf '%s\n' "$input" > "$tmp" 2>/dev/null; then
        chmod 600 "$tmp" 2>/dev/null
        mv -f "$tmp" "$dir/claude-statusline.json" 2>/dev/null || rm -f "$tmp"
    else
        rm -f "$tmp"
    fi
fi
if [ "$#" -gt 0 ]; then
    printf '%s\n' "$input" | exec "$@"
fi
exit 0
