"""Behavior tests for tools/touch_env.py (no installer side effects).

Covers tools/tests/README.md section 1.2/1.3 (keep-sdk decision) and the pure
helpers (parse_repo_url, safe removal, message lookup). These tests exist
because a P0 bug ("--keep-sdk no" treated as truthy string) slipped
through when only the parameter surface was tested.

Run:  python tools/tests/test_touch_env_behavior.py
"""

import importlib.util
import io
import os
import shutil
import sys
import tempfile
import types
import unittest
from contextlib import redirect_stdout
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[1]
TOUCH_ENV = TOOLS_DIR / "touch_env.py"


def _load_module():
    spec = importlib.util.spec_from_file_location("touch_env_under_test", TOUCH_ENV)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def _make_layout(root):
    """Seed a fake installation: local_pkgs marker, cmds/.config, venv tree."""
    os.makedirs(os.path.join(root, "local_pkgs"), exist_ok=True)
    marker = os.path.join(root, "local_pkgs", "tool.marker")
    with open(marker, "w", encoding="utf-8") as f:
        f.write("keep-me")
    os.makedirs(os.path.join(root, "tools", "scripts", "cmds"), exist_ok=True)
    config = os.path.join(root, "tools", "scripts", "cmds", ".config")
    with open(config, "w", encoding="utf-8") as f:
        f.write("CFG")
    os.makedirs(os.path.join(root, "venv", "rt-env", "Scripts"), exist_ok=True)
    os.makedirs(os.path.join(root, "packages", "packages"), exist_ok=True)
    return marker, config


def _config(root, keep_sdk, auto_mode=True):
    return types.SimpleNamespace(
        env_root=root, keep_sdk=keep_sdk, auto_mode=auto_mode
    )


class CheckExistingEnvTest(unittest.TestCase):
    """Section 1.3: the --keep-sdk decision (P0 regression)."""

    def setUp(self):
        self.module = _load_module()
        self.root = tempfile.mkdtemp(prefix="rt-env-keep-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)

    def _run(self, keep, auto=True):
        with redirect_stdout(io.StringIO()):
            self.module.check_existing_env(_config(self.root, keep, auto))

    def test_keep_yes_preserves_local_pkgs_and_config(self):
        _make_layout(self.root)
        self._run("yes")
        self.assertTrue(
            os.path.isfile(os.path.join(self.root, "local_pkgs", "tool.marker"))
        )
        self.assertTrue(
            os.path.isfile(os.path.join(self.root, "tools", "scripts", "cmds", ".config"))
        )

    def test_keep_yes_rebuilds_venv_and_repos(self):
        _make_layout(self.root)
        self._run("yes")
        self.assertFalse(os.path.exists(os.path.join(self.root, "venv")))
        self.assertFalse(os.path.exists(os.path.join(self.root, ".venv")))
        self.assertFalse(os.path.exists(os.path.join(self.root, "packages")))

    def test_keep_no_wipes_entire_root(self):
        # P0 regression: "no" is a truthy string and must still mean "wipe".
        _make_layout(self.root)
        self._run("no")
        self.assertFalse(os.path.exists(self.root))

    def test_unspecified_auto_mode_defaults_to_keep(self):
        _make_layout(self.root)
        self._run(None, auto=True)
        self.assertTrue(
            os.path.isfile(os.path.join(self.root, "local_pkgs", "tool.marker"))
        )

    def test_missing_root_is_a_no_op(self):
        # A root that does not exist must simply return.
        missing = os.path.join(self.root, "does-not-exist")
        with redirect_stdout(io.StringIO()):
            self.module.check_existing_env(_config(missing, "no", True))


class ParseRepoUrlTest(unittest.TestCase):
    """Branch-fragment parsing used by --repo-* options."""

    @classmethod
    def setUpClass(cls):
        cls.module = _load_module()

    def test_fragment_is_split_off(self):
        parsed = self.module.parse_repo_url("https://github.com/u/env.git#dev")
        self.assertEqual(parsed, {"url": "https://github.com/u/env.git", "branch": "dev"})

    def test_plain_url_has_no_branch_key(self):
        parsed = self.module.parse_repo_url("https://example.com/r.git")
        self.assertEqual(parsed, {"url": "https://example.com/r.git"})
        self.assertNotIn("branch", parsed)


class SafeRemoveTest(unittest.TestCase):
    """_safe_remove / _safe_remove_tree file-and-directory helpers."""

    @classmethod
    def setUpClass(cls):
        cls.module = _load_module()

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="rt-env-rm-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)

    def test_safe_remove_file(self):
        target = os.path.join(self.root, "f.txt")
        with open(target, "w", encoding="utf-8") as f:
            f.write("x")
        with redirect_stdout(io.StringIO()):
            self.assertTrue(self.module._safe_remove(target, "f.txt"))
        self.assertFalse(os.path.exists(target))

    def test_safe_remove_directory(self):
        target = os.path.join(self.root, "d")
        os.makedirs(target)
        with redirect_stdout(io.StringIO()):
            self.assertTrue(self.module._safe_remove(target, "d"))
        self.assertFalse(os.path.exists(target))

    def test_safe_remove_missing_path_is_idempotent(self):
        # Absent paths are treated as already deleted (returns True, no error).
        with redirect_stdout(io.StringIO()):
            self.assertTrue(self.module._safe_remove(os.path.join(self.root, "nope"), "nope"))

    def test_safe_remove_tree_directory(self):
        target = os.path.join(self.root, "tree", "nested")
        os.makedirs(target)
        marker = os.path.join(target, "m.txt")
        with open(marker, "w", encoding="utf-8") as f:
            f.write("x")
        self.module._safe_remove_tree(os.path.join(self.root, "tree"))
        self.assertFalse(os.path.exists(os.path.join(self.root, "tree")))


class GetMessageTest(unittest.TestCase):
    """i18n lookup falls back to the key itself for unknown keys."""

    @classmethod
    def setUpClass(cls):
        cls.module = _load_module()

    def test_known_key_returns_text(self):
        self.assertEqual(
            self.module.get_message("toolchain_kept"),
            "Keeping toolchains (local_pkgs) and config",
        )

    def test_unknown_key_returns_the_key(self):
        self.assertEqual(self.module.get_message("definitely_not_a_key"), "definitely_not_a_key")

    def test_set_language_switches_table(self):
        self.module.set_language("zh")
        try:
            self.assertEqual(
                self.module.get_message("toolchain_kept"),
                "保留工具链（local_pkgs）与配置",
            )
        finally:
            self.module.set_language("en")


class ShowNextStepsTest(unittest.TestCase):
    """G4: show_next_steps prints the full command list incl. plugin/webui."""

    @classmethod
    def setUpClass(cls):
        cls.module = _load_module()

    def test_output_lists_all_commands_in_order(self):
        config = types.SimpleNamespace(env_root="dummy", auto_mode=True)
        with redirect_stdout(io.StringIO()) as buf:
            self.module.show_next_steps(config)
        out = buf.getvalue()
        # Ordered appearance of every command line
        cursor = 0
        for cmd in ("menuconfig", "pkgs", "scons", "sdk", "plugin", "webui"):
            pos = out.find(f"- {cmd}")
            self.assertGreater(pos, cursor, f"expected '- {cmd}' after previous entries")
            cursor = pos
        self.assertIn("Install toolchains", out)


if __name__ == "__main__":
    unittest.main(verbosity=2)
