#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# File      : touch_env.py
# This file is part of RT-Thread RTOS
# COPYRIGHT (C) 2006 - 2026, RT-Thread Development Team
#
#  This program is free software; you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation; either version 2 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License along
#  with this program; if not, write to the Free Software Foundation, Inc.,
#  51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.
#
# Change Logs:
# Date           Author          Notes
# 2026-01-30     dongly         Initial version
#
# RT-Thread ENV Setup Script (Python)
# RT-Thread ENV 安装脚本 (Python)
#
# This script handles the setup of RT-Thread ENV after the repository is cloned.
# 此脚本在仓库克隆后处理 RT-Thread ENV 的设置。
# It performs the installation process:
# 执行安装过程：
# 1. Setup repositories (clone env, then packages and sdk) - 设置仓库（先克隆 env，再克隆 packages 与 sdk）
#    Default packages/sdk sources come from the downloaded env's env.json;
#    built-in constants are only a bootstrap fallback.
#    packages/sdk 的默认源来自已下载 env 的 env.json；内置常量仅作引导兜底。
# 2. Create Python virtual environment - 创建 Python 虚拟环境
# 3. Install Python packages - 安装 Python 包
# 4. Show next steps - 显示后续步骤
#
# Usage:
# 用法:
#   python touch_env.py [OPTIONS]
#
# Options:
# 选项:
#   --env-root <path>          Installation root directory (default: ~/.rt-env)
#                              安装 ENV_ROOT（默认：~/.rt-env）
#   --use-cn                   Use China mirror (Gitee, TUNA PyPI)
#                              使用中国镜像（Gitee, TUNA PyPI）
#   --language <lang>          Language: 'en' or 'zh'
#                              语言：'en' 或 'zh'
#   --auto-mode                Auto-install without prompts
#                              自动安装，无提示
#   --keep-sdk <yes|no>  Keep downloaded toolchains (local_pkgs) and config
#                              when ENV_ROOT exists (default: yes; prompt if omitted)
#                              当 ENV 已存在时保留已下载的工具链（local_pkgs）与配置
#                              （默认：yes；未指定时交互询问）
#   --repo-env <url>           Custom env repository URL, e.g.:
#                              自定义 env 仓库 URL,例如：
#                                  https://github.com/user/env.git#branch1  <--- branch is optional
#                                  https://github.com/user/env.git          <--- 分支是可选的
#   --repo-packages <url>      Custom packages repository URL
#                              自定义 packages 仓库 URL
#   --repo-sdk <url>           Custom sdk repository URL
#                              自定义 sdk 仓库 URL
#
# Examples:
# 示例:
#   python touch_env.py
#   python touch_env.py --env-root /path/to/env
#   python touch_env.py --repo-env https://github.com/user/env.git#branch1
#   python touch_env.py --keep-sdk no --repo-packages https://github.com/user/packages.git#my-branch
#

import os
import sys
import argparse
import platform
import shutil
import subprocess
import json
from pathlib import Path
from datetime import datetime

# ============================================================================
# Configuration Constants
# ============================================================================

# Bootstrap fallback sources.
# The downloaded env's env.json (repositories.*) is the canonical default for
# packages/sdk; these constants only apply when env.json cannot be read.
# The env repository itself is the bootstrap (chicken-and-egg) and always
# uses these constants unless overridden via --repo-env.
# 引导兜底源。已下载 env 的 env.json（repositories.*）是 packages/sdk 的
# 规范默认源；仅当 env.json 无法读取时才使用以下常量。env 仓库自身是
# 引导起点（先有鸡还是先有蛋），除 --repo-env 覆盖外始终使用这些常量。
REPO_PACKAGES_GITHUB = "https://github.com/RT-Thread/packages.git"
REPO_ENV_GITHUB = "https://github.com/RT-Thread/env.git"
REPO_SDK_GITHUB = "https://github.com/RT-Thread/sdk.git"

# Gitee mirrors (China)
REPO_PACKAGES_GITEE = "https://gitee.com/RT-Thread-Mirror/packages.git"
REPO_ENV_GITEE = "https://gitee.com/RT-Thread-Mirror/env.git"
REPO_SDK_GITEE = "https://gitee.com/RT-Thread-Mirror/sdk.git"

# PyPI mirror
PYPI_MIRROR_CN = "https://pypi.tuna.tsinghua.edu.cn/simple"

# Internal default values
VENV_DIR_RELATIVE = "venv/rt-env"
SCRIPTS_DIR_RELATIVE = "tools/scripts"

# Default installation root directory
DEFAULT_ENV_ROOT = "~/.rt-env"

# Portable Python directory name
PORTABLE_PYTHON_DIR = "python"

# ============================================================================
# Python Version Check
# ============================================================================

MIN_PYTHON_VERSION = (3, 6)

if sys.version_info < MIN_PYTHON_VERSION:
    print(
        f"Error: Python {MIN_PYTHON_VERSION[0]}.{MIN_PYTHON_VERSION[1]} or higher is required.", file=sys.stderr)
    print(f"Current Python version: {sys.version}", file=sys.stderr)
    sys.exit(1)

# ============================================================================
# Runtime Configuration
# ============================================================================

class RuntimeConfig:
    """Runtime configuration management"""
    def __init__(self):
        self._language = 'en'  # Default language

    @property
    def language(self):
        """Get current language"""
        return self._language

    @language.setter
    def language(self, value):
        """Set language"""
        self._language = value

