"""The GitHub Pages site (docs/index.html): every local link and image exists,
the theme list is the project's, both languages are present everywhere, and
every theme has its screenshots. Run by tests/run.sh and by the `site` CI job.

    python3 tests/check_site.py
"""
import os
import re
import sys
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DOCS = os.path.join(ROOT, "docs")
SHOTS = ("editor", "tour", "media-pill", "media-scope", "clock-led-ring", "clock-poster-cut", "weather", "cpu-graph")


def read(*p):
    with open(os.path.join(ROOT, *p), encoding="utf-8") as f:
        return f.read()


class Site(unittest.TestCase):
    html = read("docs", "index.html")

    def test_local_links_and_images_exist(self):
        refs = re.findall(r'(?:href|src)="([^"#:]+?)"', self.html)
        self.assertGreater(len(refs), 4)
        for ref in refs:
            if ref.startswith(("http", "mailto", "//")) or ref.startswith("screenshots/"):
                continue
            self.assertTrue(os.path.exists(os.path.join(DOCS, ref.split("?")[0])), f"docs/{ref} is missing")

    def test_fonts_referenced_in_css_exist(self):
        for ref in re.findall(r'url\("(fonts/[^"]+)"\)', self.html):
            self.assertTrue(os.path.isfile(os.path.join(DOCS, ref)), ref)

    def test_the_themes_are_the_projects_themes(self):
        site = re.findall(r"\{ id: '(\w+)', name: '(\w+)', dark: (true|false), card: '(#\w+)', alt: '(#\w+)', fg: '(#\w+)', sub: '(#\w+)', muted: '(#\w+)', acc: '(#\w+)', onAcc: '(#\w+)', acc2: '(#\w+)', track: '(#\w+)'", self.html)
        proj = re.findall(r'\{ id: "(\w+)",\s+name: "(\w+)",\s+dark: (true|false),\s+card: "(#\w+)", alt: "(#\w+)", fg: "(#\w+)", sub: "(#\w+)", muted: "(#\w+)", acc: "(#\w+)", onAcc: "(#\w+)", acc2: "(#\w+)", track: "(#\w+)"', read("ui", "js", "Themes.js"))
        self.assertEqual(len(proj), 9)
        self.assertEqual(site, proj)

    def test_every_english_span_has_a_turkish_one(self):
        self.assertEqual(self.html.count("<span data-en>"), self.html.count("<span data-tr>"))

    def test_the_install_command_matches_the_installer(self):
        self.assertIn("raw.githubusercontent.com/lunanoir21/desktop-widget-control/main/install.sh", self.html)
        self.assertIn("lunanoir21/desktop-widget-control", read("install.sh"))

    def test_every_module_is_on_the_page(self):
        names = re.findall(r'type: "[a-z-]+", category: "\w+", name: T\("([^"]+)"', read("ui", "js", "Modules.js"))
        page = self.html.lower()
        for n in names:
            self.assertIn(n.lower(), page, n)

    def test_every_shot_the_page_uses_exists_for_every_theme(self):
        used = set(re.findall(r'data-shot="([\w-]+)"', self.html))
        themes = re.findall(r'\{ id: "(\w+)"', read("ui", "js", "Themes.js"))
        for t in themes:
            for u in used:
                self.assertTrue(os.path.isfile(os.path.join(DOCS, "screenshots", t, u + ".webp")), f"{t}/{u}")

    def test_every_theme_has_its_screenshots(self):
        themes = re.findall(r'\{ id: "(\w+)"', read("ui", "js", "Themes.js"))
        missing = [f"screenshots/{t}/{s}.webp" for t in themes for s in SHOTS
                   if not os.path.isfile(os.path.join(DOCS, "screenshots", t, s + ".webp"))]
        self.assertEqual(missing, [], "run tools/site_shots.py to (re)make the screenshots")


if __name__ == "__main__":
    unittest.main(argv=[sys.argv[0]])
