"""Unit tests for the sdk command config redirection.

Covers cmds.cmd_sdk.cmd: the sdk selection persists in
$ENV_ROOT/sdk.config (via the kconfiglib KCONFIG_CONFIG redirect around
the menuconfig TUI, and via the explicit config_file argument for the
package helpers), the working directory and the exported bsp_root are
restored afterwards, and the sdk_list.json output is written from the
selected packages.

The menuconfig entry point and the cmd_package helpers are stubbed via
sys.modules / monkeypatching, so no kconfiglib TUI or network access is
needed.

Run from the repository root:
    python -m unittest plugins.tests.test_cmd_sdk
"""

import json
import os
import shutil
import sys
import tempfile
import types
import unittest
from unittest import mock

import vars
from cmds import cmd_sdk


class _FakeMenuconfig:
    """Stands in for the kconfiglib menuconfig entry point."""

    def __init__(self):
        self.calls = []
        self.fail = False

    def _main(self):
        if self.fail:
            raise RuntimeError("menuconfig exploded")
        self.calls.append((os.getcwd(), os.environ.get("KCONFIG_CONFIG"), list(sys.argv)))


class SdkCmdTest(unittest.TestCase):
    def setUp(self):
        self.env_root = tempfile.mkdtemp(prefix="rt-env-sdk-")
        self.orig_dir = tempfile.mkdtemp(prefix="rt-env-sdk-orig-")
        self.addCleanup(shutil.rmtree, self.env_root, ignore_errors=True)
        self.addCleanup(shutil.rmtree, self.orig_dir, ignore_errors=True)

        scripts = os.path.join(self.env_root, "tools", "scripts")
        os.makedirs(scripts, exist_ok=True)

        self.fake_menuconfig = _FakeMenuconfig()
        menuconfig_mod = types.ModuleType("menuconfig")
        menuconfig_mod._main = lambda: self.fake_menuconfig._main()

        module_patcher = mock.patch.dict(sys.modules, {"menuconfig": menuconfig_mod})
        module_patcher.start()
        self.addCleanup(module_patcher.stop)

        self.package_calls = []

        def fake_package_update(config_file=None):
            self.package_calls.append((os.getcwd(), config_file, os.environ.get("KCONFIG_CONFIG")))

        def fake_get_packages(config_file=None):
            self.package_calls.append((os.getcwd(), config_file, os.environ.get("KCONFIG_CONFIG")))
            return [
                {"name": "cmake", "ver": "4.1.0"},
                {"name": "riscv64-gcc", "ver": "14.2.1"},
            ]

        update_patcher = mock.patch("cmds.cmd_package.package_update", fake_package_update)
        update_patcher.start()
        self.addCleanup(update_patcher.stop)

        get_patcher = mock.patch("cmds.cmd_package.get_packages", fake_get_packages)
        get_patcher.start()
        self.addCleanup(get_patcher.stop)

        list_patcher = mock.patch("cmds.cmd_package.list_packages")
        list_patcher.start()
        self.addCleanup(list_patcher.stop)

        vars.env_vars["env_root"] = self.env_root
        vars.env_vars["bsp_root"] = "/original/bsp"
        self.addCleanup(vars.env_vars.pop, "bsp_root", None)
        self.addCleanup(vars.env_vars.pop, "env_root", None)

        self.kconfig_backup = os.environ.get("KCONFIG_CONFIG")
        self.cwd_backup = os.getcwd()
        self.addCleanup(self._restore_env)

        os.environ.pop("KCONFIG_CONFIG", None)
        os.chdir(self.orig_dir)

    def _restore_env(self):
        if self.kconfig_backup is None:
            os.environ.pop("KCONFIG_CONFIG", None)
        else:
            os.environ["KCONFIG_CONFIG"] = self.kconfig_backup
        os.chdir(self.cwd_backup)

    def test_sdk_selection_redirects_to_env_root_sdk_config(self):
        cmd_sdk.cmd([])

        scripts = os.path.join(self.env_root, "tools", "scripts")
        expected_config = os.path.join(self.env_root, "sdk.config")

        cwd, kconfig_config, argv = self.fake_menuconfig.calls[0]
        self.assertEqual(cwd, scripts)
        self.assertEqual(kconfig_config, expected_config)
        self.assertEqual(argv, ["menuconfig", "Kconfig"])

        # the package helpers take the config file explicitly, with the
        # KCONFIG_CONFIG redirect already restored (it only covers the
        # kconfiglib menuconfig TUI)
        self.assertEqual(len(self.package_calls), 2)
        for call_cwd, call_config_file, call_env in self.package_calls:
            self.assertEqual(call_cwd, scripts)
            self.assertEqual(call_config_file, expected_config)
            self.assertIsNone(call_env)

    def test_sdk_list_written_from_selected_packages(self):
        cmd_sdk.cmd([])

        sdk_list = os.path.join(self.env_root, "tools", "scripts", "sdk_list.json")
        with open(sdk_list, encoding="utf-8") as f:
            data = json.load(f)

        self.assertEqual(
            data,
            [
                {"name": "cmake", "path": "cmake-4.1.0"},
                {"name": "riscv64-gcc", "path": "riscv64-gcc-14.2.1"},
            ],
        )

    def test_no_dot_config_in_working_directory(self):
        cmd_sdk.cmd([])

        scripts = os.path.join(self.env_root, "tools", "scripts")
        self.assertFalse(os.path.exists(os.path.join(scripts, ".config")))
        self.assertFalse(os.path.exists(os.path.join(self.env_root, ".config")))

    def test_environment_and_cwd_restored(self):
        cmd_sdk.cmd([])

        self.assertNotIn("KCONFIG_CONFIG", os.environ)
        self.assertEqual(os.getcwd(), self.orig_dir)
        self.assertEqual(vars.env_vars["bsp_root"], "/original/bsp")

    def test_state_restored_on_failure(self):
        self.fake_menuconfig.fail = True

        with self.assertRaises(RuntimeError):
            cmd_sdk.cmd([])

        self.assertNotIn("KCONFIG_CONFIG", os.environ)
        self.assertEqual(os.getcwd(), self.orig_dir)
        self.assertEqual(vars.env_vars["bsp_root"], "/original/bsp")

    def test_preset_kconfig_config_restored(self):
        os.environ["KCONFIG_CONFIG"] = "/preset/config"

        self.fake_menuconfig._main = lambda: None

        cmd_sdk.cmd([])

        self.assertEqual(os.environ["KCONFIG_CONFIG"], "/preset/config")


if __name__ == "__main__":
    unittest.main()
