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

    def run_script(self, *args):
        out = subprocess.run(["sh", SCRIPT, *args], env=self.env, capture_output=True, text=True).stdout.strip()
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

    def fake_binds(self, binds):
        """A hyprctl that reports `binds` (modmask, key) as already taken."""
        import json
        rows = json.dumps([{"modmask": m, "key": k} for m, k in binds])
        with open(os.path.join(self.bin, "hyprctl"), "w") as f:
            f.write("#!/bin/sh\n[ \"$1\" = binds ] && echo '%s'\nexit 0\n" % rows)

    @unittest.skipUnless(shutil.which("jq"), "needs jq")
    def test_a_taken_key_is_skipped_for_a_free_one(self):
        self.write("hyprland.conf", "")
        self.fake_binds([(64, "G")])
        self.assertEqual(self.run_script()[1], "SUPER SHIFT + G")
        self.assertIn("bind = SUPER SHIFT, G, exec,", self.read("hypr", "hyprland.conf"))

    @unittest.skipUnless(shutil.which("jq"), "needs jq")
    def test_when_several_are_taken_it_moves_on_and_when_all_are_it_changes_nothing(self):
        self.write("hyprland.lua", "")
        self.fake_binds([(64, "G"), (65, "G"), (72, "G"), (68, "G")])
        self.assertEqual(self.run_script()[1], "SUPER + F12")
        self.assertIn('hl.bind("SUPER + F12"', self.read("hypr", "hyprland.lua"))
        self.write("hyprland.conf", "")
        os.remove(os.path.join(self.hypr, "hyprland.lua"))
        self.fake_binds([(64, "G"), (65, "G"), (72, "G"), (68, "G"), (64, "F12"), (65, "F12")])
        self.assertEqual(self.run_script()[0], "taken")
        self.assertEqual(self.read("hypr", "hyprland.conf"), "")

    def test_a_key_given_in_the_arguments_is_used_as_asked(self):
        self.write("hyprland.conf", "")
        self.assertEqual(self.run_script("SUPER_ALT", "a")[:2], ["ok", "SUPER ALT + A"])
        self.assertIn("bind = SUPER ALT, A, exec,", self.read("hypr", "hyprland.conf"))

    def test_a_key_given_in_the_arguments_goes_into_lua_too(self):
        self.write("hyprland.lua", "")
        self.assertEqual(self.run_script("SUPER_SHIFT", "F9")[1], "SUPER SHIFT + F9")
        self.assertIn('hl.bind("SUPER + SHIFT + F9"', self.read("hypr", "hyprland.lua"))

    def test_nonsense_keys_change_nothing(self):
        self.write("hyprland.conf", "")
        for args in (("SUPER", "a;rm"), ("HYPER", "a"), ("", "a"), ("NONE", "a")):
            self.assertEqual(self.run_script(*args)[0], "bad", args)
        self.assertEqual(self.read("hypr", "hyprland.conf"), "")

    @unittest.skipUnless(shutil.which("jq"), "needs jq")
    def test_a_taken_key_asked_for_is_refused_not_replaced(self):
        self.write("hyprland.conf", "")
        self.fake_binds([(72, "A")])
        self.assertEqual(self.run_script("SUPER_ALT", "a")[0], "taken")
        self.assertEqual(self.read("hypr", "hyprland.conf"), "")

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
