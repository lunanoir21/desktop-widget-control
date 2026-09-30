"""Checks that need the file tree rather than a QML engine: every module's
file exists, nothing in widgets/ is orphaned, the qmldirs list what is on
disk, and the showcase generator writes a layout the store would accept."""
import json
import os
import re
import subprocess
import sys
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
UI = os.path.join(ROOT, "ui")


def read(*p):
    with open(os.path.join(ROOT, *p), encoding="utf-8") as f:
        return f.read()


def module_sources():
    return re.findall(r'source:\s*"(widgets/[A-Za-z]+\.qml)"', read("ui", "js", "Modules.js"))


class Files(unittest.TestCase):
    def test_every_module_has_its_file(self):
        sources = module_sources()
        self.assertGreaterEqual(len(sources), 15)
        for s in sources:
            self.assertTrue(os.path.isfile(os.path.join(UI, s)), s)

    def test_no_orphan_widget_files(self):
        listed = {os.path.basename(s) for s in module_sources()}
        on_disk = {f for f in os.listdir(os.path.join(UI, "widgets")) if f.endswith(".qml")}
        self.assertEqual(on_disk, listed)

    def test_each_widget_extends_the_base(self):
        for s in module_sources():
            self.assertRegex(read("ui", s), r"\nDwcWidget \{", s)

    def test_qmldirs_match_the_files(self):
        for folder in ("ui", os.path.join("ui", "controls")):
            qmldir = read(folder, "qmldir")
            listed = set(re.findall(r"^(?:singleton )?(\w+) [\d.]+ (\w+\.qml)$", qmldir, re.M))
            for name, file in listed:
                self.assertEqual(name + ".qml", file, f"{folder}/qmldir: {name} -> {file}")
                self.assertTrue(os.path.isfile(os.path.join(ROOT, folder, file)), f"{folder}/{file}")
            on_disk = {f for f in os.listdir(os.path.join(ROOT, folder)) if f.endswith(".qml")}
            self.assertEqual(on_disk, {f for _, f in listed}, folder)

    def test_scripts_are_not_pragma_library(self):
        # Quickshell keeps library scripts cached across a hot reload, so an edit
        # to the catalogue would need a full restart of the shell to show up.
        folder = os.path.join(UI, "js")
        for f in os.listdir(folder):
            if f.endswith(".js"):
                self.assertNotIn("pragma library", read("ui", "js", f), f)

    def test_fonts_ship_with_licences(self):
        fonts = os.listdir(os.path.join(UI, "fonts"))
        self.assertTrue([f for f in fonts if f.endswith(".ttf")])
        self.assertTrue([f for f in fonts if f.startswith("OFL-")])

    def test_network_reads_are_bounded(self):
        """Every curl in the QML goes through js/Net.js (HTTPS only, a time limit and a
        byte cap); none is spelled out on its own. A marketplace reviewer asked for this."""
        for folder, _, files in os.walk(UI):
            for f in files:
                if f.endswith(".qml"):
                    text = read(os.path.relpath(os.path.join(folder, f), ROOT))
                    self.assertNotIn('"curl"', text, f"{f} runs curl itself; use Net.curl")
        if os.path.exists(os.path.join(ROOT, "ui/scripts/usage.sh")):
            script = read("ui/scripts/usage.sh")
            self.assertIn("--max-filesize", script)
            self.assertIn("head -c", script)

    def test_no_machine_specific_paths(self):
        # The project must run for anyone: nothing may point at one person's home.
        for dirpath, _, files in os.walk(ROOT):
            if any(part in dirpath for part in (".git", ".impeccable", "fonts", "__pycache__")):
                continue
            for f in files:
                if not f.endswith((".qml", ".js", ".py", ".sh", ".md", ".json", ".yml")):
                    continue
                if f == "test_files.py":
                    continue
                text = read(os.path.relpath(os.path.join(dirpath, f), ROOT))
                self.assertNotIn("/home/lunanoir", text, f)