# Global runtime configuration instance
_runtime_config = RuntimeConfig()

def get_language():
    """Get current language"""
    return _runtime_config.language

def set_language(lang):
    """Set language"""
    _runtime_config.language = lang

# ============================================================================
# TouchEnvConfig Class
# ============================================================================


class TouchEnvConfig:
    """Configuration management class for touch_env"""

    def __init__(self, args):
        # Check if using default env-root
        default_env_root = os.path.expanduser(DEFAULT_ENV_ROOT)
        if args.env_root == default_env_root:
            # Temporarily set language for log_info
            set_language(args.language)
            log_info('using_default_env_root', default_env_root)

        # Set language in runtime config
        set_language(args.language)

        self.env_root = args.env_root
        self.use_cn = args.use_cn
        self.language = args.language
        self.auto_mode = args.auto_mode
        self.keep_sdk = args.keep_sdk
        self.custom_repos = args.custom_repos

        # Compute internal paths
        self._compute_paths()

        # Validate configuration
        self._validate()

    def _compute_paths(self):
        """Compute internal paths based on env_root"""
        self.venv_dir = os.path.join(self.env_root, VENV_DIR_RELATIVE)
        self.scripts_dir = os.path.join(self.env_root, SCRIPTS_DIR_RELATIVE)

    def _validate(self):
        """Validate configuration"""
        # Validate env_root
        if not self.env_root:
            raise ValueError("env_root is required")

        # Validate language
        if self.language not in ['en', 'zh']:
            raise ValueError(
                f"Invalid language: {self.language}. Must be 'en' or 'zh'")

        # custom_repos is built internally in parse_arguments, no need for extensive validation
        # Basic type check is sufficient
        if self.custom_repos and not isinstance(self.custom_repos, dict):
            raise ValueError("custom_repos must be a dictionary")

# ============================================================================
# Internationalization Messages
# ============================================================================


