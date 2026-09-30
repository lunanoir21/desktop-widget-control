"""The tour's key-binding offer (ui/scripts/keybind.sh), in a throwaway HOME with a
stand-in `hyprctl`, so a real Hyprland is never reloaded."""
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "ui", "scripts", "keybind.sh")


class KeyBind(unittest.TestCase):
    def setUp(self):
        self.home = tempfile.mkdtemp()
        self.bin = os.path.join(self.home, "fakebin")
        os.makedirs(self.bin)
        with open(os.path.join(self.bin, "hyprctl"), "w") as f:
            f.write("#!/bin/sh\nexit 1\n")
        os.chmod(os.path.join(self.bin, "hyprctl"), 0o755)
        self.hypr = os.path.join(self.home, ".config", "hypr")
        os.makedirs(self.hypr)
        self.env = {"HOME": self.home, "PATH": self.bin + ":/usr/bin:/bin", "LANG": "C"}

    def tearDown(self):
        shutil.rmtree(self.home, ignore_errors=True)

    def run_script(self):
        out = subprocess.run(["sh", SCRIPT], env=self.env, capture_output=True, text=True).stdout.strip()
        return out.split("|")

    def write(self, name, text=""):
        with open(os.path.join(self.hypr, name), "w") as f:
            f.write(text)

    def read(self, *p):
        with open(os.path.join(self.home, ".config", *p)) as f:
            return f.read()

    def test_without_a_hyprland_config_nothing_is_written(self):
        self.assertEqual(self.run_script()[0], "nohypr")
        self.assertFalse(os.path.exists(os.path.join(self.home, ".config", "desktop-widget-control")))

    def test_a_lua_config_gets_the_line_to_paste_and_is_not_touched(self):
        self.write("hyprland.lua", "-- mine\n")
        status, line, _ = self.run_script()
        self.assertEqual(status, "lua")
        self.assertIn("hl.bind", line)
        self.assertEqual(self.read("hypr", "hyprland.lua"), "-- mine\n")

    def test_the_key_goes_into_a_snippet_sourced_from_the_config(self):
        self.write("hyprland.conf", "general { }\n")
        status, keys, _ = self.run_script()
        self.assertEqual((status, keys), ("ok", "SUPER + G"))
        self.assertIn("bind = SUPER, G, exec,", self.read("desktop-widget-control", "hyprland.conf"))
        conf = self.read("hypr", "hyprland.conf")
        self.assertTrue(conf.startswith("general { }\n"))
        self.assertIn("desktop-widget-control/hyprland.conf # desktop-widget-control", conf)

    def test_omarchys_bindings_file_is_preferred(self):
        self.write("hyprland.conf", "source = bindings.conf\n")
        self.write("bindings.conf", "")
        self.assertEqual(self.run_script()[2], os.path.join(self.hypr, "bindings.conf"))
        self.assertIn("desktop-widget-control", self.read("hypr", "bindings.conf"))
        self.assertNotIn("desktop-widget-control", self.read("hypr", "hyprland.conf"))

    def test_running_twice_adds_it_once(self):
        self.write("hyprland.conf", "")
        self.run_script()
        self.assertEqual(self.run_script()[0], "exists")
        self.assertEqual(self.read("hypr", "hyprland.conf").count("desktop-widget-control"), 2)  # path + marker, one line


if __name__ == "__main__":
    unittest.main()
