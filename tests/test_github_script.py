"""The script behind the GitHub profile widget, run with a stand-in curl that answers from
fixtures: what it prints for a good name, that a bad name asks nothing, how each failure is
reported, that the pages are cut down to the lines the widget parses, and that only a real
picture is kept."""
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "ui", "scripts", "github.sh")

USER = '{"login": "octocat", "name": "The Octocat", "followers": 3, "public_repos": 1}'
REPOS = """[
  {
    "id": 1,
    "name": "hello",
    "owner": {
      "login": "octocat",
      "name": "should not appear"
    },
    "description": "My first repo",
    "fork": false,
    "pushed_at": "2026-10-08T15:41:09Z",
    "stargazers_count": 7,
    "language": "Ruby",
    "forks_count": 2,
    "archived": false,
    "license": {
      "name": "MIT"
    }
  }
]
"""
GRAPH = """<table>
<td tabindex="0" data-ix="0" style="width: 10px" data-date="2026-10-04" id="contribution-day-component-0-0" data-level="2" role="gridcell"></td>
<td tabindex="0" data-ix="1" style="width: 10px" data-date="2026-10-05" id="contribution-day-component-0-1" data-level="0" role="gridcell"></td>
<tool-tip for="contribution-day-component-0-0" popover="manual">12 contributions on October 4th.</tool-tip>
<tool-tip for="contribution-day-component-0-1" popover="manual">No contributions on October 5th.</tool-tip>
<script>alert("hostile")</script>
</table>"""
GQL = '{"data":{"user":{"contributionsCollection":{"contributionCalendar":{"weeks":[{"contributionDays":[{"date":"2026-10-04","contributionCount":12,"contributionLevel":"FOURTH_QUARTILE"},{"date":"2026-10-05","contributionCount":0,"contributionLevel":"NONE"}]}]}}}}}'
TOKEN = "ghp_testtoken123"
PNG = b"\x89PNG\r\n\x1a\n" + b"0" * 20

# A curl that serves fixtures by URL and records every URL it was asked for.
FAKE = r"""#!/bin/sh
out=""; fmt=""; url=""; authed=""
echo "$*" >> "$FIX/argv"
while [ $# -gt 0 ]; do
    case "$1" in
        -o) out=$2; shift 2 ;;
        -w) fmt=$2; shift 2 ;;
        -D) hdr=$2; shift 2 ;;
        -H) if [ "$2" = "@-" ]; then authed=1; cat >> "$FIX/stdin"; fi; shift 2 ;;
        -d) shift 2 ;;
        --max-time|--max-filesize|--proto|--proto-redir) shift 2 ;;
        -*) shift ;;
        *) url=$1; shift ;;
    esac
done
echo "$url" >> "$FIX/asked"
case "$url" in
    */graphql) f=gql; code=200 ;;
    */users/*/repos*|*/contributions) ;;
    */users/*) [ -n "$authed" ] && [ -n "$BAD" ] && { code=401; url=refused; } ;;
esac
case "$url" in
    refused|*/graphql) ;;
    */users/ghost) code=404 ;;
    */users/limited) code=403; [ -n "$hdr" ] && printf 'HTTP/2 403\r\nx-ratelimit-reset: 1791493305\r\n' > "$hdr" ;;
    */users/down) code=000 ;;
    */contributions) f=graph; code=200 ;;
    */users/*/repos*) f=repos; code=200 ;;
    */users/*) f=user; code=200 ;;
    *.png*) f=${PIC:-pic}; code=200 ;;
    *) code=404 ;;
esac
[ -n "$f" ] && [ -f "$FIX/$f" ] && [ -n "$out" ] && cp "$FIX/$f" "$out"
[ "$code" = 000 ] && exit 6
printf '%s' "$code"
"""