MESSAGES = {
    'en': {
        'info': 'INFO',
        'success': 'SUCCESS',
        'warning': 'WARNING',
        'error': 'ERROR',
        'cloning': 'Cloning {0} to {1}',
        'cloned': 'Cloned {0}',
        'dir_exists': 'Directory already exists: {0}',
        'generating_kconfig': 'Generating Kconfig: {0}',
        'creating_venv': 'Creating virtual environment at: {0}',
        'venv_created': 'Virtual environment created',
        'venv_exists': 'Virtual environment already exists',
        'upgrading_pip': 'Upgrading pip...',
        'installing_packages': 'Installing Python packages...',
        'installed_packages': 'Python packages installed successfully',
        'using_cn_mirror': 'Using China mirror',
        'using_pypi_mirror': 'Using PyPI mirror: {0}',
        'copied_env_script': 'Copied env script: {0}',
        'activator_created': 'Created thin activator: {0}',
        'user_config_created': 'Created user customization file: {0}',
        'fixed_guiconfig': 'Fixed guiconfig.py (added missing import)',
        'setup_complete': 'RT-Thread ENV installation completed!',
        'next_steps': 'Next steps:',
        'activate_env': '1. Activate environment:',
        'add_to_profile': '2. Add to profile:',
        'install_toolchain': '3. Install toolchains:',
        'install_toolchain_cmd': '   Run `sdk` command to install required toolchains',
        'after_activation': '4. After activation, you can use:',
        'menuconfig': '     - menuconfig    : Configure project',
        'menuconfig_s': '     - menuconfig -s : Configure RT-Thread ENV',
        'pkgs': '     - pkgs          : Package manager',
        'scons': '     - scons         : Build project',
        'sdk': '     - sdk           : Install toolchains',
        'plugin': '     - plugin        : Manage local Env plugins',
        'webui': '     - webui         : Manage and run the local Env WebUI',
        'clone_failed': 'Git clone failed: {0}',
        'invalid_git_repo': 'Invalid git repository: {0}',
        'venv_not_found': 'Virtual environment not found',
        'package_install_failed': 'Package installation failed: {0}',
        'venv_creation_failed': 'Virtual environment creation failed: {0}',
        'fix_guiconfig_failed': 'Failed to fix guiconfig.py: {0}',
        'using_custom_repo': 'Using custom repository: {0}',
        'using_custom_repo_branch': 'Using custom repository: {0} (branch: {1})',
        'env_json_defaults': 'Repository defaults loaded from env.json: {0}',
        'env_json_fallback': 'Cannot read repository defaults from {0}, using built-in sources',
        'env_root_exists': 'Existing RT-Thread ENV detected at: {0}',
        'toolchain_keep_prompt': 'Keep downloaded toolchains (local_pkgs) and config? [Y/n]: ',
        'toolchain_kept': 'Keeping toolchains (local_pkgs) and config',
        'toolchain_removed': 'Removing entire existing directory',
        'auto_mode_preserving': 'Auto mode: keeping toolchains (local_pkgs) and config',
        'deleting_item': 'Removing: {0}',
        'installation_cancelled': 'Installation cancelled',
        'installation_failed': 'Installation failed: {0}',
        'file_delete_failed': 'Failed to delete file: {0} - {1}',
        'dir_delete_failed': 'Failed to delete directory: {0} - {1}',
        'deleting_env_root': 'Deleting existing directory: {0}',
        'deleting_env_root_failed': 'Failed to delete directory: {0}',
        'manual_delete_required': 'Please manually delete directory: {0}, then retry',
        'start': '[PY]Starting RT-Thread ENV installation...',
        'using_default_env_root': 'Using default ENV_ROOT: {0}',
        'env_root_prompt': 'Enter installation root directory (ENV_ROOT)',
        'env_root_default': '[default: {0}]',
        'python_path_invalid': 'Path contains {0} (not allowed in Python paths)',
        'python_path_creating_dir': 'Creating directory: {0}',
        'python_path_no_permission': 'No write permission for directory: {0}',
    },
    'zh': {
        'info': '信息',
        'success': '成功',
        'warning': '警告',
        'error': '错误',
        'cloning': '正在克隆: {0} 到 {1}',
        'cloned': '已克隆: {0}',
        'dir_exists': '目录已存在: {0}',
        'generating_kconfig': '生成 Kconfig: {0}',
        'creating_venv': '正在创建虚拟环境: {0}',
        'venv_created': '虚拟环境创建完成',
        'venv_exists': '虚拟环境已存在',
        'upgrading_pip': '正在升级 pip...',
        'installing_packages': '正在安装 Python 包...',
        'installed_packages': 'Python 包安装完成',
        'using_cn_mirror': '使用中国镜像源',
        'using_pypi_mirror': '使用 PyPI 镜像: {0}',
        'copied_env_script': '已复制 env 脚本: {0}',
        'activator_created': '已创建薄激活器: {0}',
        'user_config_created': '已创建用户自定义文件: {0}',
        'fixed_guiconfig': '已修复 guiconfig.py（添加缺失的导入）',
        'setup_complete': 'RT-Thread ENV 安装完成！',
        'next_steps': '后续步骤:',
        'activate_env': '1. 激活环境:',
        'add_to_profile': '2. 添加到配置文件:',
        'install_toolchain': '3. 安装工具链:',
        'install_toolchain_cmd': '   运行 `sdk` 命令安装所需的工具链',
        'after_activation': '4. 激活后可用命令:',
        'menuconfig': '     - menuconfig    : 配置项目',
        'menuconfig_s': '     - menuconfig -s : 配置 RT-Thread ENV',
        'pkgs': '     - pkgs          : 包管理器',
        'scons': '     - scons         : 编译项目',
        'sdk': '     - sdk           : 安装工具链',
        'plugin': '     - plugin        : 管理本地 Env 插件',
        'webui': '     - webui         : 管理并运行本地 Env WebUI',
        'clone_failed': 'Git 克隆失败: {0}',
        'invalid_git_repo': '无效的 git 仓库: {0}',
        'venv_not_found': '找不到虚拟环境',
        'package_install_failed': '包安装失败: {0}',
        'venv_creation_failed': '虚拟环境创建失败: {0}',
        'fix_guiconfig_failed': '修复 guiconfig.py 失败: {0}',
        'using_custom_repo': '使用自定义仓库: {0}',
        'using_custom_repo_branch': '使用自定义仓库: {0} (分支: {1})',
        'env_json_defaults': '仓库默认配置已从 env.json 加载: {0}',
        'env_json_fallback': '无法从 {0} 读取仓库默认配置，使用内置源',
        'env_root_exists': '检测到已存在的 RT-Thread ENV: {0}',
        'toolchain_keep_prompt': '保留已下载的工具链（local_pkgs）与配置？[Y/n]: ',
        'toolchain_kept': '保留工具链（local_pkgs）与配置',
        'toolchain_removed': '删除整个现有目录',
        'auto_mode_preserving': '自动模式：保留工具链（local_pkgs）与配置',
        'deleting_item': '正在移除: {0}',
        'installation_cancelled': '安装已取消',
        'installation_failed': '安装失败: {0}',
        'file_delete_failed': '删除文件失败: {0} - {1}',
        'dir_delete_failed': '删除目录失败: {0} - {1}',
        'deleting_env_root': '正在删除现有目录: {0}',
        'deleting_env_root_failed': '删除目录失败: {0}',
        'manual_delete_required': '请手动删除目录: {0}，然后重试',
        'start': '[PY]开始 RT-Thread ENV 安装...',
        'using_default_env_root': '使用默认 ENV_ROOT: {0}',
        'env_root_prompt': '请选择怎样处理现存目录(ENV_ROOT)',
        'env_root_default': '[默认: {0}]',
        'python_path_invalid': '路径包含 {0}（Python 路径中不允许）',
        'python_path_creating_dir': '正在创建目录: {0}',
        'python_path_no_permission': '没有目录的写入权限: {0}',
    }
        }

# ============================================================================
# Global Variables
# ============================================================================

# ============================================================================
# Message Functions
# ============================================================================


def get_message(key):
    """Get localized message using current language"""
    lang = get_language()
    return MESSAGES.get(lang, {}).get(key, key)


def log_info(key, *args):
    """Log info message to stdout"""
    msg = get_message(key)
    if args:
        msg = msg.format(*args)
    print(f"\033[0;36m[{get_message('info')}]\033[0m {msg}")


def log_success(key, *args):
    """Log success message to stdout"""
    msg = get_message(key)
    if args:
        msg = msg.format(*args)
    print(f"\033[0;32m[{get_message('success')}]\033[0m {msg}")


