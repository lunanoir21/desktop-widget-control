# Changelog

## 0.2.1 — 2026-10-01

- Outside text is always literal. `DText`, the one text control every widget uses, now sets `textFormat: Text.PlainText`, so a track title, artist or any other string that carries HTML (an `<img>` tag, say) is drawn as written instead of making the shell fetch a URL. A test fails if a QML file builds a bare `Text` or turns rich text on.
- Cover art is read from local files only. A media player's `http(s)` cover URL is no longer fetched; players that save the cover to a file (most browsers, Spotify's local cache) still show it.
- The weather request rounds the coordinates it got back from the geocoder to plain numbers before they go into the URL. (Thanks again to the marketplace reviewer.)
- Hardening found by a full review of the same class of problem:
  - The spectrum widget no longer writes its cava config to a fixed `/tmp` name (a pre-made symlink could have made it overwrite a file): it uses a private `mktemp` file and removes it once cava has read it.
  - The layout file is capped at 2 MiB when read, the layout folder is `0700` and the file `0600` (it holds your notes and places), one option's text is capped at 20,000 characters, and a checklist builds at most 300 rows. Text boxes have length limits too.
  - The Claude usage request reports a failed `curl` as failed (the old pipe reported the status of `head`).
  - `install.sh`: `--ref` accepts only a plain branch or tag name, the Hyprland line is written without splicing paths into a shell string, and the archive download is checked before it is unpacked.

## 0.2.0 — 2026-10-01

- New module: *AI limits*, the 5-hour and weekly limits of Claude and Codex as twin rings (outer = 5 hours, inner = week) or LED dots, red above a warning level you set. Codex is read from its own session logs; Claude from a capture of Claude Code's status line (`ui/scripts/claude-statusline.sh`, no network) or, as an opt-in, from the usage endpoint. Numbers that are old say how old; a window whose reset time has passed reads empty.
- The Claude and OpenAI marks are drawn from Simple Icons (CC0); they are trademarks of their owners and the project is not affiliated with either.

## 0.1.3 — 2026-10-01

- Network reads are bounded. The weather widget and the city search now run `curl` through one helper (`ui/js/Net.js`): HTTPS only, a time limit, and a hard cap of 128 KiB on what is read back, enforced by `head -c` so a server that streams without a length is cut off too. The forecast keeps at most 7 days and a city search at most 8 results. A test fails if any QML file runs `curl` on its own. (Thanks to the marketplace reviewer who pointed this out.)

## 0.1.2 — 2026-10-01

- The tour's shortcut offer has a *Choose key…* button: hold your keys (Super, Ctrl, Alt, Shift and a letter, number or F-key), see them live, press Esc to save. If the key is taken nothing is written and it says so.
- `ui/scripts/bind.sh` takes the key as arguments (`sh bind.sh SUPER_ALT A`), asks for it in a terminal, or picks a free one (`auto`); it writes Lua or `.conf` syntax to match the config, refuses keys that are bound already and anything that is not a modifier plus a plain key.

## 0.1.1 — 2026-10-01

- The first-run tour offers to add the editor key on Hyprland (`SUPER + G`, or `SUPER SHIFT + G` / `SUPER ALT + G` when that one is taken): one button, nothing is touched until it is pressed. The line is appended to `bindings.conf` (Omarchy) or `hyprland.conf`; a Lua config (`hyprland.lua` / `bindings.lua`) gets a Lua line instead. The work is `ui/scripts/bind.sh`, which can also be run by hand. This is the prompt for installs that have no installer to ask, such as the Omarchy plugin.
- The site's screenshots swap instantly (they are fetched ahead), and the logo and favicon take the theme's colours.

## 0.1.0 — 2026-09-30

First version.

- Sixteen modules: six clocks (LED pixel, analog, serif, poster, mono with seconds, world), five system monitors (CPU graph, RAM ring, disk, network, temperature), a media player for any MPRIS player, a calendar, weather from Open-Meteo, a pomodoro timer and a checklist. Most come in several sizes (S, M, L, W).
- The editor: a widget library with live thumbnails, drag and drop onto a snapping grid, resizing by preset, an inspector built from each module's options, duplicate, lock, delete, arrow-key nudging, panels that slide out of the way while you drag and open on the side away from the widget being edited, a top bar to bring them back, and a key (Tab) to hide them.
- The weather widget has a place picker: choose a country (or any), type a city and pick it from what Open-Meteo finds; older layouts that stored a plain city name keep working.
- The poster clock is a lock-screen look in three styles: classic (the weekday in large spaced capitals, the date and a small time under it), cut letters (the weekday sliced across the middle) and sign (an outlined weekday over a strip of date, week, day of the year and time; narrow cards keep the date and the time). Modules can now start with their own appearance (it starts without a card).
- Styles: the LED clock has classic, ring (a dotted ring that fills with the seconds or the minutes) and day strip (the week's days and the day's 24 hours); the CPU graph and the network widget draw btop-style bars by default (colour follows the load, the CPU scale adapts to recent peaks) with the old lines as a style.
- The media player has a live audio visualizer fed by `cava`: the progress bar itself becomes the spectrum (played bars lit, the rest faint), or a soft spectrum rises behind the card, which only runs while music plays and is skipped when cava is not installed.
- The media player has a *Wide strip* style (cover, text, a long spectrum progress bar and big transport buttons in one row) and a new extra-wide size X (20×4 cells); clicking the progress bar seeks. Any widget can be put in the exact middle of the screen with the inspector's *Centre* buttons or `dwc center`.
- Options can depend on another (`when` in the catalogue): the ring's "shows" choice only appears for the ring style.
- Nine themes (text contrast checked by the tests) and Turkish and English.
- Data sources run only while a widget needs them and are shared; the desktop surface is click-through except for widgets that have buttons.
- IPC (`desktopWidgets`) and the `dwc` helper for everything the editor does; the layout is one JSON file that is reloaded when edited by hand.
- Runs on its own (`quickshell -c desktop-widget-control`) or inside an existing shell with one `DwcHost {}`. Fonts are bundled.
- `dwc hide` / `dwc unhide` hide and bring back every widget (hidden widgets also stop reading data).
- Saved layouts are repaired on load: a widget that is off-screen or sits on another is moved to the nearest free spot.
- The media player has two more looks for the extra-wide size: *Pill* (a rounded capsule with a ringed cover and the spectrum in the middle) and *Oscilloscope* (a live trace in place of the bars).
- A first-run tour (six steps: edit, drag, style, theme, done) opens on the first start; `dwc tour` brings it back.
- One-line installer (`install.sh`, also `--uninstall`, `--dry-run`), the `dwc start/stop/restart` commands, an app-menu entry and icon, an Arch `PKGBUILD`, and the Mozaik logo.
- A GitHub Pages site with a theme picker whose screenshots follow the theme, and screenshot tooling (`tools/site_shots.py`).
- GitHub Actions: tests, shellcheck, an installer end-to-end run, a site check, Pages deployment and tagged releases.
- Tests: `tests/run.sh` (layout maths, module catalogue, strings, theme contrast, icons, file-tree checks), run by GitHub Actions on every push.
