#!/bin/sh
# Reads what the usage-limits widget shows. Prints sections, each starting with
# a line "@name [epoch]" followed by the raw JSON; the widget parses them.
#
#   sh usage.sh local    Codex: the newest rate-limit line in ~/.codex/sessions
#                        Claude: the status line capture (see claude-statusline.sh)
#   sh usage.sh api      Claude: the usage endpoint, with the token Claude Code keeps
#
# `local` reads files only. `api` is the one thing here that uses the network and
# reads a credential, and the widget runs it only when the option is switched on.
mode=${1:-local}
now=$(date +%s)
state=${XDG_STATE_HOME:-$HOME/.local/state}

if [ "$mode" = local ]; then
    dir=${CODEX_HOME:-$HOME/.codex}/sessions
    if [ -d "$dir" ]; then
        # The newest few logs, in case the very newest has not recorded a limit yet.
        find "$dir" -name 'rollout-*.jsonl' -type f -printf '%T@ %p\n' 2>/dev/null | sort -rn | head -6 | cut -d' ' -f2- |
        while IFS= read -r f; do
            line=$(tail -c 300000 "$f" 2>/dev/null | grep '"used_percent"' | tail -1)
            if [ -n "$line" ]; then
                printf '@codex\n%s\n' "$line"
                break
            fi
        done
    fi

    # Our own capture, or flare's when that is what the user has.
    best=""
    bestm=0
    for c in "$state/desktop-widget-control/claude-statusline.json" "$state/flare/claude-statusline.json"; do
        [ -r "$c" ] || continue
        m=$(stat -c %Y "$c" 2>/dev/null) || continue
        if [ "$m" -gt "$bestm" ]; then
            best=$c
            bestm=$m
        fi
    done
    if [ -n "$best" ]; then
        printf '@claude-capture %s\n' "$bestm"
        head -c 65536 "$best"
        printf '\n'
    fi
    exit 0
fi

if [ "$mode" = api ]; then
    creds=${CLAUDE_CONFIG_DIR:-$HOME/.claude}/.credentials.json
    [ -r "$creds" ] || { echo "@claude-api-none"; exit 0; }
    token=$(sed -n 's/.*"accessToken"[[:space:]]*:[[:space:]]*"\([^"]*\)".*/\1/p' "$creds" | head -1)
    exp=$(sed -n 's/.*"expiresAt"[[:space:]]*:[[:space:]]*\([0-9]*\).*/\1/p' "$creds" | head -1)
    [ -n "$token" ] || { echo "@claude-api-none"; exit 0; }
    # An expired token is not sent: the endpoint answers it with a long 429.
    if [ -n "$exp" ] && [ "$exp" -le $((now * 1000)) ]; then
        echo "@claude-api-expired"
        exit 0
    fi
    # The token goes in on stdin, not on the command line where `ps` would show it.
    # The answer goes to a file so curl's own exit status is the one we test (in a pipe it
    # would be head's), then is cut to the byte cap.
    raw=$(mktemp) || { echo "@claude-api-failed"; exit 0; }
    trap 'rm -f "$raw"' EXIT
    if ! printf 'Authorization: Bearer %s\n' "$token" |
        curl -fsS --proto '=https' --max-time 10 --max-filesize 65536 -H @- -H 'anthropic-beta: oauth-2025-04-20' -H 'Accept: application/json' \
            -o "$raw" https://api.anthropic.com/api/oauth/usage 2>/dev/null; then
        echo "@claude-api-failed"
        exit 0
    fi
    body=$(head -c 65536 "$raw")
    printf '@claude-api %s\n%s\n' "$now" "$body"
fi
