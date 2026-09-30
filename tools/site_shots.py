#!/usr/bin/env python3
"""Make the screenshots for the README and the GitHub Pages site.

    tools/site_shots.py [THEME ...]      # default: every theme

One widget at a time, cropped to the widget: players first, then the clocks, then
the rest, and the editor and the tour last. For each theme it writes
docs/screenshots/<theme>/<name>.webp (the weather is Istanbul, the language English).
If another Desktop Widget Control of yours runs, pass --hide "<quickshell args>" so it
is hidden meanwhile. It runs its own instance in a throwaway config dir, on an empty Hyprland
workspace, and puts you back on your workspace afterwards. Needs quickshell,
grim, hyprctl, jq and ImageMagick. Do not touch the mouse while it runs.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "docs", "screenshots")

ISTANBUL = {"name": "Istanbul", "admin": "Istanbul", "country": "Türkiye", "cc": "TR", "lat": 41.0138, "lon": 28.9497}
CELL = 40
AT = (12, 8)  # grid cell of the widget being shot (clear of any bar)
SIZES = {"S": (4, 4), "M": (8, 4), "L": (8, 8), "W": (12, 4), "X": (20, 4)}

# (file name, type, size, cfg)
PLAYERS = [("media-" + s, "media", s, {"look": "card"}) for s in "SML"] + [
    ("media-wide", "media", "W", {"look": "wide"}), ("media-pill", "media", "X", {"look": "pill"}),
    ("media-scope", "media", "X", {"look": "scope"}), ("media-wide-x", "media", "X", {"look": "wide"})]
CLOCKS = [
    ("clock-led-classic", "clock-led", "M", {"design": "classic"}), ("clock-led-ring", "clock-led", "M", {"design": "ring"}),
    ("clock-led-strip", "clock-led", "W", {"design": "strip"}), ("clock-analog", "clock-analog", "M", {}),
    ("clock-serif", "clock-serif", "M", {}), ("clock-poster-classic", "clock-poster", "W", {"design": "classic"}),
    ("clock-poster-cut", "clock-poster", "W", {"design": "cut"}), ("clock-poster-sign", "clock-poster", "W", {"design": "sign"}),
    ("clock-mono", "clock-mono", "M", {}), ("clock-world", "clock-world", "M", {})]
OTHERS = [
    ("cpu-graph", "cpu-graph", "M", {}), ("ram-ring", "ram-ring", "M", {}), ("disk", "disk", "M", {}),
    ("net", "net", "M", {}), ("temp-gauge", "temp-gauge", "S", {}),
    ("calendar", "calendar", "L", {}), ("weather", "weather", "M", {"place": ISTANBUL}),
    ("pomodoro", "pomodoro", "S", {}), ("notes", "notes", "M", {})]


def sh(*a, **k):
    return subprocess.run(a, capture_output=True, text=True, **k)


def theme_ids():
    with open(os.path.join(ROOT, "ui", "js", "Themes.js"), encoding="utf-8") as f:
        return re.findall(r'\{ id: "(\w+)"', f.read())


def main():
    args = sys.argv[1:]
    hide = []
    if "--hide" in args:
        i = args.index("--hide")
        hide = args[i + 1].split()
        del args[i:i + 2]
    themes = args or theme_ids()
    cfg = tempfile.mkdtemp(prefix="dwc-shots-")
    with open(os.path.join(cfg, "layout.json"), "w") as f:
        json.dump({"version": 1, "theme": themes[0], "language": "en", "cell": CELL, "onboarded": True, "widgets": []}, f)

    ipc = lambda *a: sh("quickshell", "-p", ROOT, "ipc", "call", "desktopWidgets", *a)
    back = json.loads(sh("hyprctl", "activeworkspace", "-j").stdout)["id"]
    mon = next(m["name"] for m in json.loads(sh("hyprctl", "monitors", "-j").stdout) if m["focused"])
    proc = None
    try:
        if hide:
            sh("quickshell", *hide, "ipc", "call", "desktopWidgets", "hide")
        sh("hyprctl", "dispatch", "workspace", "empty")
        time.sleep(0.8)
        proc = subprocess.Popen(["quickshell", "-p", ROOT], env=dict(os.environ, DWC_CONFIG_DIR=cfg),
                                stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        time.sleep(8)
        tmp = tempfile.mkdtemp(prefix="dwc-png-")

        def save(t, name, crop=None):
            d = os.path.join(OUT, t)
            os.makedirs(d, exist_ok=True)
            png = os.path.join(tmp, name + ".png")
            sh("grim", *(["-g", crop] if crop else ["-o", mon]), png)
            sh("magick", png, "-resize", "1600x>", "-quality", "86", os.path.join(d, name + ".webp"))
            print(t, name, flush=True)

        def widgets():
            try:
                return json.loads(ipc("list").stdout)["widgets"]
            except ValueError:
                return []

        def clear():
            for w in widgets():
                ipc("remove", w["id"])

        def one(t, name, typ, size, conf):
            clear()
            ipc("add", typ, size)
            wid = widgets()[0]["id"]
            ipc("move", wid, str(AT[0]), str(AT[1]))
            for k, v in conf.items():
                ipc("set", wid, k, json.dumps(v))
            cols, rows = SIZES[size]
            m = 24
            geo = "%d,%d %dx%d" % (AT[0] * CELL - m, AT[1] * CELL - m, cols * CELL + 2 * m, rows * CELL + 2 * m)
            time.sleep(3.5 if typ in ("media", "weather") else 2)
            save(t, name, geo)

        for phase in (PLAYERS, CLOCKS, OTHERS):
            for t in themes:
                ipc("theme", t)
                for name, typ, size, conf in phase:
                    one(t, name, typ, size, conf)
        # the editor and the tour last, with one media widget in it
        clear()
        ipc("add", "media", "X"); wid = widgets()[0]["id"]
        ipc("set", wid, "look", json.dumps("pill")); ipc("center", wid, "both")
        for t in themes:
            ipc("theme", t)
            ipc("edit"); ipc("select", wid)
            time.sleep(2.5)
            save(t, "editor")
            ipc("done")
            ipc("tour", "3")
            time.sleep(2.5)
            save(t, "tour")
            ipc("done")
    finally:
        if proc:
            proc.terminate()
        sh("hyprctl", "dispatch", "workspace", str(back))
        if hide:
            sh("quickshell", *hide, "ipc", "call", "desktopWidgets", "unhide")
        shutil.rmtree(cfg, ignore_errors=True)


if __name__ == "__main__":
    main()
