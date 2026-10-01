#!/bin/sh
# Install Desktop Widget Control for the current user, in one go.
#
#   curl -fsSL https://raw.githubusercontent.com/lunanoir21/desktop-widget-control/main/install.sh | sh
#
# or from a checkout:   ./install.sh
#
# What it does:
#   - gets the code (this checkout, or a fresh clone in ~/.local/share/desktop-widget-control)
#   - links it where Quickshell looks:  ~/.config/quickshell/desktop-widget-control
#   - puts the `dwc` helper in ~/.local/bin, and an app-launcher entry with an icon
#   - on Hyprland, offers to add the autostart line and a key (Super+G) to your config
#   - starts it, and the first-run tour opens
# It never touches your compositor config without asking (or --autostart), and
# `--dry-run` shows everything it would do without doing any of it.
#
# Options:
#   --copy          copy the files instead of linking to the checkout
#   --autostart     add the autostart line and the key binding (Hyprland) without asking
#   --no-autostart  never touch the compositor config
#   --no-start      do not start it at the end
#   --ref REF       branch or tag to fetch when not run from a checkout (default: main)
#   --dry-run       print what would happen
#   --uninstall     remove everything this script added (your layout stays)
#   -y, --yes       answer yes to every question
set -eu

REPO="lunanoir21/desktop-widget-control"
REF="main"
MODE="link"
AUTOSTART=ask
START=yes
DRY=no
UNINSTALL=no
YES=no

while [ $# -gt 0 ]; do
    case "$1" in
        --copy) MODE=copy ;;
        --autostart) AUTOSTART=yes ;;
        --no-autostart) AUTOSTART=no ;;
        --no-start) START=no ;;
        --ref) REF=${2:?--ref needs a value}; shift ;;
        --dry-run) DRY=yes ;;
        --uninstall) UNINSTALL=yes ;;
        -y|--yes) YES=yes ;;
        -h|--help) sed -n '2,27p' "$0"; exit 0 ;;
        *) echo "unknown option: $1 (try --help)" >&2; exit 1 ;;
    esac
    shift
done

# The ref ends up in a git command and a URL: a plain branch or tag name only.
case $REF in
    ""|-*|*..*|*[!A-Za-z0-9._/-]*) echo "invalid --ref: $REF" >&2; exit 1 ;;
esac

CONFIG_HOME=${XDG_CONFIG_HOME:-$HOME/.config}
DATA_HOME=${XDG_DATA_HOME:-$HOME/.local/share}
BIN_DIR=${XDG_BIN_HOME:-$HOME/.local/bin}
TARGET=$CONFIG_HOME/quickshell/desktop-widget-control
CHECKOUT=$DATA_HOME/desktop-widget-control
SNIPPET_DIR=$CONFIG_HOME/desktop-widget-control
MARK="# desktop-widget-control"

say()  { printf '%s\n' "$*"; }
step() { printf '\033[1m==>\033[0m %s\n' "$*"; }
warn() { printf 'warning: %s\n' "$*" >&2; }
run()  { if [ "$DRY" = yes ]; then printf '  (dry run) %s\n' "$*"; else "$@"; fi; }

# A yes/no question. Without a terminal to ask on (a piped install, a dry run)
# the answer is no, so nothing outside our own folders changes unasked.
ask() {
    [ "$YES" = yes ] && return 0
    if [ "$DRY" = yes ] || [ ! -r /dev/tty ]; then
        return 1
    fi
    printf '%s [%s] ' "$1" "$([ "$2" = y ] && echo Y/n || echo y/N)" > /dev/tty
    # No answer (end of input, no real terminal behind /dev/tty) is a no.
    read -r reply < /dev/tty || return 1
    case "$reply" in
        [Yy]*) return 0 ;;
        [Nn]*) return 1 ;;
        *) [ "$2" = y ] ;;
    esac
}

here=""
# Run from a checkout ($0 is the script's own path). Piped into sh, $0 is just "sh".
if [ -f "$0" ]; then
    d=$(cd "$(dirname "$0")" 2>/dev/null && pwd) || d=""
    if [ -n "$d" ] && [ -f "$d/shell.qml" ] && [ -d "$d/ui" ]; then here=$d; fi
