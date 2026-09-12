"""Tests for tools/touch_env.py command-line surface.

Covers the parameter surface and i18n table described in tools/tests/README.md
section 1.  Static analysis only (AST) plus one ``--help`` subprocess call;
no installer side effects.

Run:  python tools/tests/common/test_touch_env_args.py
"""

import ast
import re
import subprocess
import sys
import unittest
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[3] / "tools"
TOUCH_ENV = TOOLS_DIR / "touch_env.py"

_removed_options = ("--install-pyocd", "--backup", "--restore-config")
_expected_options = (
    "--env-root",
    "--use-cn",
    "--language",
    "--auto-mode",
    "--keep-sdk",
    "--repo-env",
    "--repo-packages",
    "--repo-sdk",
)


def _module_ast():
    return ast.parse(TOUCH_ENV.read_text(encoding="utf-8"))


def _messages_dicts():
    """Return (en_keys, zh_keys) from the MESSAGES literal."""
    for node in ast.walk(_module_ast()):
        if isinstance(node, ast.Assign) and any(
            isinstance(t, ast.Name) and t.id == "MESSAGES" for t in node.targets
        ):
            # node.value is Dict{ 'en': Dict{...}, 'zh': Dict{...} }
            tables = node.value.values
            if len(tables) != 2:
                raise AssertionError("MESSAGES must hold exactly en and zh tables")
            en, zh = tables
            return (
                {k.value for k in en.keys},
                {k.value for k in zh.keys},
            )
    raise AssertionError("MESSAGES literal not found")


def _find_add_argument(keyword):
    """Yield the add_argument call whose first arg contains ``keyword``."""
    for node in ast.walk(_module_ast()):
        if not (isinstance(node, ast.Call) and isinstance(node.func, ast.Attribute)):
            continue
        if node.func.attr != "add_argument" or not node.args:
            continue
        first = node.args[0]
        if isinstance(first, ast.Constant) and first.value == keyword:
            yield node


class HelpOutputTest(unittest.TestCase):
    """Section 1.1: parameter surface as seen by --help."""

    @classmethod
    def setUpClass(cls):
        result = subprocess.run(
            [sys.executable, str(TOUCH_ENV), "--help"],
            capture_output=True,
            text=True,
        )
        cls.help = result.stdout + result.stderr

    def test_keep_sdk_listed(self):
        self.assertIn("--keep-sdk", self.help)

    def test_expected_options_listed(self):
        for option in _expected_options:
            with self.subTest(option=option):
                self.assertIn(option, self.help)

    def test_removed_options_absent(self):
        for option in _removed_options:
            with self.subTest(option=option):
                self.assertNotIn(option, self.help)

    def test_no_single_letter_short_options(self):
        # argparse renders defined short options as "-x, --long"; none expected here.
        short_options = re.findall(r"(?m)^\s+(-[a-zA-Z]),\s+--", self.help)
        unexpected = [opt for opt in short_options if opt != "-h"]
        self.assertEqual(unexpected, [], "unexpected short options defined")


class ArgumentDefinitionTest(unittest.TestCase):
    """Static checks on argparse definitions."""

    def test_keep_sdk_default_is_none(self):
        calls = list(_find_add_argument("--keep-sdk"))
        self.assertEqual(len(calls), 1, "--keep-sdk must be defined once")
        keywords = {kw.arg: kw.value for kw in calls[0].keywords}
        self.assertIn("default", keywords)
        self.assertIsInstance(keywords["default"], ast.Constant)
        self.assertIsNone(keywords["default"].value)

    def test_keep_sdk_choices(self):
        calls = list(_find_add_argument("--keep-sdk"))
        keywords = {kw.arg: kw.value for kw in calls[0].keywords}
        choices = {e.value for e in keywords["choices"].elts}
        self.assertEqual(choices, {"yes", "no"})

    def test_removed_options_not_defined(self):
        for option in _removed_options:
            with self.subTest(option=option):
                self.assertEqual(list(_find_add_argument(option)), [])


class MessagesTest(unittest.TestCase):
    """Section 1.2: the en/zh message tables must stay symmetric."""

    def test_en_zh_keys_symmetric(self):
        en_keys, zh_keys = _messages_dicts()
        self.assertEqual(
            en_keys - zh_keys, set(), "keys present in en but missing in zh"
        )
        self.assertEqual(
            zh_keys - en_keys, set(), "keys present in zh but missing in en"
        )

    def test_toolchain_keys_present(self):
        en_keys, _ = _messages_dicts()
        for key in ("toolchain_keep_prompt", "toolchain_kept", "toolchain_removed"):
            with self.subTest(key=key):
                self.assertIn(key, en_keys)

    def test_plugin_and_webui_messages_present(self):
        en_keys, zh_keys = _messages_dicts()
        for table in (en_keys, zh_keys):
            for key in ("plugin", "webui"):
                with self.subTest(key=key):
                    self.assertIn(key, table)


class MessageUsageTest(unittest.TestCase):
    """G5: every defined i18n key must have at least one call site."""

    def test_no_orphan_message_keys(self):
        source = TOUCH_ENV.read_text(encoding="utf-8")
        match = re.search(r"MESSAGES = \{\s*'en': \{(.*?)\n    \},\s*'zh':", source, re.S)
        self.assertIsNotNone(match, "MESSAGES literal not found")
        defined = set(re.findall(r"'([a-z_0-9]+)':", match.group(1)))
        called = set(
            re.findall(
                r"(?:get_message|log_info|log_success|log_error|log_warning|log_raw)\s*\(\s*'([a-z_0-9]+)'",
                source,
            )
        )
        orphans = sorted(defined - called)
        self.assertEqual(orphans, [], "orphan message keys (defined but never used)")


class ConstantsTest(unittest.TestCase):
    """Sanity checks on module constants."""

    def test_default_env_root_is_rt_env(self):
        source = TOUCH_ENV.read_text(encoding="utf-8")
        self.assertIn('DEFAULT_ENV_ROOT = "~/.rt-env"', source)

    def test_venv_layout_relative(self):
        source = TOUCH_ENV.read_text(encoding="utf-8")
        self.assertIn('VENV_DIR_RELATIVE = "venv/rt-env"', source)


if __name__ == "__main__":
    unittest.main(verbosity=2)