def log_error(key, *args):
    """Log error message to stderr"""
    msg = get_message(key)
    if args:
        msg = msg.format(*args)
    print(f"\033[0;31m[{get_message('error')}]\033[0m {msg}", file=sys.stderr)


def log_warning(key, *args):
    """Log warning message to stderr"""
    msg = get_message(key)
    if args:
        msg = msg.format(*args)
    print(f"\033[0;33m[{get_message('warning')}]\033[0m {msg}", file=sys.stderr)


def log_raw(key, *args, **kwargs):
    """Log raw message using current language"""
    msg = get_message(key)
    if args:
        msg = msg.format(*args)
    print(msg, **kwargs)

# ============================================================================
# Repository Functions
# ============================================================================


def clone_repository(config, repo_name, url, dest_rel, branch='', depth=1):
    """
    Clone Git repository with cleanup on failure

    Args:
        config: TouchEnvConfig instance
        repo_name: Repository name ('packages', 'sdk', or 'env')
        url: Repository URL
        dest_rel: Destination path relative to env_root
        branch: Optional branch name
        depth: Clone depth (default 1 for shallow clone)

    Raises:
        RuntimeError: If clone fails
    """
    dest_path = os.path.join(config.env_root, dest_rel)

    # If directory exists, verify it's a valid git repository
    if os.path.exists(dest_path):
        try:
            result = subprocess.run(
                ['git', 'rev-parse', '--git-dir'],
                cwd=dest_path,
                capture_output=True,
                text=True,
                check=True
            )
            log_success('dir_exists', dest_path)
            return
        except subprocess.CalledProcessError:
            # Invalid git repository, need to clean up
            log_error('invalid_git_repo', dest_path)
            shutil.rmtree(dest_path, ignore_errors=True)

    # Clone repository
    log_info('cloning', url, dest_path)

    clone_args = ['git', 'clone', '--depth', str(depth)]
    if branch:
        clone_args.extend(['--branch', branch])
    clone_args.extend([url, dest_path])

    try:
        # Run without capture to show verbose git output
        subprocess.run(clone_args, check=True)
        log_success('cloned', dest_path)
    except subprocess.CalledProcessError as e:
        # Clone failed, clean up partial clone
        log_error('clone_failed', str(e))
        shutil.rmtree(dest_path, ignore_errors=True)
        raise RuntimeError(f"Failed to clone {url}") from e


def load_repo_defaults(config):
    """
    Load default packages/sdk sources from the downloaded env's env.json

    Args:
        config: TouchEnvConfig instance

    Returns:
        dict: {'packages': {...}, 'sdk': {...}}, each entry with
              'url', 'branch', 'mirror_url', 'mirror_branch';
              built-in constants where env.json provides nothing
    """
    env_json_path = os.path.join(
        config.env_root, 'tools', 'scripts', 'env.json')

    defaults = {
        'packages': {
            'url': REPO_PACKAGES_GITHUB,
            'branch': '',
            'mirror_url': REPO_PACKAGES_GITEE,
            'mirror_branch': '',
        },
        'sdk': {
            'url': REPO_SDK_GITHUB,
            'branch': '',
            'mirror_url': REPO_SDK_GITEE,
            'mirror_branch': '',
        },
    }

    try:
        with open(env_json_path, 'r', encoding='utf-8') as f:
            data = json.load(f)
        repositories = data.get('repositories', {})
        for repo_name in ('packages', 'sdk'):
            entry = repositories.get(repo_name)
            if not isinstance(entry, dict) or not entry.get('url'):
                continue
            source = defaults[repo_name]
            source['url'] = entry['url']
            source['branch'] = entry.get('branch', '')
            mirror = entry.get('mirror') or {}
            if mirror.get('url'):
                source['mirror_url'] = mirror['url']
                # a mirror without its own branch inherits the primary branch
                source['mirror_branch'] = mirror.get('branch') or source['branch']
        log_info('env_json_defaults', env_json_path)
    except (OSError, ValueError):
        log_warning('env_json_fallback', env_json_path)

    return defaults


def setup_repositories(config):
    """
    Setup all repositories (env, packages, sdk)

    The env repository is cloned first: the env.json it carries provides
    the default sources for packages and sdk.

    Args:
        config: TouchEnvConfig instance

    Raises:
        RuntimeError: If any repository setup fails
    """
    # Repository destinations
    repo_dests = {
        'env': 'tools/scripts',
        'packages': 'packages/packages',
        'sdk': 'packages/sdk'
    }

    # Clone env first (bootstrap). Its own source cannot come from its
    # env.json (chicken-and-egg), so use built-in constants or --repo-env.
    if config.custom_repos and 'env' in config.custom_repos:
        env_repo = config.custom_repos['env']
        url = env_repo['url']
        branch = env_repo.get('branch', '')

        if branch:
            log_info('using_custom_repo_branch', url, branch)
        else:
            log_info('using_custom_repo', url)
    else:
        url = REPO_ENV_GITEE if config.use_cn else REPO_ENV_GITHUB
        branch = ''

    clone_repository(config, 'env', url, repo_dests['env'], branch)

    # Default packages/sdk sources from the env just cloned
    repo_defaults = load_repo_defaults(config)

    # Clone the remaining repositories
    for repo_name in ('packages', 'sdk'):
        # Check for custom repository
        if config.custom_repos and repo_name in config.custom_repos:
            repo_info = config.custom_repos[repo_name]
            url = repo_info['url']
            branch = repo_info.get('branch', '')

            if branch:
                log_info('using_custom_repo_branch', url, branch)
            else:
                log_info('using_custom_repo', url)
        else:
            source = repo_defaults[repo_name]
            if config.use_cn:
                url = source['mirror_url']
                branch = source['mirror_branch']
            else:
                url = source['url']
                branch = source['branch']

        clone_repository(config, repo_name, url, repo_dests[repo_name], branch)

    # Generate Kconfig file
    generate_kconfig_file(config)

    # Copy env scripts
    copy_env_scripts(config)


