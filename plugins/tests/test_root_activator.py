"""Unit tests for the post-upgrade root activator regeneration.

Covers cmds.cmd_upgrade._write_root_activator: a relative-anchored thin
delegator is always generated when the inner script exists, and a no-op
when it is missing. Legacy verbatim copy was removed together with the
RT_ENV_ROOT signal (upstream master never had it).

Run from the repository root:
    python -m unittest plugins.tests.test_root_activator
"""

import os
import shutil
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

    def test_generates_relative_anchored_delegator(self):
        self._write_inner("# inner\n")
        self._run()
        content = self._read_root()
        self.assertNotIn("RT_ENV_ROOT=", content)
        self.assertIn(
            '. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/tools/scripts/env.sh"',
            content,
        )
        self.assertNotIn(self.root, content)

    def test_missing_inner_is_a_no_op(self):
        self._run()
        self.assertFalse(os.path.exists(os.path.join(self.root, "env.sh")))

    def test_user_config_never_touched_by_refresh(self):
        user = os.path.join(self.root, "env.user.sh")
        with open(user, "w", encoding="utf-8") as f:
            f.write("# mine\n")
        self._write_inner("# inner\n")
        self._run()
        with open(user, encoding="utf-8") as f:
            self.assertEqual(f.read(), "# mine\n")


if __name__ == "__main__":
    unittest.main(verbosity=2)