fi

# ---- uninstall -------------------------------------------------------------
if [ "$UNINSTALL" = yes ]; then
    step "removing Desktop Widget Control"
    run rm -rf "$TARGET" "$BIN_DIR/dwc"
    run rm -f "$DATA_HOME/applications/desktop-widget-control.desktop" \
              "$DATA_HOME/icons/hicolor/scalable/apps/desktop-widget-control.svg"
    HCONF=$CONFIG_HOME/hypr/hyprland.conf
    if [ -f "$HCONF" ] && grep -q "$MARK" "$HCONF"; then
        run sed -i "/$MARK/d" "$HCONF"
        say "removed the lines it added to $HCONF"
    fi
    run rm -f "$SNIPPET_DIR/hyprland.conf"
    [ -d "$CHECKOUT/.git" ] && say "the downloaded copy is still in $CHECKOUT (delete it if you like)"
    say "your layout stays in $SNIPPET_DIR/layout.json"
    exit 0
fi

# ---- 1. requirements -------------------------------------------------------
step "checking requirements"
if ! command -v quickshell >/dev/null 2>&1; then
    cat >&2 <<'MSG'
Quickshell is not installed, and Desktop Widget Control is a Quickshell config.
  Arch / Omarchy:  sudo pacman -S quickshell     (or:  yay -S quickshell-git)
  Others:          https://quickshell.org/docs/guide/install-setup/
Install it, then run this again.
MSG
    [ "$DRY" = yes ] || exit 1
fi
say "quickshell: $(command -v quickshell 2>/dev/null || echo 'missing (dry run continues)')"
for opt in curl cava notify-send; do
    if command -v "$opt" >/dev/null 2>&1; then
        say "$opt: found"
    else
        case "$opt" in
            curl) say "curl: not found (the weather widget needs it)" ;;
            cava) say "cava: not found (optional: the music visualizer)" ;;
            notify-send) say "notify-send: not found (optional: pomodoro notifications)" ;;
        esac
    fi
done

# ---- 2. the code -----------------------------------------------------------
if [ -n "$here" ]; then
    SRC=$here
    step "using the checkout at $SRC"
else
    SRC=$CHECKOUT
    step "downloading Desktop Widget Control ($REF) to $SRC"
    if command -v git >/dev/null 2>&1; then
        if [ -d "$SRC/.git" ]; then
            run git -C "$SRC" fetch --quiet --depth 1 origin "$REF"
            run git -C "$SRC" checkout --quiet FETCH_HEAD
        else
            run rm -rf "$SRC"
            run git clone --quiet --depth 1 --branch "$REF" "https://github.com/$REPO.git" "$SRC"
        fi
    elif command -v curl >/dev/null 2>&1 && command -v tar >/dev/null 2>&1; then
        run rm -rf "$SRC"
        run mkdir -p "$SRC"
        if [ "$DRY" = yes ]; then
            say "  (dry run) curl -fsSL https://github.com/$REPO/archive/$REF.tar.gz | tar -xz -C $SRC --strip-components=1"
        else
            # To a file first: in a pipe a failed download would be hidden behind tar's status.
            ARCHIVE=$(mktemp) || exit 1
            trap 'rm -f "$ARCHIVE"' EXIT
            curl -fsSL -o "$ARCHIVE" "https://github.com/$REPO/archive/$REF.tar.gz"
            tar -xzf "$ARCHIVE" -C "$SRC" --strip-components=1
        fi
    else
        echo "need git, or curl and tar, to download the code" >&2
        exit 1
    fi
fi

# ---- 3. link it in ---------------------------------------------------------
step "installing"
run mkdir -p "$CONFIG_HOME/quickshell" "$BIN_DIR" "$DATA_HOME/applications" "$DATA_HOME/icons/hicolor/scalable/apps"
run rm -rf "$TARGET"
if [ "$MODE" = copy ]; then
    run mkdir -p "$TARGET"
    run cp -r "$SRC/shell.qml" "$SRC/ui" "$TARGET/"
else
    run ln -s "$SRC" "$TARGET"