def generate_kconfig_file(config):
    """Generate Kconfig configuration file"""
    packages_dir = os.path.join(config.env_root, 'packages')
    os.makedirs(packages_dir, exist_ok=True)

    kconfig_path = os.path.join(packages_dir, 'Kconfig')
    kconfig_content = 'source "$PKGS_DIR/packages/Kconfig"\n'

    with open(kconfig_path, 'w', encoding='utf-8') as f:
        f.write(kconfig_content)

    log_success('generating_kconfig', kconfig_path)

    # Create local_pkgs directory
    local_pkgs_dir = os.path.join(config.env_root, 'local_pkgs')
    os.makedirs(local_pkgs_dir, exist_ok=True)


def _sh_quote(text):
    """Escape single quotes for a single-quoted shell literal."""
    return text.replace("'", "'\\''")


def _ps_quote(text):
    """Escape single quotes for a single-quoted PowerShell literal."""
    return text.replace("'", "''")


def copy_env_scripts(config):
    """Install the root activator and seed the user customization file.

    Thin delegator when the cloned env scripts understand RT_ENV_ROOT,
    full copy for legacy env versions. The user customization file is
    created only when missing: it lives outside the managed repository,
    so upgrades and reinstalls never overwrite it. The same generation
    logic is mirrored in cmds/cmd_package/cmd_package_upgrade.py
    (_write_root_activator) for the pkgs --upgrade refresh path.
    """
    scripts_dir = os.path.join(config.env_root, 'tools/scripts')

    if platform.system() == 'Windows':
        name = 'env.ps1'
    else:
        name = 'env.sh'
    src = os.path.join(scripts_dir, name)
    dst = os.path.join(config.env_root, name)

    if not os.path.exists(src):
        return

    with open(src, encoding='utf-8') as f:
        inner = f.read()

    if 'RT_ENV_ROOT' in inner:
        if name.endswith('.ps1'):
            content = (
                "# Generated by the RT-Thread ENV installer. Do not edit.\r\n"
                "$env:RT_ENV_ROOT = '{0}'\r\n"
                ". '{1}'\r\n".format(_ps_quote(config.env_root), _ps_quote(src))
            )
            encoding = 'utf-8-sig'
        else:
            content = (
                "# Generated by the RT-Thread ENV installer. Do not edit.\n"
                "RT_ENV_ROOT='{0}'\n"
                ". '{1}'\n".format(_sh_quote(config.env_root), _sh_quote(src))
            )
            encoding = 'utf-8'
        with open(dst, 'w', encoding=encoding, newline='') as f:
            f.write(content)
        log_success('activator_created', dst)
    else:
        shutil.copy2(src, dst)
        log_success('copied_env_script', dst)

    _seed_user_config(config)


def _seed_user_config(config):
    """Create the user customization file with examples when missing."""
    if platform.system() == 'Windows':
        name = 'env.user.ps1'
        encoding = 'utf-8-sig'
        template = (
            "# RT-Thread ENV user customization.\r\n"
            "# Sourced by env.ps1 on every activation; never overwritten\r\n"
            "# by upgrades or reinstalls. Add your settings below, e.g.:\r\n"
            "# $env:RTT_EXEC_PATH = 'C:\\gcc-arm\\bin'\r\n"
        )
    else:
        name = 'env.user.sh'
        encoding = 'utf-8'
        template = (
            "# RT-Thread ENV user customization.\n"
            "# Sourced by env.sh on every activation; never overwritten\n"
            "# by upgrades or reinstalls. Add your settings below, e.g.:\n"
            "# export RTT_EXEC_PATH=/opt/gcc-arm/bin\n"
            "# alias pkgs='rt-env pkg'\n"
        )
    dst = os.path.join(config.env_root, name)
    if os.path.exists(dst):
        return
    with open(dst, 'w', encoding=encoding, newline='') as f:
        f.write(template)
    log_success('user_config_created', dst)

# ============================================================================
# Virtual Environment Functions
# ============================================================================


def create_venv(config):
    """
    Create Python virtual environment

    Args:
        config: TouchEnvConfig instance

    Raises:
        RuntimeError: If venv creation fails
    """
    venv_path = config.venv_dir

    if os.path.exists(venv_path):
        log_success('venv_exists')
        return

    log_info('creating_venv', venv_path)

    try:
        import venv
        venv.create(venv_path, with_pip=True)
        log_success('venv_created')
    except (OSError, PermissionError, ValueError) as e:
        log_error('venv_creation_failed', str(e))
        raise RuntimeError(f"Failed to create virtual environment: {e}") from e


