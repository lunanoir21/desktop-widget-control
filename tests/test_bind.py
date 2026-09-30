"""The tour's key-binding offer (ui/scripts/bind.sh), in a throwaway HOME with a
stand-in `hyprctl`, so a real Hyprland is never reloaded."""
import os
import shutil
import subprocess
import tempfile
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SCRIPT = os.path.join(ROOT, "ui", "scripts", "bind.sh")


class Bind(unittest.TestCase):
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

    def test_a_lua_config_gets_a_lua_line(self):
        self.write("hyprland.lua", "-- mine\n")
        status, keys, path = self.run_script()
        self.assertEqual((status, keys), ("ok", "SUPER + G"))
        lua = self.read("hypr", "hyprland.lua")
        self.assertTrue(lua.startswith("-- mine\n"))
        self.assertIn('hl.bind("SUPER + G", hl.dsp.exec_cmd(', lua)
        self.assertNotIn("bind =", lua)

    def test_a_conf_config_gets_a_conf_line(self):
        self.write("hyprland.conf", "general { }\n")
        status, keys, _ = self.run_script()
        self.assertEqual((status, keys), ("ok", "SUPER + G"))
        conf = self.read("hypr", "hyprland.conf")
        self.assertTrue(conf.startswith("general { }\n"))
        self.assertIn("bind = SUPER, G, exec,", conf)
        self.assertNotIn("hl.bind", conf)

    def test_omarchys_bindings_file_is_preferred(self):
        self.write("hyprland.conf", "source = bindings.conf\n")
        self.write("bindings.conf", "")
        self.assertEqual(self.run_script()[2], os.path.join(self.hypr, "bindings.conf"))
        self.assertIn("bind = SUPER, G", self.read("hypr", "bindings.conf"))
        self.assertNotIn("desktop-widget-control", self.read("hypr", "hyprland.conf"))

    def test_running_twice_adds_it_once(self):
        self.write("hyprland.conf", "")
        self.run_script()
        self.assertEqual(self.run_script()[0], "exists")
        self.assertEqual(self.read("hypr", "hyprland.conf").count("bind = SUPER, G"), 1)

    def test_lua_twice_adds_it_once(self):
        self.write("hyprland.lua", "")
        self.run_script()
        self.assertEqual(self.run_script()[0], "exists")
        self.assertEqual(self.read("hypr", "hyprland.lua").count("hl.bind"), 1)


if __name__ == "__main__":
    unittest.main()
