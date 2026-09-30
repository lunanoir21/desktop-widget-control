#!/usr/bin/env python3
"""Write a layout.json that shows every module at every size it supports.

Used to look over all the widgets at once (and in the tests' screenshots):

    tools/showcase.py DIR [PAGE]     # DIR/layout.json; PAGE 0 or 1 when it does not all fit one screen
    DWC_CONFIG_DIR=DIR quickshell -p .

The module list and sizes are read from ui/js/Modules.js and Layout.js, so a
new module shows up here without touching this file.
"""
import json
import os
import re
import subprocess
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PRESETS = {"S": (4, 4), "M": (8, 4), "L": (8, 8), "W": (12, 4), "X": (20, 4)}


def modules():
    """[(type, [sizes])] from Modules.js, read by node-free regex so it needs nothing installed."""
    src = open(os.path.join(ROOT, "ui/js/Modules.js")).read()
    out = []
    for m in re.finditer(r'type:\s*"([a-z-]+)",\s*category.*?sizes:\s*\[([^\]]*)\]', src, re.S):
        out.append((m.group(1), re.findall(r'"([SMLWX])"', m.group(2))))
    return out


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    outdir = sys.argv[1]
    page = int(sys.argv[2]) if len(sys.argv) > 2 else 0
    cols, rows = 48, 27
    items = [(t, s) for t, sizes in modules() for s in sizes]
    pages, cur, x, y, rowh = [], [], 0, 0, 0
    for t, s in items:
        w, h = PRESETS[s]
        if x + w > cols:
            x, y, rowh = 0, y + rowh, 0
        if y + h > rows:
            pages.append(cur)
            cur, x, y, rowh = [], 0, 0, 0
        cur.append({"id": f"{t}-{s}", "type": t, "size": s, "x": x, "y": y, "screen": "", "locked": False,
                    "cfg": {"city": "Istanbul"} if t == "weather" else {}, "st": {}})
        x += w
        rowh = max(rowh, h)
    pages.append(cur)
    os.makedirs(outdir, exist_ok=True)
    with open(os.path.join(outdir, "layout.json"), "w") as f:
        json.dump({"version": 1, "theme": "moss", "language": "en", "cell": 40, "widgets": pages[page % len(pages)]}, f)
    print(f"{len(items)} widgets, {len(pages)} page(s); wrote page {page % len(pages)}")


main()