def get_python_executable(config):
    """
    Get virtual environment Python executable path

    Args:
        config: TouchEnvConfig instance

    Returns:
        Path to Python executable
    """
    if platform.system() == 'Windows':
        return os.path.join(config.venv_dir, 'Scripts', 'python.exe')
    else:
        return os.path.join(config.venv_dir, 'bin', 'python')

# ============================================================================
# Package Installation Functions
# ============================================================================


def install_packages(config):
    """
    Install Python packages

    Args:
        config: TouchEnvConfig instance

    Raises:
        RuntimeError: If package installation fails
    """
    python_exe = get_python_executable(config)

    if not os.path.exists(python_exe):
        log_error('venv_not_found')
        raise RuntimeError("Virtual environment not found")

    # Upgrade pip
    log_info('upgrading_pip')
    subprocess.run(
        [python_exe, '-m', 'pip', 'install', '--upgrade', 'pip'],
        check=True
    )

    # Build pip install arguments
    pip_args = [python_exe, '-m', 'pip', 'install']

    # Add mirror source
    if config.use_cn:
        log_info('using_cn_mirror')
        log_info('using_pypi_mirror', PYPI_MIRROR_CN)
        pip_args.extend(['--index-url', PYPI_MIRROR_CN])

    # Install rt-env package (editable mode)
    pip_args.extend(['-e', config.scripts_dir])

    # Install pyocd
    pip_args.append('pyocd')

    # Execute installation
    log_info('installing_packages')
    try:
        subprocess.run(pip_args, check=True)
        log_success('installed_packages')
    except subprocess.CalledProcessError as e:
        log_error('package_install_failed', str(e))
        raise RuntimeError(f"Package installation failed: {e}") from e

    # Fix guiconfig.py missing import re issue
    fix_guiconfig_import(config)


def fix_guiconfig_import(config):
    """
    Fix guiconfig.py missing import re issue

    Args:
        config: TouchEnvConfig instance
    """
    # Direct path for Windows and Unix-like systems
    if platform.system() == 'Windows':
        guiconfig_path = os.path.join(
            config.venv_dir, 'Lib', 'site-packages', 'guiconfig.py')
    else:
        guiconfig_path = os.path.join(
            config.venv_dir, 'lib', f'python{sys.version_info.major}.{sys.version_info.minor}', 'site-packages', 'guiconfig.py')

    if not os.path.exists(guiconfig_path):
        return

    try:
        with open(guiconfig_path, 'r', encoding='utf-8') as f:
            content = f.read()

        # Check if import re already exists
        if 'import re' not in content:
            # Insert import re at the appropriate location
            lines = content.split('\n')

            # Find the first non-comment, non-docstring line
            # Skip shebang, encoding, and docstring
            import_index = 0
            in_docstring = False
            docstring_delimiter = None

            for i, line in enumerate(lines):
                stripped = line.strip()

                # Skip empty lines and comments
                if not stripped or stripped.startswith('#'):
                    continue

                # Handle docstring
                if (stripped.startswith('"""') or stripped.startswith("'''")):
                    if in_docstring:
                        if stripped.startswith(docstring_delimiter) and len(stripped) > 3:
                            in_docstring = False
                    else:
                        in_docstring = True
                        docstring_delimiter = stripped[:3]
                    continue

                if in_docstring:
                    continue

                # Found first actual code line
                # Look for the first import or from statement
                if line.startswith('import ') or line.startswith('from '):
                    import_index = i + 1
                else:
                    import_index = i
                break

            # Insert import re at the calculated position
            lines.insert(import_index, 'import re')
            content = '\n'.join(lines)

            with open(guiconfig_path, 'w', encoding='utf-8') as f:
                f.write(content)

            log_success('fixed_guiconfig')
    except (IOError, PermissionError, UnicodeDecodeError, UnicodeEncodeError) as e:
        # Fix failure should not interrupt installation
        log_error('fix_guiconfig_failed', str(e))

# ============================================================================
# Existing Environment Handling
# ============================================================================


def check_existing_env(config):
    """
    Handle an existing ENV installation based on the keep-sdk decision

    Args:
        config: TouchEnvConfig instance

    Raises:
        SystemExit: If user cancels installation
    """
    if not os.path.exists(config.env_root):
        return

    log_raw(get_message('env_root_exists').format(config.env_root))
    print()

    # Decide whether to keep toolchains: argument first, then prompt, auto-mode defaults to keep
    keep = config.keep_sdk
    if keep is None:
        if config.auto_mode:
            keep = True
            log_info('auto_mode_preserving')
        else:
            response = input(get_message('toolchain_keep_prompt')).strip().lower()
            keep = response not in ('n', 'no')
    else:
        keep = (keep == 'yes')

    if keep:
        log_info('toolchain_kept')

        # Preserve local_pkgs/ and tools/scripts/cmds/.config in place
        config_path = os.path.join(config.env_root, 'tools', 'scripts', 'cmds', '.config')
        config_saved = None
        if os.path.isfile(config_path):
            try:
                with open(config_path, 'rb') as f:
                    config_saved = f.read()
            except OSError:
                config_saved = None

        for rel in ('venv', '.venv', 'tools', 'packages'):
            target = os.path.join(config.env_root, rel)
            if os.path.exists(target):
                log_info('deleting_item', rel)
                try:
                    _safe_remove_tree(target)
                except (OSError, PermissionError):
                    pass  # installation rebuilds these paths

        if config_saved is not None:
            try:
                os.makedirs(os.path.dirname(config_path), exist_ok=True)
                with open(config_path, 'wb') as f:
                    f.write(config_saved)
            except OSError:
                pass  # config restore is best-effort
    else:
        log_info('toolchain_removed')
        if os.path.exists(config.env_root):
            log_info('deleting_env_root', config.env_root)
            try:
                _safe_remove_tree(config.env_root)
            except (OSError, PermissionError) as e:
                log_error('deleting_env_root_failed', str(e))
                log_warning('manual_delete_required', config.env_root)
                sys.exit(1)