fi
say "shell:   $TARGET"
run ln -sf "$SRC/bin/dwc" "$BIN_DIR/dwc"
say "helper:  $BIN_DIR/dwc"
run cp "$SRC/packaging/desktop-widget-control.desktop" "$DATA_HOME/applications/desktop-widget-control.desktop"
run cp "$SRC/assets/icon.svg" "$DATA_HOME/icons/hicolor/scalable/apps/desktop-widget-control.svg"
if command -v update-desktop-database >/dev/null 2>&1; then
    run update-desktop-database "$DATA_HOME/applications" 2>/dev/null || true
fi
say "launcher: Desktop Widget Control (in your app menu)"
case ":$PATH:" in
    *":$BIN_DIR:"*) ;;
    *) warn "$BIN_DIR is not on your PATH; add it so the dwc command works" ;;
esac

# ---- 4. autostart and a key ------------------------------------------------
detect_compositor() {
    if [ -n "${HYPRLAND_INSTANCE_SIGNATURE:-}" ] || [ "${XDG_CURRENT_DESKTOP:-}" = Hyprland ]; then echo hyprland
    elif [ -n "${SWAYSOCK:-}" ]; then echo sway
    elif [ -n "${NIRI_SOCKET:-}" ]; then echo niri
    else echo unknown; fi
}
COMP=$(detect_compositor)
KEY="${DWC_KEY:-SUPER, G}"

case "$COMP" in
    hyprland)
        HCONF=$CONFIG_HOME/hypr/hyprland.conf
        SNIP=$SNIPPET_DIR/hyprland.conf
        if [ -f "$HCONF" ] && grep -q "desktop-widget-control" "$HCONF" 2>/dev/null; then
            say "Hyprland: already set up in $HCONF"
        elif [ "$AUTOSTART" != no ] && [ -f "$HCONF" ] && { [ "$AUTOSTART" = yes ] || ask "Start it with Hyprland and bind $KEY to the editor? (adds 2 lines to $HCONF)" y; }; then
            run mkdir -p "$SNIPPET_DIR"
            if [ "$DRY" = no ]; then
                cat > "$SNIP" <<EOF2
# Desktop Widget Control: start it with the session and open the editor with a key.
exec-once = quickshell -c desktop-widget-control
bind = $KEY, exec, dwc toggle
EOF2
            fi
            run sh -c 'printf "%s\n" "$1" >> "$2"' sh "source = $SNIP $MARK" "$HCONF"
            say "Hyprland: added the autostart and $KEY to $HCONF (through $SNIP)"
        else
            say "Hyprland: to start it with the session, add to hyprland.conf:"
            say "    exec-once = quickshell -c desktop-widget-control"
            say "    bind = $KEY, exec, dwc toggle"
        fi
        ;;
    sway)
        say "Sway: add to your config:"
        say "    exec quickshell -c desktop-widget-control"
        say "    bindsym \$mod+g exec dwc toggle"
        ;;
    niri)
        say "niri: add to config.kdl:"
        say "    spawn-at-startup \"quickshell\" \"-c\" \"desktop-widget-control\""
        say "    binds { Mod+G { spawn \"dwc\" \"toggle\"; } }"
        ;;
    *)
        say "To start it with your session, run  quickshell -c desktop-widget-control  from its autostart,"
        say "and bind a key to  dwc toggle  to open the editor."
        ;;
esac

# ---- 5. start it -----------------------------------------------------------
if [ "$START" = yes ]; then
    if command -v quickshell >/dev/null 2>&1 && [ -n "${WAYLAND_DISPLAY:-}" ]; then
        if quickshell -c desktop-widget-control ipc call desktopWidgets status >/dev/null 2>&1; then
            say "it is already running; run  dwc restart  to load the new version"
        elif [ "$DRY" = yes ]; then
            say "  (dry run) quickshell -c desktop-widget-control &"
        else
            step "starting it"
            nohup quickshell -c desktop-widget-control >/dev/null 2>&1 &
        fi
    else
        say "start it from your desktop session with:  quickshell -c desktop-widget-control"
    fi
fi

cat <<'DONE'

Done.
  dwc toggle   open the editor (Esc or Done closes it)
  dwc help     every command
  dwc tour     the first-run tour again
DONE