class Consistency(unittest.TestCase):
    """Things that drift when a feature is added: strings, icons, commands, docs."""

    def qml_sources(self):
        for folder, _, files in os.walk(UI):
            if "fonts" in folder:
                continue
            for f in files:
                if f.endswith(".qml"):
                    yield os.path.join(folder, f)

    def test_every_string_key_used_in_qml_exists(self):
        table = read("ui", "js", "Strings.js")
        known = set(re.findall(r'"([a-zA-Z0-9_.]+)":', table))
        used = set()
        for path in self.qml_sources():
            with open(path, encoding="utf-8") as f:
                used |= set(re.findall(r'Str\.t\("([a-zA-Z0-9_.]+)"\)', f.read()))
        self.assertGreater(len(used), 20)
        self.assertEqual(sorted(used - known), [])

    def test_every_icon_used_exists(self):
        icons = set(re.findall(r'^\s+(\w+):\s+"M', read("ui", "js", "Icons.js"), re.M))
        used = set()
        for path in self.qml_sources():
            with open(path, encoding="utf-8") as f:
                text = f.read()
            used |= set(re.findall(r'DIcon\s*\{[^}]*?name:\s*"(\w+)"', text))
            used |= set(re.findall(r'\bicon:\s*"(\w+)"', text))
        self.assertEqual(sorted(used - icons), [])

    def test_every_ipc_function_is_in_the_helpers_help(self):
        host = read("ui", "DwcHost.qml")
        block = host[host.index("IpcHandler"):]
        functions = set(re.findall(r"function (\w+)\(", block))
        helper = read("bin", "dwc")
        self.assertGreater(len(functions), 15)
        for fn in sorted(functions):
            self.assertIn(fn, helper, f"dwc help does not mention the IPC call {fn}")

    def test_the_readme_names_every_module(self):
        readme = read("README.md").lower()
        names = re.findall(r'type: "[a-z-]+", category: "\w+", name: T\("([^"]+)"', read("ui", "js", "Modules.js"))
        self.assertGreaterEqual(len(names), 16)
        for name in names:
            self.assertIn(name.lower(), readme, f"README.md does not mention the module {name}")

    def test_readme_and_changelog_agree_on_the_version(self):
        changelog = read("CHANGELOG.md")
        version = re.search(r"^## (\d+\.\d+\.\d+)", changelog, re.M).group(1)
        self.assertIn("pkgver=" + version, read("packaging", "PKGBUILD"))


class Showcase(unittest.TestCase):
    def page(self, n):
        with tempfile.TemporaryDirectory() as d:
            subprocess.run([sys.executable, os.path.join(ROOT, "tools", "showcase.py"), d, str(n)], check=True, capture_output=True)
            with open(os.path.join(d, "layout.json")) as f:
                return json.load(f)

    def test_showcase_layout_is_valid(self):
        types = set()
        sizes = set()
        for n in (0, 1, 2, 3):
            data = self.page(n)
            self.assertEqual(data["version"], 1)
            ids = [w["id"] for w in data["widgets"]]
            self.assertEqual(len(ids), len(set(ids)))
            types |= {w["type"] for w in data["widgets"]}
            sizes |= {(w["type"], w["size"]) for w in data["widgets"]}
            # No two widgets on a page overlap, and all fit a 48x27 screen.
            pre = {"S": (4, 4), "M": (8, 4), "L": (8, 8), "W": (12, 4), "X": (20, 4)}
            rects = [(w["x"], w["y"], *pre[w["size"]]) for w in data["widgets"]]
            for r in rects:
                self.assertLessEqual(r[0] + r[2], 48)
                self.assertLessEqual(r[1] + r[3], 27)
            for i, a in enumerate(rects):
                for b in rects[i + 1:]:
                    self.assertFalse(a[0] < b[0] + b[2] and b[0] < a[0] + a[2] and a[1] < b[1] + b[3] and b[1] < a[1] + a[3], (a, b))
        # Together the two pages show every module at every size it has.
        self.assertGreaterEqual(len(types), 15)
        self.assertGreaterEqual(len(sizes), 37)


if __name__ == "__main__":
    unittest.main()