def _safe_remove(path, name):
    """
    Safely remove a file or directory with error handling

    Args:
        path: Full path to the file or directory
        name: Name of the item (for logging)

    Returns:
        bool: True if removal succeeded, False otherwise
    """
    try:
        if os.path.isfile(path) or os.path.islink(path):
            os.remove(path)
        elif os.path.isdir(path):
            shutil.rmtree(path)
        log_info('item_deleted', name)
        return True
    except (OSError, PermissionError) as e:
        if os.path.isfile(path) or os.path.islink(path):
            log_error('file_delete_failed', name, str(e))
        else:
            log_error('dir_delete_failed', name, str(e))
        return False


def _safe_remove_tree(path):
    """
    Safely remove a directory tree, trying multiple methods

    Args:
        path: Path to directory to remove
    """
    if not os.path.exists(path):
        return

    # Method 1: Try rmtree with ignore_errors first
    shutil.rmtree(path, ignore_errors=True)

    # Method 2: If still exists, retry with onerror handler
    if os.path.exists(path):
        def onerror(func, path, exc_info):
            # Try to change permissions and retry
            try:
                os.chmod(path, 0o700)
                if os.path.isdir(path):
                    shutil.rmtree(path, ignore_errors=True)
                else:
                    os.remove(path)
            except Exception:
                pass  # Ignore if still fails

        shutil.rmtree(path, onerror=onerror)

    # Method 3: If still exists, list and delete individually
    if os.path.exists(path):
        for item in os.listdir(path):
            item_path = os.path.join(path, item)
            try:
                if os.path.isfile(item_path) or os.path.islink(item_path):
                    os.chmod(item_path, 0o700)
                    os.remove(item_path)
                elif os.path.isdir(item_path):
                    _safe_remove_tree(item_path)
            except Exception:
                pass  # Ignore if fails

        # Finally try to remove the directory itself
        try:
            os.rmdir(path)
        except Exception:
            pass  # Ignore if fails


# ============================================================================
# User Interaction Functions
# ============================================================================



def show_next_steps(config):
    """
    Show installation completion and next steps

    Args:
        config: TouchEnvConfig instance
    """
    print()
    print("=" * 60)
    log_success('setup_complete')
    print("=" * 60)
    print()
    log_info('next_steps')
    print()

    # Activate environment
    log_raw('activate_env')
    if platform.system() == 'Windows':
        print(f"   . {config.env_root}\\env.ps1")
    else:
        print(f"   source {config.env_root}/env.sh")
    print()

    # Add to profile
    log_raw('add_to_profile')
    if platform.system() == 'Windows':
        print(f"   echo '. {config.env_root}\\env.ps1' >> $PROFILE")
        print(f"   . $PROFILE")
    else:
        shell = os.path.basename(os.getenv('SHELL', 'bash'))
        profile_file = '~/.zshrc' if 'zsh' in shell else '~/.bashrc'
        print(f"   echo 'source {config.env_root}/env.sh' >> {profile_file}")
        print(f"   source {profile_file}")
    print()

    # Install toolchain
    log_raw('install_toolchain')
    print(f"   {get_message('install_toolchain_cmd')}")
    print()

    # Available commands
    log_raw('after_activation')
    print(f"{get_message('menuconfig')}")
    print(f"{get_message('menuconfig_s')}")
    print(f"{get_message('pkgs')}")
    print(f"{get_message('scons')}")
    print(f"{get_message('sdk')}")
    print(f"{get_message('plugin')}")
    print(f"{get_message('webui')}")
    print()

# ============================================================================
# Argument Parsing
# ============================================================================


def parse_repo_url(url):
    """
    Parse repository URL and extract branch from fragment (#branch)
    
    Args:
        url: Repository URL with optional branch fragment (e.g., https://github.com/user/repo.git#branch1)
    
    Returns:
        dict: {'url': 'https://github.com/user/repo.git', 'branch': 'branch1'}
              or {'url': 'https://github.com/user/repo.git'} if no branch specified
    """
    from urllib.parse import urlparse, urlunparse
    
    parsed = urlparse(url)
    repo_info = {'url': urlunparse(parsed._replace(fragment=''))}
    
    if parsed.fragment:
        repo_info['branch'] = parsed.fragment
    
    return repo_info


