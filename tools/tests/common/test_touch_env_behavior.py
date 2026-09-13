"""Behavior tests for tools/touch_env.py (no installer side effects).

Covers tools/tests/README.md section 1.2/1.3 (keep-sdk decision) and the pure
helpers (parse_repo_url, safe removal, message lookup). These tests exist
because a P0 bug ("--keep-sdk no" treated as truthy string) slipped
through when only the parameter surface was tested.

Also covers persist_custom_repos (rt-env.config merge/upsert/clean of the
--repo-* overrides) and the setup_repositories source priority
(CLI custom_repos > rt-env.config persisted values > env.json/builtin
defaults), per .omo/plans/persist-custom-repos.md section 3.4.

Run:  python tools/tests/common/test_touch_env_behavior.py
"""

import importlib.util
import io
import json
import os
import shutil
import sys
import tempfile
import types
import unittest
from unittest import mock
from contextlib import redirect_stdout
from pathlib import Path

TOOLS_DIR = Path(__file__).resolve().parents[3] / "tools"
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
    os.makedirs(os.path.join(root, "packages", "sdk"), exist_ok=True)
    toolchain = os.path.join(root, "toolchain", "gcc-arm-1.0")
    os.makedirs(toolchain, exist_ok=True)
    with open(os.path.join(toolchain, "tool.marker"), "w", encoding="utf-8") as f:
        f.write("keep-me")
    with open(os.path.join(root, "toolchain", "pkgs.json"), "w", encoding="utf-8") as f:
        f.write("{}")
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

    def test_keep_yes_preserves_toolchains_and_config(self):
        _make_layout(self.root)
        self._run("yes")
        self.assertFalse(os.path.exists(os.path.join(self.root, "local_pkgs")))
        new_cfg = os.path.join(self.root, "rt-env.config")
        self.assertTrue(os.path.isfile(new_cfg))
        with open(new_cfg, encoding="utf-8") as f:
            self.assertEqual(f.read(), "CFG")
        self.assertFalse(os.path.exists(os.path.join(self.root, "tools", "scripts", "cmds", ".config")))
        self.assertTrue(
            os.path.isfile(os.path.join(self.root, "toolchain", "gcc-arm-1.0", "tool.marker"))
        )
        self.assertTrue(os.path.isfile(os.path.join(self.root, "toolchain", "pkgs.json")))

    def test_keep_yes_rebuilds_venv_and_repos(self):
        _make_layout(self.root)
        self._run("yes")
        self.assertFalse(os.path.exists(os.path.join(self.root, "venv")))
        self.assertFalse(os.path.exists(os.path.join(self.root, ".venv")))
        self.assertFalse(os.path.exists(os.path.join(self.root, "packages", "packages")))
        self.assertFalse(os.path.exists(os.path.join(self.root, "packages", "sdk")))

    def test_keep_no_wipes_entire_root(self):
        # P0 regression: "no" is a truthy string and must still mean "wipe".
        _make_layout(self.root)
        self._run("no")
        self.assertFalse(os.path.exists(self.root))

    def test_unspecified_auto_mode_defaults_to_keep(self):
        _make_layout(self.root)
        self._run(None, auto=True)
        self.assertFalse(os.path.exists(os.path.join(self.root, "local_pkgs")))

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
            "Keeping toolchains (toolchain/) and configs (rt-env.config, sdk.config)",
        )

    def test_unknown_key_returns_the_key(self):
        self.assertEqual(self.module.get_message("definitely_not_a_key"), "definitely_not_a_key")

    def test_set_language_switches_table(self):
        self.module.set_language("zh")
        try:
            self.assertEqual(
                self.module.get_message("toolchain_kept"),
                "保留工具链（toolchain/）与配置（rt-env.config、sdk.config）",
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


class LoadRepoDefaultsTest(unittest.TestCase):
    """Default packages/sdk sources come from the downloaded env's env.json."""

    @classmethod
    def setUpClass(cls):
        cls.module = _load_module()

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="rt-env-defs-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)

    def _write_env_json(self, payload):
        scripts = os.path.join(self.root, "tools", "scripts")
        os.makedirs(scripts, exist_ok=True)
        path = os.path.join(scripts, "env.json")
        with open(path, "w", encoding="utf-8") as f:
            json.dump(payload, f)

    def _defaults(self):
        config = types.SimpleNamespace(env_root=self.root, use_cn=False)
        with redirect_stdout(io.StringIO()):
            return self.module.load_repo_defaults(config)

    def test_urls_and_branches_from_env_json(self):
        self._write_env_json({
            "repositories": {
                "packages": {
                    "url": "https://fork.example/packages.git",
                    "branch": "dev",
                    "mirror": {
                        "url": "https://mirror.example/packages.git",
                        "branch": "dev-cn",
                    },
                },
            },
        })
        defaults = self._defaults()
        self.assertEqual(defaults["packages"]["url"], "https://fork.example/packages.git")
        self.assertEqual(defaults["packages"]["branch"], "dev")
        self.assertEqual(defaults["packages"]["mirror_url"], "https://mirror.example/packages.git")
        self.assertEqual(defaults["packages"]["mirror_branch"], "dev-cn")

    def test_missing_env_json_falls_back_to_constants(self):
        defaults = self._defaults()
        self.assertEqual(defaults["packages"]["url"], self.module.REPO_PACKAGES_GITHUB)
        self.assertEqual(defaults["sdk"]["url"], self.module.REPO_SDK_GITHUB)
        self.assertEqual(defaults["packages"]["branch"], "")
        self.assertEqual(defaults["packages"]["mirror_url"], self.module.REPO_PACKAGES_GITEE)

    def test_malformed_env_json_falls_back_to_constants(self):
        scripts = os.path.join(self.root, "tools", "scripts")
        os.makedirs(scripts, exist_ok=True)
        with open(os.path.join(scripts, "env.json"), "w", encoding="utf-8") as f:
            f.write("{not json")
        defaults = self._defaults()
        self.assertEqual(defaults["sdk"]["url"], self.module.REPO_SDK_GITHUB)

    def test_partial_env_json_only_overrides_listed_repos(self):
        self._write_env_json({
            "repositories": {
                "packages": {"url": "https://fork.example/packages.git"},
            },
        })
        defaults = self._defaults()
        self.assertEqual(defaults["packages"]["url"], "https://fork.example/packages.git")
        self.assertEqual(defaults["sdk"]["url"], self.module.REPO_SDK_GITHUB)
        # mirror untouched when env.json carries none for that repo
        self.assertEqual(defaults["packages"]["mirror_url"], self.module.REPO_PACKAGES_GITEE)

    def test_mirror_without_branch_inherits_primary_branch(self):
        self._write_env_json({
            "repositories": {
                "sdk": {
                    "url": "https://fork.example/sdk.git",
                    "branch": "lts-3.2",
                    "mirror": {"url": "https://mirror.example/sdk.git"},
                },
            },
        })
        defaults = self._defaults()
        self.assertEqual(defaults["sdk"]["mirror_branch"], "lts-3.2")


class SetupRepositoriesOrderTest(unittest.TestCase):
    """env is cloned before packages/sdk so env.json can drive their defaults."""

    def setUp(self):
        self.module = _load_module()
        self.root = tempfile.mkdtemp(prefix="rt-env-order-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.calls = []
        self._orig_clone = self.module.clone_repository
        self.module.clone_repository = self._fake_clone
        self.addCleanup(setattr, self.module, "clone_repository", self._orig_clone)

    def _fake_clone(self, config, repo_name, url, dest_rel, branch="", depth=1):
        self.calls.append((repo_name, url, branch))
        if repo_name == "env":
            # emulate: env.json only exists once env has been cloned
            scripts = os.path.join(self.root, "tools", "scripts")
            os.makedirs(scripts, exist_ok=True)
            with open(os.path.join(scripts, "env.json"), "w", encoding="utf-8") as f:
                json.dump({
                    "repositories": {
                        "packages": {
                            "url": "https://fork.example/packages.git",
                            "branch": "dev",
                        },
                    },
                }, f)

    def _run(self, use_cn=False):
        config = types.SimpleNamespace(
            env_root=self.root, use_cn=use_cn, custom_repos={})
        with redirect_stdout(io.StringIO()):
            self.module.setup_repositories(config)
        return self.calls

    def test_env_cloned_first(self):
        calls = self._run()
        self.assertEqual([name for name, _, _ in calls], ["env", "packages", "sdk"])

    def test_packages_default_from_downloaded_env_json(self):
        calls = self._run()
        by_name = dict((name, (url, branch)) for name, url, branch in calls)
        self.assertEqual(by_name["packages"], ("https://fork.example/packages.git", "dev"))
        # sdk not listed in env.json -> built-in constant, no branch pin
        self.assertEqual(by_name["sdk"], (self.module.REPO_SDK_GITHUB, ""))

    def test_cn_mirror_selected_from_env_json_fallback(self):
        calls = self._run(use_cn=True)
        by_name = dict((name, (url, branch)) for name, url, branch in calls)
        # packages has no mirror in the seeded env.json -> gitee constant keeps
        # its own default branch (a fork's primary branch must not leak into
        # the built-in official mirror)
        self.assertEqual(by_name["packages"], (self.module.REPO_PACKAGES_GITEE, ""))
        self.assertEqual(by_name["sdk"], (self.module.REPO_SDK_GITEE, ""))

    def test_env_repo_uses_builtin_bootstrap_url(self):
        calls = self._run()
        env_url = calls[0][1]
        self.assertEqual(env_url, self.module.REPO_ENV_GITHUB)

    def test_custom_repos_still_win(self):
        config = types.SimpleNamespace(
            env_root=self.root,
            use_cn=False,
            custom_repos={"packages": {"url": "https://custom.example/p.git", "branch": "x"}},
        )
        with redirect_stdout(io.StringIO()):
            self.module.setup_repositories(config)
        by_name = dict((name, (url, branch)) for name, url, branch in self.calls)
        self.assertEqual(by_name["packages"], ("https://custom.example/p.git", "x"))


class ConfigStringSymbolTest(unittest.TestCase):
    """Line-level .config parser behind the persisted-repo overrides."""

    @classmethod
    def setUpClass(cls):
        cls.module = _load_module()

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="rt-env-sym-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)

    def _write(self, text):
        path = os.path.join(self.root, "rt-env.config")
        with open(path, "w", encoding="utf-8") as f:
            f.write(text)
        return path

    def test_quoted_value_is_returned_unquoted(self):
        path = self._write('CONFIG_SYS_ENV_REPO_URL="https://example.com/env.git"\n')
        self.assertEqual(
            self.module._config_string_symbol(path, "SYS_ENV_REPO_URL"),
            "https://example.com/env.git",
        )

    def test_absent_symbol_returns_none(self):
        path = self._write("CONFIG_SYS_AUTO_UPDATE_PKGS=y\n")
        self.assertIsNone(self.module._config_string_symbol(path, "SYS_ENV_REPO_URL"))

    def test_missing_file_returns_none(self):
        missing = os.path.join(self.root, "rt-env.config")
        self.assertIsNone(self.module._config_string_symbol(missing, "SYS_ENV_REPO_URL"))


class PersistedRepoOverridesTest(unittest.TestCase):
    """rt-env.config -> {repo: {url, branch}} gate rules."""

    @classmethod
    def setUpClass(cls):
        cls.module = _load_module()

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="rt-env-ovr-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)

    def _write_config(self, lines):
        with open(os.path.join(self.root, "rt-env.config"), "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")

    def _overrides(self):
        config = types.SimpleNamespace(env_root=self.root)
        return self.module._persisted_repo_overrides(config)

    def test_url_without_branch_yields_empty_branch(self):
        self._write_config(['CONFIG_SYS_ENV_REPO_URL="https://example.com/env.git"'])
        self.assertEqual(
            self._overrides(),
            {"env": {"url": "https://example.com/env.git", "branch": ""}},
        )

    def test_empty_url_means_no_override(self):
        self._write_config(['CONFIG_SYS_SDK_REPO_URL=""'])
        self.assertEqual(self._overrides(), {})

    def test_missing_file_means_no_overrides(self):
        self.assertEqual(self._overrides(), {})


class PersistCustomReposTest(unittest.TestCase):
    """rt-env.config merge/upsert/clean semantics of persist_custom_repos."""

    ALL_REPO_LINES = [
        'CONFIG_SYS_ENV_REPO_URL="https://old.example/env.git"',
        'CONFIG_SYS_ENV_REPO_BRANCH="old-env"',
        'CONFIG_SYS_SDK_REPO_URL="https://old.example/sdk.git"',
        'CONFIG_SYS_SDK_REPO_BRANCH="old-sdk"',
        'CONFIG_SYS_PKGS_REPO_URL="https://old.example/packages.git"',
        'CONFIG_SYS_PKGS_REPO_BRANCH="old-pkgs"',
    ]
    UNRELATED = "CONFIG_SYS_AUTO_UPDATE_PKGS=y"

    @classmethod
    def setUpClass(cls):
        cls.module = _load_module()

    def setUp(self):
        self.root = tempfile.mkdtemp(prefix="rt-env-persist-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)

    def _config_path(self):
        return os.path.join(self.root, "rt-env.config")

    def _write_config(self, lines):
        with open(self._config_path(), "w", encoding="utf-8") as f:
            f.write("\n".join(lines) + "\n")

    def _read_config(self):
        with open(self._config_path(), encoding="utf-8") as f:
            return f.read()

    def _persist(self, custom_repos, env_root=None):
        config = types.SimpleNamespace(
            env_root=env_root or self.root, custom_repos=custom_repos
        )
        with redirect_stdout(io.StringIO()):
            self.module.persist_custom_repos(config)

    def test_merge_updates_env_and_preserves_unrelated_lines(self):
        self._write_config([
            "CONFIG_SYS_DOWNLOAD_SERVER_GITHUB=y",
            "CONFIG_SYS_AUTO_UPDATE_PKGS=y",
            'CONFIG_SYS_ENV_REPO_URL="https://stale.example/env.git"',
        ])
        self._persist({"env": {"url": "https://example.com/env.git", "branch": "dev"}})
        content = self._read_config()
        self.assertEqual(
            content,
            "CONFIG_SYS_DOWNLOAD_SERVER_GITHUB=y\n"
            "CONFIG_SYS_AUTO_UPDATE_PKGS=y\n"
            'CONFIG_SYS_ENV_REPO_URL="https://example.com/env.git"\n'
            'CONFIG_SYS_ENV_REPO_BRANCH="dev"\n',
        )
        self.assertNotIn("SYS_SDK_REPO", content)
        self.assertNotIn("SYS_PKGS_REPO", content)

    def test_unspecified_repos_are_cleared_per_repo(self):
        self._write_config(self.ALL_REPO_LINES + [self.UNRELATED])
        self._persist({"env": {"url": "https://new.example/env.git", "branch": "b"}})
        self.assertEqual(
            self._read_config(),
            'CONFIG_SYS_ENV_REPO_URL="https://new.example/env.git"\n'
            'CONFIG_SYS_ENV_REPO_BRANCH="b"\n'
            "CONFIG_SYS_AUTO_UPDATE_PKGS=y\n",
        )

    def test_empty_custom_repos_clears_every_repo_line(self):
        self._write_config(self.ALL_REPO_LINES + [self.UNRELATED])
        self._persist({})
        self.assertEqual(self._read_config(), "CONFIG_SYS_AUTO_UPDATE_PKGS=y\n")
        self.assertTrue(os.path.isfile(self._config_path()))

    def test_pure_create_writes_only_the_target_lines(self):
        self._persist({"sdk": {"url": "u", "branch": "b"}})
        self.assertTrue(os.path.isfile(self._config_path()))
        self.assertEqual(
            self._read_config(),
            'CONFIG_SYS_SDK_REPO_URL="u"\nCONFIG_SYS_SDK_REPO_BRANCH="b"\n',
        )

    def test_no_file_and_no_custom_repos_is_a_no_op(self):
        self._persist({})
        self.assertFalse(os.path.exists(self._config_path()))

    def test_fresh_install_creates_missing_env_root_and_config(self):
        # regression: on a fresh install persist_custom_repos runs before the
        # env root exists; the write must create the missing directories
        # instead of failing with FileNotFoundError
        nested = os.path.join(self.root, "a", "b")
        self.assertFalse(os.path.exists(nested))
        self._persist(
            {"env": {"url": "https://example.com/env.git", "branch": "dev"}},
            env_root=nested,
        )
        config_file = os.path.join(nested, "rt-env.config")
        self.assertTrue(os.path.isfile(config_file))
        self.assertEqual(
            self._read_file(config_file),
            'CONFIG_SYS_ENV_REPO_URL="https://example.com/env.git"\n'
            'CONFIG_SYS_ENV_REPO_BRANCH="dev"\n',
        )

    def test_fresh_install_persist_then_upsert_in_created_env_root(self):
        nested = os.path.join(self.root, "a", "b")
        self._persist(
            {"env": {"url": "https://example.com/env.git", "branch": "dev"}},
            env_root=nested,
        )
        self._persist(
            {
                "env": {"url": "https://example.com/env.git", "branch": "dev2"},
                "sdk": {"url": "https://example.com/sdk.git", "branch": "s"},
            },
            env_root=nested,
        )
        config_file = os.path.join(nested, "rt-env.config")
        self.assertTrue(os.path.isfile(config_file))
        self.assertEqual(
            self._read_file(config_file),
            'CONFIG_SYS_ENV_REPO_URL="https://example.com/env.git"\n'
            'CONFIG_SYS_ENV_REPO_BRANCH="dev2"\n'
            'CONFIG_SYS_SDK_REPO_URL="https://example.com/sdk.git"\n'
            'CONFIG_SYS_SDK_REPO_BRANCH="s"\n',
        )

    @staticmethod
    def _read_file(path):
        with open(path, encoding="utf-8") as f:
            return f.read()


class SetupRepositoriesPriorityTest(unittest.TestCase):
    """Source priority: CLI custom_repos > rt-env.config > env.json/builtin."""

    PERSISTED_LINES = [
        'CONFIG_SYS_ENV_REPO_URL="https://persist.example/env.git"',
        'CONFIG_SYS_ENV_REPO_BRANCH="p-env"',
        'CONFIG_SYS_SDK_REPO_URL="https://persist.example/sdk.git"',
        'CONFIG_SYS_SDK_REPO_BRANCH="p-sdk"',
    ]

    def setUp(self):
        self.module = _load_module()
        self.root = tempfile.mkdtemp(prefix="rt-env-prio-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.calls = []
        self._orig_clone = self.module.clone_repository
        self.module.clone_repository = self._fake_clone
        self.addCleanup(setattr, self.module, "clone_repository", self._orig_clone)

    def _fake_clone(self, config, repo_name, url, dest_rel, branch="", depth=1):
        self.calls.append((repo_name, url, branch))
        if repo_name == "env":
            # the cloned env carries env.json with its own packages/sdk defaults
            scripts = os.path.join(self.root, "tools", "scripts")
            os.makedirs(scripts, exist_ok=True)
            with open(os.path.join(scripts, "env.json"), "w", encoding="utf-8") as f:
                json.dump({
                    "repositories": {
                        "packages": {"url": "https://envjson.example/packages.git", "branch": "ej-pkgs"},
                        "sdk": {"url": "https://envjson.example/sdk.git", "branch": "ej-sdk"},
                    },
                }, f)

    def _write_persisted(self):
        with open(os.path.join(self.root, "rt-env.config"), "w", encoding="utf-8") as f:
            f.write("\n".join(self.PERSISTED_LINES) + "\n")

    def _run(self, custom_repos=None):
        config = types.SimpleNamespace(
            env_root=self.root, use_cn=False, custom_repos=custom_repos or {})
        with redirect_stdout(io.StringIO()):
            self.module.setup_repositories(config)
        return dict((name, (url, branch)) for name, url, branch in self.calls)

    def test_persisted_values_beat_defaults(self):
        self._write_persisted()
        by_name = self._run()
        # env: persisted beats the built-in bootstrap constant
        self.assertEqual(by_name["env"], ("https://persist.example/env.git", "p-env"))
        # sdk: persisted beats the env.json default of the just-cloned env
        self.assertEqual(by_name["sdk"], ("https://persist.example/sdk.git", "p-sdk"))
        # packages has no persisted lines: the env.json default still applies
        self.assertEqual(by_name["packages"], ("https://envjson.example/packages.git", "ej-pkgs"))

    def test_cli_value_beats_persisted_value(self):
        self._write_persisted()
        by_name = self._run({"env": {"url": "https://cli.example/env.git", "branch": "cli"}})
        self.assertEqual(by_name["env"], ("https://cli.example/env.git", "cli"))
        # a repo the CLI does not name keeps its persisted value
        self.assertEqual(by_name["sdk"], ("https://persist.example/sdk.git", "p-sdk"))


class CopyEnvScriptsTest(unittest.TestCase):
    """Root activator generation: delegator vs legacy copy, user config."""

    def setUp(self):
        self.module = _load_module()
        self.root = tempfile.mkdtemp(prefix="rt-env-activator-")
        self.addCleanup(shutil.rmtree, self.root, ignore_errors=True)
        self.scripts = os.path.join(self.root, "tools", "scripts")
        os.makedirs(self.scripts, exist_ok=True)

    def _write_inner(self, content):
        with open(os.path.join(self.scripts, "env.sh"), "w", encoding="utf-8") as f:
            f.write(content)

    def _run(self):
        with mock.patch.object(self.module.platform, "system", return_value="Linux"):
            with redirect_stdout(io.StringIO()):
                self.module.copy_env_scripts(types.SimpleNamespace(env_root=self.root))

    def test_generates_relative_anchored_delegator(self):
        self._write_inner("# inner\n")
        self._run()
        with open(os.path.join(self.root, "env.sh"), encoding="utf-8") as f:
            content = f.read()
        self.assertNotIn("RT_ENV_ROOT=", content)
        self.assertIn(
            '. "$(cd "$(dirname "$_RT_SELF")" && pwd)/tools/scripts/env.sh"',
            content,
        )
        self.assertIn('${ZSH_VERSION:-}', content)
        self.assertNotIn(self.root, content)

    def test_missing_inner_is_a_no_op(self):
        self._run()
        self.assertFalse(os.path.exists(os.path.join(self.root, "env.sh")))
        self.assertFalse(os.path.exists(os.path.join(self.root, "env.user.sh")))


if __name__ == "__main__":
    unittest.main(verbosity=2)
