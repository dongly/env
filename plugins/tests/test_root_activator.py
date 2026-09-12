"""Unit tests for the post-upgrade root activator regeneration.

Covers cmds.cmd_upgrade._write_root_activator: thin
delegator when the upgraded env script understands RT_ENV_ROOT, verbatim
copy for legacy scripts, and a no-op when the inner script is missing.

Run from the repository root:
    python -m unittest plugins.tests.test_root_activator
"""

import os
import shutil
import sys
import tempfile
import unittest

from cmds import cmd_upgrade


class WriteRootActivatorTest(unittest.TestCase):
    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="rt-env-activator-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.scripts = os.path.join(self.root, "tools", "scripts")
        os.makedirs(self.scripts, exist_ok=True)

    def _write_inner(self, content):
        with open(os.path.join(self.scripts, "env.sh"), "w", encoding="utf-8") as f:
            f.write(content)

    def _run(self):
        cmd_upgrade._write_root_activator(self.root, self.scripts)

    def _read_root(self):
        with open(os.path.join(self.root, "env.sh"), encoding="utf-8") as f:
            return f.read()

    def test_new_inner_produces_thin_delegator(self):
        self._write_inner('if [ -n "$RT_ENV_ROOT" ]; then\nfi\n')
        self._run()
        content = self._read_root()
        self.assertIn("RT_ENV_ROOT='%s'" % self.root, content)
        self.assertIn(". '%s'" % os.path.join(self.scripts, "env.sh"), content)

    def test_legacy_inner_is_copied_verbatim(self):
        self._write_inner("SCRIPT_DIR=legacy\n")
        self._run()
        self.assertEqual(self._read_root(), "SCRIPT_DIR=legacy\n")

    def test_missing_inner_is_a_no_op(self):
        self._run()
        self.assertFalse(os.path.exists(os.path.join(self.root, "env.sh")))

    def test_user_config_never_touched_by_refresh(self):
        user = os.path.join(self.root, "env.user.sh")
        with open(user, "w", encoding="utf-8") as f:
            f.write("# mine\n")
        self._write_inner("legacy\n")
        self._run()
        with open(user, encoding="utf-8") as f:
            self.assertEqual(f.read(), "# mine\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
