"""The scripts behind the AI limits widget, in a throwaway HOME: what `usage.sh local`
finds, that nothing is read when there is nothing, that the credential is only read in
`api` mode and never sent when expired, and that the status line hook saves the payload
and passes it on."""
import json
import os
import shutil
import subprocess
import tempfile
import time
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
USAGE = os.path.join(ROOT, "ui", "scripts", "usage.sh")
HOOK = os.path.join(ROOT, "ui", "scripts", "claude-statusline.sh")

LIMIT_LINE = {"timestamp": "2026-08-17T10:00:02.000Z", "type": "event_msg", "payload": {"type": "token_count",
              "rate_limits": {"primary": {"used_percent": 93.0, "window_minutes": 10080, "resets_at": 1787256462},
                              "secondary": {"used_percent": 40.0, "window_minutes": 300, "resets_at": 1787017800}}}}


class Scripts(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.mkdtemp()
        self.bin = os.path.join(self.home, "fakebin")
        os.makedirs(self.bin)
        # a curl that records what it was asked and must never run in `local` mode
        with open(os.path.join(self.bin, "curl"), "w") as f:
            f.write('#!/bin/sh\necho called > "%s/curl-called"\nexit 22\n' % self.home)
        os.chmod(os.path.join(self.bin, "curl"), 0o755)
        self.env = {"HOME": self.home, "PATH": self.bin + ":/usr/bin:/bin", "LANG": "C"}

    def tearDown(self):
        shutil.rmtree(self.home, ignore_errors=True)

    def run_script(self, script, *args, stdin=""):
        return subprocess.run(["sh", script, *args], env=self.env, input=stdin, capture_output=True, text=True).stdout

    def codex_log(self, lines, name="rollout-2026-08-17T10-00-00-x.jsonl"):
        d = os.path.join(self.home, ".codex", "sessions", "2026", "08", "17")
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, name), "w") as f:
            f.write("\n".join(lines) + "\n")

    def test_nothing_installed_prints_nothing(self):
        self.assertEqual(self.run_script(USAGE, "local"), "")
        self.assertFalse(os.path.exists(os.path.join(self.home, "curl-called")))

    def test_the_last_codex_limit_line_is_found(self):
        self.codex_log([json.dumps({"payload": {"type": "message"}}), json.dumps(LIMIT_LINE), json.dumps({"payload": {"type": "message"}})])
        out = self.run_script(USAGE, "local")
        self.assertTrue(out.startswith("@codex\n"))
        self.assertEqual(json.loads(out.split("\n")[1])["payload"]["rate_limits"]["secondary"]["used_percent"], 40.0)

    def test_the_newest_log_without_a_limit_does_not_hide_an_older_one(self):
        self.codex_log([json.dumps(LIMIT_LINE)], "rollout-old.jsonl")
        time.sleep(1.1)
        self.codex_log([json.dumps({"payload": {"type": "message"}})], "rollout-new.jsonl")
        self.assertIn("@codex", self.run_script(USAGE, "local"))

    def test_the_status_line_capture_is_read_with_its_age(self):
        d = os.path.join(self.home, ".local", "state", "desktop-widget-control")
        os.makedirs(d)
        with open(os.path.join(d, "claude-statusline.json"), "w") as f:
            f.write(json.dumps({"rate_limits": {"five_hour": {"used_percentage": 63, "resets_at": 1}}}))
        out = self.run_script(USAGE, "local")
        head = out.split("\n")[0].split()
        self.assertEqual(head[0], "@claude-capture")
        self.assertGreater(int(head[1]), 1_000_000_000)
        self.assertIn('"used_percentage": 63', out)

    def test_api_mode_without_a_credential_says_so_and_asks_nothing(self):
        self.assertEqual(self.run_script(USAGE, "api").strip(), "@claude-api-none")
        self.assertFalse(os.path.exists(os.path.join(self.home, "curl-called")))

    def test_an_expired_token_is_never_sent(self):
        d = os.path.join(self.home, ".claude")
        os.makedirs(d)
        with open(os.path.join(d, ".credentials.json"), "w") as f:
            f.write('{"claudeAiOauth":{"accessToken":"secret-token","expiresAt":1000}}')
        self.assertEqual(self.run_script(USAGE, "api").strip(), "@claude-api-expired")
        self.assertFalse(os.path.exists(os.path.join(self.home, "curl-called")))

    def test_a_failed_request_is_reported_as_failed(self):
        """curl's own exit status decides, not the status of whatever reads its output."""
        d = os.path.join(self.home, ".claude")
        os.makedirs(d, exist_ok=True)
        with open(os.path.join(d, ".credentials.json"), "w") as f:
            f.write('{"claudeAiOauth":{"accessToken":"secret-token","expiresAt":99999999999999}}')
        fake = os.path.join(self.home, "fakebin")
        os.makedirs(fake, exist_ok=True)
        with open(os.path.join(fake, "curl"), "w") as f:
            f.write("#!/bin/sh\nexit 22\n")
        os.chmod(os.path.join(fake, "curl"), 0o755)
        out = subprocess.run(["sh", USAGE, "api"], capture_output=True, text=True,
                             env={"HOME": self.home, "PATH": fake + ":/usr/bin:/bin"}).stdout
        self.assertEqual(out.strip(), "@claude-api-failed")

    def test_the_token_is_not_put_on_the_command_line(self):
        with open(USAGE) as f:
            text = f.read()
        self.assertIn("-H @-", text)
        self.assertNotIn('Bearer $token" ', text.replace("printf 'Authorization: Bearer %s\\n' \"$token\"", ""))

    def test_the_hook_saves_the_payload_and_passes_it_on(self):
        payload = '{"rate_limits":{"five_hour":{"used_percentage":5,"resets_at":1}}}'
        out = self.run_script(HOOK, "cat", stdin=payload)
        self.assertEqual(out.strip(), payload)
        saved = os.path.join(self.home, ".local", "state", "desktop-widget-control", "claude-statusline.json")
        with open(saved) as f:
            self.assertEqual(f.read().strip(), payload)

    def test_the_hook_without_a_command_prints_nothing(self):
        self.assertEqual(self.run_script(HOOK, stdin="{}"), "")


if __name__ == "__main__":
    unittest.main()
