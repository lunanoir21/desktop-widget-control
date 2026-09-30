"""The installer, run against a throwaway HOME with a stand-in `quickshell`:
it links, copies, sets up Hyprland only when told to, is safe to run twice,
and its --dry-run and --uninstall do what they say."""
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
INSTALL = os.path.join(ROOT, "install.sh")


class Installer(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.mkdtemp()
        self.bin = os.path.join(self.home, "fakebin")
        os.makedirs(self.bin)
        qs = os.path.join(self.bin, "quickshell")
        with open(qs, "w") as f:
            f.write("#!/bin/sh\nexit 1\n")          # "not running": ipc calls fail
        os.chmod(qs, 0o755)
        self.env = {"HOME": self.home, "PATH": self.bin + ":/usr/bin:/bin", "LANG": "C"}
        for k in ("XDG_CONFIG_HOME", "XDG_DATA_HOME", "WAYLAND_DISPLAY", "HYPRLAND_INSTANCE_SIGNATURE"):
            self.env.pop(k, None)

    def tearDown(self):
        shutil.rmtree(self.home, ignore_errors=True)

    def run_install(self, *args, env=None):
        e = dict(self.env)
        e.update(env or {})
        return subprocess.run(["sh", INSTALL, "--no-start", *args], env=e, capture_output=True, text=True, cwd=self.home)

    def path(self, *p):
        return os.path.join(self.home, *p)

    def test_installs_a_link_the_helper_and_the_launcher_entry(self):
        r = self.run_install()
        self.assertEqual(r.returncode, 0, r.stderr + r.stdout)
        link = self.path(".config/quickshell/desktop-widget-control")
        self.assertTrue(os.path.islink(link))
        self.assertEqual(os.path.realpath(link), os.path.realpath(ROOT))
        self.assertTrue(os.path.islink(self.path(".local/bin/dwc")))
        self.assertTrue(os.path.isfile(self.path(".local/share/applications/desktop-widget-control.desktop")))
        self.assertTrue(os.path.isfile(self.path(".local/share/icons/hicolor/scalable/apps/desktop-widget-control.svg")))

    def test_copy_mode_makes_a_real_folder_with_the_shell_and_ui(self):
        r = self.run_install("--copy")
        self.assertEqual(r.returncode, 0, r.stderr)
        target = self.path(".config/quickshell/desktop-widget-control")
        self.assertFalse(os.path.islink(target))
        self.assertTrue(os.path.isfile(os.path.join(target, "shell.qml")))
        self.assertTrue(os.path.isfile(os.path.join(target, "ui", "qmldir")))

    def test_running_it_twice_is_fine(self):
        self.assertEqual(self.run_install().returncode, 0)
        r = self.run_install()
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertTrue(os.path.islink(self.path(".config/quickshell/desktop-widget-control")))

    def test_dry_run_changes_nothing(self):
        r = self.run_install("--dry-run")
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("dry run", r.stdout)
        self.assertFalse(os.path.exists(self.path(".config")))
        self.assertFalse(os.path.exists(self.path(".local")))

    def test_fails_clearly_without_quickshell(self):
        # A PATH with the basic tools the script uses, and no quickshell.
        bare = os.path.join(self.home, "barebin")
        os.makedirs(bare)
        for tool in ("sh", "ln", "mkdir", "rm", "cp", "cat", "sed", "grep", "dirname", "sleep"):
            src = shutil.which(tool)
            if src:
                os.symlink(src, os.path.join(bare, tool))
        r = self.run_install(env={"PATH": bare})
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("Quickshell is not installed", r.stderr)
        self.assertFalse(os.path.exists(self.path(".config/quickshell")))

    def test_hyprland_config_is_only_touched_when_asked(self):
        conf = self.path(".config/hypr/hyprland.conf")
        os.makedirs(os.path.dirname(conf))
        with open(conf, "w") as f:
            f.write("monitor=,preferred,auto,1\n")
        env = {"HYPRLAND_INSTANCE_SIGNATURE": "x"}
        self.assertEqual(self.run_install(env=env).returncode, 0)
        self.assertEqual(open(conf).read(), "monitor=,preferred,auto,1\n")          # no terminal, no --autostart: untouched

        self.assertEqual(self.run_install("--autostart", env=env).returncode, 0)
        text = open(conf).read()
        self.assertIn("source = " + self.path(".config/desktop-widget-control/hyprland.conf"), text)
        snippet = open(self.path(".config/desktop-widget-control/hyprland.conf")).read()
        self.assertIn("exec-once = quickshell -c desktop-widget-control", snippet)
        self.assertIn("dwc toggle", snippet)

        # and not twice
        self.run_install("--autostart", env=env)
        self.assertEqual(open(conf).read().count("desktop-widget-control"), text.count("desktop-widget-control"))

    def test_uninstall_removes_what_it_added_and_keeps_the_layout(self):
        conf = self.path(".config/hypr/hyprland.conf")
        os.makedirs(os.path.dirname(conf))
        with open(conf, "w") as f:
            f.write("monitor=,preferred,auto,1\n")
        env = {"HYPRLAND_INSTANCE_SIGNATURE": "x"}
        self.run_install("--autostart", env=env)
        layout = self.path(".config/desktop-widget-control/layout.json")
        with open(layout, "w") as f:
            f.write("{}")
        r = subprocess.run(["sh", INSTALL, "--uninstall"], env={**self.env, **env}, capture_output=True, text=True, cwd=self.home)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertFalse(os.path.lexists(self.path(".config/quickshell/desktop-widget-control")))
        self.assertFalse(os.path.lexists(self.path(".local/bin/dwc")))
        self.assertEqual(open(conf).read(), "monitor=,preferred,auto,1\n")
        self.assertTrue(os.path.isfile(layout))

    def test_a_piped_install_plans_a_download(self):
        with open(INSTALL) as f:
            script = f.read()
        r = subprocess.run(["sh", "-s", "--", "--dry-run", "--no-start"], input=script, env=self.env, capture_output=True, text=True, cwd=self.home)
        self.assertEqual(r.returncode, 0, r.stderr)
        self.assertIn("downloading Desktop Widget Control", r.stdout)
        self.assertIn("github.com/lunanoir21/desktop-widget-control", r.stdout)
        self.assertFalse(os.path.exists(self.path(".local")))


class Helper(unittest.TestCase):
    def test_help_and_the_not_running_message(self):
        dwc = os.path.join(ROOT, "bin", "dwc")
        h = subprocess.run(["sh", dwc, "help"], capture_output=True, text=True)
        self.assertEqual(h.returncode, 0)
        for word in ("start", "toggle", "center", "tour", "theme"):
            self.assertIn("dwc " + word, h.stdout)
        r = subprocess.run(["sh", dwc, "toggle"], capture_output=True, text=True, env={"PATH": "/usr/bin:/bin", "DWC_QS": "false"})
        self.assertNotEqual(r.returncode, 0)
        self.assertIn("not running", r.stderr)


if __name__ == "__main__":
    unittest.main()