def prompt_env_root(default_env_root, language='en'):
    """
    Prompt user to enter env-root directory
    
    Args:
        default_env_root: Default installation directory
        language: Language code ('en' or 'zh')
    
    Returns:
        str: User input env-root directory
    """
    # Set language for messages
    set_language(language)
    
    env_root = ""
    is_valid = False
    
    while not is_valid:
        # Display prompt with default value
        prompt_msg = get_message('env_root_prompt')
        default_msg = get_message('env_root_default').format(default_env_root)
        print(f"{prompt_msg} {default_msg}", end=' ')
        env_root = input().strip()
        
        # Use default if input is empty
        if not env_root:
            env_root = default_env_root
        
        # Expand user home directory
        env_root = os.path.expanduser(env_root)
        
        # Check path format (spaces, non-ASCII characters)
        if ' ' in env_root:
            log_error('python_path_invalid', 'spaces')
            continue
        if any(ord(c) > 127 for c in env_root):
            log_error('python_path_invalid', 'non-ASCII characters')
            continue
        
        # Check if parent directory exists or can be created
        parent_dir = os.path.dirname(env_root)
        if parent_dir and not os.path.exists(parent_dir):
            log_info('python_path_creating_dir', parent_dir)
            try:
                os.makedirs(parent_dir, exist_ok=True)
            except Exception:
                log_error('python_path_no_permission', parent_dir)
                continue
        
        # Check write permission
        if parent_dir:
            test_file = os.path.join(parent_dir, '.__write_test__')
            try:
                with open(test_file, 'w') as f:
                    f.write('test')
                os.remove(test_file)
            except Exception:
                log_error('python_path_no_permission', parent_dir)
                continue
        
        is_valid = True
    
    return env_root


def prompt_env_root_if_needed(config, args):
    """
    Prompt for env-root if needed (interactive mode, not explicitly specified)
    
    Args:
        config: TouchEnvConfig instance
        args: Parsed command line arguments
    """
    if not config.auto_mode:
        # Check if --env-root was explicitly provided
        import sys
        has_explicit_env_root = False
        for i in range(len(sys.argv)):
            if sys.argv[i] == '--env-root' and i + 1 < len(sys.argv):
                has_explicit_env_root = True
                break
            elif sys.argv[i].startswith('--env-root='):
                has_explicit_env_root = True
                break
        
        if not has_explicit_env_root:
            default_env_root = os.path.expanduser(DEFAULT_ENV_ROOT)
            config.env_root = prompt_env_root(default_env_root, config.language)
            # Recompute paths with new env_root
            config._compute_paths()


def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description='RT-Thread ENV Setup Script',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument(
        '--env-root',
        required=False,
        default=os.path.expanduser(DEFAULT_ENV_ROOT),
        help='Installation root directory (default: ~/.rt-env)'
    )
    parser.add_argument(
        '--use-cn',
        action='store_true',
        help='Use China mirror (Gitee, TUNA PyPI)'
    )
    parser.add_argument(
        '--language',
        choices=['en', 'zh'],
        default='en',
        help='Language (en/zh)'
    )
    parser.add_argument(
        '--auto-mode',
        action='store_true',
        help='Auto-install without prompts'
    )
    parser.add_argument(
        '--keep-sdk',
        choices=['yes', 'no'],
        default=None,
        help='Keep downloaded toolchains (local_pkgs) and config when ENV_ROOT exists (default: yes; prompt if omitted)'
    )
    parser.add_argument(
        '--repo-env',
        type=str,
        default='',
        help='Custom env repository URL'
    )
    parser.add_argument(
        '--repo-packages',
        type=str,
        default='',
        help='Custom packages repository URL'
    )
    parser.add_argument(
        '--repo-sdk',
        type=str,
        default='',
        help='Custom sdk repository URL'
    )

    args = parser.parse_args()

    # Build custom_repos dictionary from individual arguments
    args.custom_repos = {}
    if args.repo_env:
        args.custom_repos['env'] = parse_repo_url(args.repo_env)
    if args.repo_packages:
        args.custom_repos['packages'] = parse_repo_url(args.repo_packages)
    if args.repo_sdk:
        args.custom_repos['sdk'] = parse_repo_url(args.repo_sdk)

    return args

# ============================================================================
# Main Execution Function
# ============================================================================


def run_touch_env(args):
    """
    Main execution function

    Args:
        args: Parsed command line arguments

    Returns:
        int: Exit code (0 for success, non-zero for failure)
    """
    config = None

    try:
        # Step 0: Initialize configuration
        config = TouchEnvConfig(args)

        # Step 1: Interactive mode: prompt for env-root if needed
        prompt_env_root_if_needed(config, args)

        # Step 2: Handle existing ENV (--keep-sdk decision)
        check_existing_env(config)

        # Step 3: Setup repositories
        setup_repositories(config)

        # Step 4: Create virtual environment
        create_venv(config)

        # Step 5: Install packages (includes pyocd)
        install_packages(config)

        # Step 6: Show next steps
        show_next_steps(config)

        return 0

    except KeyboardInterrupt:
        print()
        log_info('installation_cancelled')
        return 1
    except Exception as e:
        print()
        log_error('installation_failed', str(e))
        return 1


def main():
    """Main entry point"""
    try:
        args = parse_arguments()
        # Set language before logging
        set_language(args.language)
        log_info('start')
        result = run_touch_env(args)
        sys.exit(result)
    except KeyboardInterrupt:
        print()
        log_info('installation_cancelled')
        sys.exit(1)
    except Exception as e:
        print()
        log_error('installation_failed', str(e))
        sys.exit(1)

# ============================================================================
if __name__ == '__main__':
    main()
