"""The script that downloads an album cover a player named: only the allowed image hosts are
fetched, only a real image is kept, the cache is private, and the host list in the script is
the one in js/Cover.js."""
import os
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "ui", "scripts", "cover.sh")
OK = "https://i.scdn.co/image/ab67616d0000b273b1f99ea4d9bf47dd43ad600f"

FAKE = r"""#!/bin/sh
out=""; url=""
echo "$*" >> "$FIX/argv"
while [ $# -gt 0 ]; do
    case "$1" in
        -o) out=$2; shift 2 ;;
        -w) shift 2 ;;
        --max-time|--max-filesize|--proto) shift 2 ;;
        -*) shift ;;
        *) url=$1; shift ;;
    esac
done
echo "$url" >> "$FIX/asked"
[ -n "$out" ] && cp "$FIX/${BODY:-png}" "$out"
printf '%s' "${CODE:-200}"
"""


class Cover(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.mkdtemp()
        self.fix = os.path.join(self.home, "fix")
        self.bin = os.path.join(self.home, "bin")
        os.makedirs(self.fix)
        os.makedirs(self.bin)
        with open(os.path.join(self.bin, "curl"), "w") as f:
            f.write(FAKE)
        os.chmod(os.path.join(self.bin, "curl"), 0o755)
        for name, body in (("png", b"\x89PNG\r\n\x1a\n" + b"0" * 30), ("jpg", b"\xff\xd8\xff\xe0" + b"0" * 30),
                           ("webp", b"RIFF\x10\x00\x00\x00WEBPVP8 " + b"0" * 20), ("html", b"<html>not an image</html>")):
            with open(os.path.join(self.fix, name), "wb") as f:
                f.write(body)
        self.env = {"HOME": self.home, "PATH": self.bin + ":/usr/bin:/bin", "FIX": self.fix, "LANG": "C"}

    def tearDown(self):
        shutil.rmtree(self.home, ignore_errors=True)

    def run_script(self, url, env=None):
        e = dict(self.env)
        e.update(env or {})
        return subprocess.run(["sh", SCRIPT, url], env=e, capture_output=True, text=True).stdout.strip()

    def asked(self):
        p = os.path.join(self.fix, "asked")
        if not os.path.exists(p):
            return []
        with open(p) as f:
            return f.read().split()

    def test_an_allowed_cover_is_downloaded_into_the_private_cache(self):
        path = self.run_script(OK)
        self.assertTrue(path.startswith(os.path.join(self.home, ".cache", "desktop-widget-control", "covers")))
        self.assertTrue(os.path.isfile(path))
        self.assertEqual(oct(os.stat(path).st_mode & 0o777), "0o600")
        self.assertEqual(oct(os.stat(os.path.dirname(path)).st_mode & 0o777), "0o700")
        self.assertEqual(self.asked(), [OK])

    def test_the_same_cover_is_not_downloaded_twice(self):
        first = self.run_script(OK)
        second = self.run_script(OK)
        self.assertEqual(first, second)
        self.assertEqual(self.asked(), [OK])

    def test_jpeg_and_webp_are_kept_too(self):
        for body in ("jpg", "webp"):
            self.assertTrue(self.run_script(OK + "/" + body, env={"BODY": body}) != "", body)

    def test_refused_addresses_ask_nothing(self):
        for bad in ("http://i.scdn.co/image/abc", "https://evil.example/image/abc", "https://i.scdn.co.evil.example/image/abc",
                    OK + "?x=1", "https://i.scdn.co/image/../etc", "file:///etc/passwd", "", "https://i.scdn.co/image/a b",
                    "https://i.scdn.co/image/" + "a" * 600):
            self.assertEqual(self.run_script(bad), "", bad)
        self.assertEqual(self.asked(), [])

    def test_something_that_is_not_an_image_is_not_kept(self):
        self.assertEqual(self.run_script(OK, env={"BODY": "html"}), "")
        cache = os.path.join(self.home, ".cache", "desktop-widget-control", "covers")
        self.assertEqual([f for f in os.listdir(cache) if not f.startswith(".")], [])

    def test_a_failed_download_prints_nothing(self):
        self.assertEqual(self.run_script(OK, env={"CODE": "404"}), "")

    def test_the_cache_keeps_only_the_newest_forty(self):
        cache = os.path.join(self.home, ".cache", "desktop-widget-control", "covers")
        os.makedirs(cache)
        for i in range(60):
            p = os.path.join(cache, f"old{i:02d}.img")
            with open(p, "w") as f:
                f.write("x")
            os.utime(p, (1000 + i, 1000 + i))
        self.run_script(OK)
        self.assertLessEqual(len(os.listdir(cache)), 41)

    def test_the_host_list_is_the_one_in_cover_js(self):
        js = open(os.path.join(ROOT, "ui", "js", "Cover.js")).read()
        sh = open(SCRIPT).read()
        js_hosts = re.search(r'var hostPattern = "(.*)";', js).group(1).replace("\\\\", "\\")
        self.assertIn(js_hosts, sh)

    def test_the_download_is_bounded(self):
        text = open(SCRIPT).read()
        for needle in ("--max-filesize", "--proto '=https'", "--max-time"):
            self.assertIn(needle, text)
        self.assertNotIn(" -L", text)          # no redirects are followed


if __name__ == "__main__":
    unittest.main()