class Script(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.mkdtemp()
        self.fix = os.path.join(self.home, "fix")
        self.bin = os.path.join(self.home, "bin")
        os.makedirs(self.fix)
        os.makedirs(self.bin)
        with open(os.path.join(self.bin, "curl"), "w") as f:
            f.write(FAKE)
        os.chmod(os.path.join(self.bin, "curl"), 0o755)
        # a `gh` that is not logged in, so a real one on this machine is never asked for its token
        with open(os.path.join(self.bin, "gh"), "w") as f:
            f.write('#!/bin/sh\nif [ -n "$FAKE_TOKEN" ]; then echo "$FAKE_TOKEN"; else exit 1; fi\n')
        os.chmod(os.path.join(self.bin, "gh"), 0o755)
        for name, body in (("user", USER), ("repos", REPOS), ("graph", GRAPH), ("gql", GQL)):
            with open(os.path.join(self.fix, name), "w") as f:
                f.write(body)
        with open(os.path.join(self.fix, "pic"), "wb") as f:
            f.write(PNG)
        with open(os.path.join(self.fix, "html"), "wb") as f:
            f.write(b"<html>not a picture</html>")
        self.env = {"HOME": self.home, "PATH": self.bin + ":/usr/bin:/bin", "FIX": self.fix, "LANG": "C"}

    def tearDown(self):
        shutil.rmtree(self.home, ignore_errors=True)

    def run_script(self, *args, env=None):
        e = dict(self.env)
        e.update(env or {})
        return subprocess.run(["sh", SCRIPT, *args], env=e, capture_output=True, text=True).stdout

    def asked(self):
        p = os.path.join(self.fix, "asked")
        if not os.path.exists(p):
            return []
        with open(p) as f:
            return f.read().split()

    def test_a_good_name_prints_the_three_sections(self):
        out = self.run_script("octocat")
        self.assertEqual([l for l in out.split("\n") if l.startswith("@")], ["@user", "@repos", "@graph"])
        self.assertIn('"login": "octocat"', out)

    def test_the_repository_page_is_cut_down_to_its_own_keys(self):
        out = self.run_script("octocat")
        repos = out.split("@repos\n")[1].split("@graph")[0]
        self.assertTrue(repos.startswith("{\n"))
        self.assertIn('"name": "hello"', repos)
        self.assertIn('"stargazers_count": 7', repos)
        self.assertNotIn("should not appear", repos)
        self.assertNotIn("MIT", repos)

    def test_the_calendar_page_is_cut_down_to_days_and_counts(self):
        graph = self.run_script("octocat").split("@graph\n")[1]
        self.assertEqual(sorted(graph.strip().split("\n")),
                         sorted(["D 2026-10-04 contribution-day-component-0-0 2", "D 2026-10-05 contribution-day-component-0-1 0",
                                 "C contribution-day-component-0-0 12", "C contribution-day-component-0-1 No"]))
        self.assertNotIn("hostile", graph)

    def test_a_name_that_is_not_a_github_name_asks_nothing(self):
        for bad in ("", "a b", "x;rm -rf ~", "-flag", "a/b", "$(id)", "a" * 40, "名前"):
            self.assertEqual(self.run_script(bad).strip(), "@error notfound", bad)
        self.assertEqual(self.asked(), [])

    def test_every_url_is_https_and_belongs_to_github(self):
        self.run_script("octocat", "1")
        urls = self.asked()
        self.assertEqual(len(urls), 4)
        for u in urls:
            self.assertRegex(u, r"^https://(api\.github\.com|github\.com)/")

    def test_each_failure_has_its_word(self):
        self.assertEqual(self.run_script("ghost").strip(), "@error notfound")
        self.assertEqual(self.run_script("limited").strip(), "@error limited 1791493305")
        self.assertEqual(self.run_script("down").strip(), "@error offline")

    def test_a_missing_calendar_is_not_an_error(self):
        os.remove(os.path.join(self.fix, "graph"))
        out = self.run_script("octocat")
        self.assertIn("@user", out)
        self.assertNotIn("@error", out)

    def test_no_picture_is_fetched_unless_asked(self):
        self.run_script("octocat")
        self.assertFalse([u for u in self.asked() if ".png" in u])
        self.assertFalse(os.path.exists(os.path.join(self.home, ".cache")))

    def test_a_picture_is_kept_privately_and_only_once_a_day(self):
        out = self.run_script("octocat", "1")
        path = out.split("@avatar ")[1].strip()
        self.assertTrue(path.startswith(os.path.join(self.home, ".cache", "desktop-widget-control")))
        with open(path, "rb") as f:
            self.assertEqual(f.read(), PNG)
        self.assertEqual(oct(os.stat(path).st_mode & 0o777), "0o600")
        self.assertEqual(oct(os.stat(os.path.dirname(path)).st_mode & 0o777), "0o700")
        before = len([u for u in self.asked() if ".png" in u])
        self.run_script("octocat", "1")
        self.assertEqual(len([u for u in self.asked() if ".png" in u]), before)

    def test_something_that_is_not_a_picture_is_not_kept(self):
        out = self.run_script("octocat", "1", env={"PIC": "html"})
        self.assertNotIn("@avatar", out)
        self.assertEqual(os.listdir(os.path.join(self.home, ".cache", "desktop-widget-control")), [])

    def read(self, name):
        p = os.path.join(self.fix, name)
        if not os.path.exists(p):
            return ""
        with open(p) as f:
            return f.read()

    def test_without_the_option_no_token_is_asked_for_or_sent(self):
        out = self.run_script("octocat", "0", "0", env={"FAKE_TOKEN": TOKEN})
        self.assertNotIn("@login", out)
        self.assertNotIn("@graphql", out)
        self.assertEqual(self.read("stdin"), "")
        self.assertNotIn("graphql", self.read("asked"))

    def test_logged_in_the_token_goes_in_on_stdin_and_the_calendar_comes_from_graphql(self):
        out = self.run_script("octocat", "0", "1", env={"FAKE_TOKEN": TOKEN})
        sections = [l for l in out.split("\n") if l.startswith("@")]
        self.assertEqual(sections, ["@user", "@login ok", "@repos", "@graphql"])
        self.assertIn("contributionDays", out)
        self.assertIn("Authorization: Bearer " + TOKEN, self.read("stdin"))
        self.assertNotIn(TOKEN, self.read("argv"), "the token must never be on a command line")
        self.assertNotIn(TOKEN, out)
        self.assertNotIn("github.com/users/octocat/contributions", self.read("asked"))

    def test_the_token_is_only_sent_to_the_api_host(self):
        self.run_script("octocat", "1", "1", env={"FAKE_TOKEN": TOKEN})
        for line in self.read("argv").split("\n"):
            if "-H @-" in line:
                self.assertRegex(line, r"https://api\.github\.com/")

    def test_no_gh_login_says_so_and_falls_back_to_the_public_calendar(self):
        out = self.run_script("octocat", "0", "1")
        self.assertIn("@login none", out)
        self.assertIn("@graph\n", out)
        self.assertEqual(self.read("stdin"), "")

    def test_a_token_that_is_refused_is_dropped(self):
        out = self.run_script("octocat", "0", "1", env={"FAKE_TOKEN": TOKEN, "BAD": "1"})
        self.assertIn("@login bad", out)
        self.assertIn("@user", out)
        self.assertIn("@graph\n", out)

    def test_a_token_with_odd_characters_is_not_used(self):
        out = self.run_script("octocat", "0", "1", env={"FAKE_TOKEN": "bad token;rm -rf ~"})
        self.assertIn("@login none", out)
        self.assertEqual(self.read("stdin"), "")

    def test_the_reads_are_bounded(self):
        with open(SCRIPT) as f:
            text = f.read()
        self.assertIn("--max-filesize", text)
        self.assertIn("--proto '=https'", text)
        self.assertIn("head -c", text)
        self.assertNotIn("http://", text)


if __name__ == "__main__":
    unittest.main()
