#!/usr/bin/env python3
# -*- coding: utf-8 -*-
#
# RT-Thread ENV Setup Script (Python)
#
# This script handles the setup of RT-Thread ENV after the repository is cloned.
# It performs steps 4-9 of the installation process:
# 1. Setup repositories (clone packages, sdk, env)
# 2. Create Python virtual environment
# 3. Install Python packages
# 4. Restore preserved configuration
# 5. Show next steps
#
# Usage:
#   python touch_env.py --env-root <path> [OPTIONS]
#
# Options:
#   --env-root <path>           Installation root directory (required)
#   --use-cn                     Use China mirror (Gitee, TUNA PyPI)
#   --language <lang>            Language: 'en' or 'zh'
#   --auto-mode                  Auto-install without prompts
#   --install-pyocd              Install pyocd for debugging
#   --restore-config             Restore preserved configuration
#   --repo-env <url>             Custom env repository URL
#   --repo-packages <url>        Custom packages repository URL
#   --repo-sdk <url>             Custom sdk repository URL
#   --branch-env <branch>        Branch for custom env repository
#   --branch-packages <branch>   Branch for custom packages repository
#   --branch-sdk <branch>        Branch for custom sdk repository
#
# Examples:
#   python touch_env.py --env-root /path/to/env --repo-env https://github.com/user/env.git
#   python touch_env.py --env-root /path/to/env --repo-packages https://github.com/user/packages.git --branch-packages my-branch
#

import os
import sys
import argparse
import platform
import shutil
import subprocess
import json
from pathlib import Path

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
# Configuration Constants
# ============================================================================

# GitHub official sources
REPO_PACKAGES_GITHUB = "https://github.com/RT-Thread/packages.git"
REPO_ENV_GITHUB = "https://github.com/RT-Thread/env.git"
REPO_SDK_GITHUB = "https://github.com/RT-Thread/sdk.git"

# Gitee mirrors (China)
REPO_PACKAGES_GITEE = "https://gitee.com/RT-Thread-Mirror/packages.git"
REPO_ENV_GITEE = "https://gitee.com/RT-Thread-Mirror/env.git"
REPO_SDK_GITEE = "https://gitee.com/RT-Thread-Mirror/sdk.git"

# Default branches (empty means use git default)
BRANCH_PACKAGES_DEFAULT = ""
BRANCH_ENV_DEFAULT = ""
BRANCH_SDK_DEFAULT = ""

# PyPI mirror
PYPI_MIRROR_CN = "https://pypi.tuna.tsinghua.edu.cn/simple"

# Internal default values
VENV_DIR_RELATIVE = "venv/rt-env"
SCRIPTS_DIR_RELATIVE = "tools/scripts"
TEMP_CONFIG_FILE = ".config.backup"

# Portable Python directory name
PORTABLE_PYTHON_DIR = "python"

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
        # Set language in runtime config
        set_language(args.language)

        self.env_root = args.env_root
        self.use_cn = args.use_cn
        self.language = args.language
        self.auto_mode = args.auto_mode
        self.install_pyocd = args.install_pyocd
        self.restore_config = args.restore_config
        self.custom_repos = args.custom_repos

        # Compute internal paths
        self._compute_paths()

        # Validate configuration
        self._validate()

    def _compute_paths(self):
        """Compute internal paths based on env_root"""
        self.venv_dir = os.path.join(self.env_root, VENV_DIR_RELATIVE)
        self.scripts_dir = os.path.join(self.env_root, SCRIPTS_DIR_RELATIVE)
        self.temp_config_path = os.path.join(self.env_root, TEMP_CONFIG_FILE)

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
        'restoring_config': 'Restoring config...',
        'config_restored': 'Config restored',
        'pyocd_install_prompt': 'Do you want to install pyocd (for debugging Cortex-M devices)?',
        'pyocd_install_confirm': 'Install pyocd? [Y/n]: ',
        'fixed_guiconfig': 'Fixed guiconfig.py (added missing import)',
        'setup_complete': 'RT-Thread ENV installation completed!',
        'next_steps': 'Next steps:',
        'activate_env': '1. Activate environment:',
        'add_to_profile': '2. Add to profile:',
        'install_toolchain': '3. Install toolchains:',
        'install_toolchain_cmd': '   Run sdk command to install required toolchains',
        'after_activation': '4. After activation, you can use:',
        'menuconfig': '     - menuconfig    : Configure RT-Thread',
        'pkgs': '     - pkgs          : Package manager',
        'scons': '     - scons         : Build RT-Thread',
        'sdk': '     - sdk           : Install toolchains',
        'clone_failed': 'Git clone failed: {0}',
        'invalid_git_repo': 'Invalid git repository: {0}',
        'venv_not_found': 'Virtual environment not found',
        'package_install_failed': 'Package installation failed: {0}',
        'using_custom_repo': 'Using custom repository: {0}',
        'using_custom_repo_branch': 'Using custom repository: {0} (branch: {1})',
        'backup_config': 'Backing up configuration file...',
        'no_config_to_restore': 'No configuration to restore',
        'env_root_exists': 'Existing RT-Thread ENV detected at: {0}',
        'env_root_prompt': 'Existing RT-Thread ENV detected. Do you want to delete and reinstall?',
        'env_root_confirm': 'Are you sure you want to delete? [Y/a/n]: ',
        'env_root_confirm_help': '  Y/y: Preserve config and local_pkgs, delete others (default)',
        'env_root_confirm_all': '  A/a: Delete entire directory (including config and local_pkgs)',
        'env_root_confirm_no': '  N/n: Cancel installation',
        'removing_env_preserving': 'Removing (preserving config and local_pkgs): {0}...',
        'removing_env_all': 'Removing entire directory: {0}...',
        'env_root_removed': 'Existing RT-Thread ENV removed: {0}',
        'installation_cancelled': 'Installation cancelled',
        'installation_failed': 'Installation failed: {0}',
        'removing_portable_python': 'Removing portable Python: {0}...',
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
        'restoring_config': '正在恢复配置...',
        'config_restored': '配置已恢复',
        'pyocd_install_prompt': '是否要安装 pyocd (用于调试 Cortex-M 设备)？',
        'pyocd_install_confirm': '安装 pyocd？[Y/n]: ',
        'fixed_guiconfig': '已修复 guiconfig.py（添加缺失的导入）',
        'setup_complete': 'RT-Thread ENV 安装完成！',
        'next_steps': '后续步骤:',
        'activate_env': '1. 激活环境:',
        'add_to_profile': '2. 添加到配置文件:',
        'install_toolchain': '3. 安装工具链:',
        'install_toolchain_cmd': '   运行 sdk 命令安装所需的工具链',
        'after_activation': '4. 激活后可用命令:',
        'menuconfig': '     - menuconfig    : 配置 RT-Thread',
        'pkgs': '     - pkgs          : 包管理器',
        'scons': '     - scons         : 编译 RT-Thread',
        'sdk': '     - sdk           : 安装工具链',
        'clone_failed': 'Git 克隆失败: {0}',
        'invalid_git_repo': '无效的 git 仓库: {0}',
        'venv_not_found': '找不到虚拟环境',
        'package_install_failed': '包安装失败: {0}',
        'using_custom_repo': '使用自定义仓库: {0}',
        'using_custom_repo_branch': '使用自定义仓库: {0} (分支: {1})',
        'backup_config': '正在备份配置文件...',
        'no_config_to_restore': '没有需要恢复的配置',
        'env_root_exists': '检测到已存在的 RT-Thread ENV: {0}',
        'env_root_prompt': '检测到已存在的RT-Thread ENV。是否要删除并重新安装？',
        'env_root_confirm': '确定要删除吗？[Y/a/n]: ',
        'env_root_confirm_help': '  Y/y: 保留配置和本地包，删除其他（默认）',
        'env_root_confirm_all': '  A/a: 删除整个目录（包括配置和本地包）',
        'env_root_confirm_no': '  N/n: 取消安装',
        'removing_env_preserving': '正在删除（保留配置和本地包）: {0}...',
        'removing_env_all': '正在删除整个目录: {0}...',
        'env_root_removed': '已删除 RT-Thread ENV: {0}',
        'installation_cancelled': '安装已取消',
        'installation_failed': '安装失败: {0}',
        'removing_portable_python': '正在删除便携式 Python: {0}...',
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


def log_raw(text):
    """Log raw text to stderr"""
    print(text, file=sys.stderr)

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
        subprocess.run(clone_args, check=True, capture_output=True, text=True)
        log_success('cloned', dest_path)
    except subprocess.CalledProcessError as e:
        # Clone failed, clean up partial clone
        log_error('clone_failed', e.stderr)
        shutil.rmtree(dest_path, ignore_errors=True)
        raise RuntimeError(f"Failed to clone {url}") from e


def setup_repositories(config):
    """
    Setup all repositories (packages, sdk, env)

    Args:
        config: TouchEnvConfig instance

    Raises:
        RuntimeError: If any repository setup fails
    """
    # Base repositories
    github_repos = {
        'packages': REPO_PACKAGES_GITHUB,
        'env': REPO_ENV_GITHUB,
        'sdk': REPO_SDK_GITHUB
    }

    gitee_repos = {
        'packages': REPO_PACKAGES_GITEE,
        'env': REPO_ENV_GITEE,
        'sdk': REPO_SDK_GITEE
    }

    # Select mirror
    repos_base = gitee_repos if config.use_cn else github_repos

    # Repository destinations
    repo_dests = {
        'packages': 'packages/packages',
        'env': 'tools/scripts',
        'sdk': 'packages/sdk'
    }

    # Clone all repositories
    for repo_name in ['packages', 'env', 'sdk']:
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
            url = repos_base[repo_name]
            branch = ''

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


def copy_env_scripts(config):
    """Copy env scripts to root directory"""
    scripts_dir = os.path.join(config.env_root, 'tools/scripts')

    # Copy appropriate script based on platform
    if platform.system() == 'Windows':
        src = os.path.join(scripts_dir, 'env.ps1')
        dst = os.path.join(config.env_root, 'env.ps1')
    else:
        src = os.path.join(scripts_dir, 'env.sh')
        dst = os.path.join(config.env_root, 'env.sh')

    if os.path.exists(src):
        shutil.copy2(src, dst)
        log_success('copied_env_script', dst)

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
        check=True,
        capture_output=True,
        text=True
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

    # Optionally install pyocd
    if config.install_pyocd:
        pip_args.append('pyocd')

    # Execute installation
    log_info('installing_packages')
    try:
        subprocess.run(pip_args, check=True, capture_output=True, text=True)
        log_success('installed_packages')
    except subprocess.CalledProcessError as e:
        log_error('package_install_failed', e.stderr)
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
# Configuration Backup/Restore Functions
# ============================================================================


def backup_config_file(config):
    """
    Backup configuration file

    Args:
        config: TouchEnvConfig instance
    """
    config_path = os.path.join(
        config.env_root, 'tools', 'scripts', 'cmds', '.config')

    if os.path.exists(config_path):
        log_info('backup_config')
        shutil.copy2(config_path, config.temp_config_path)


def restore_config(config):
    """
    Restore configuration file

    Args:
        config: TouchEnvConfig instance
    """
    if config.restore_config and os.path.exists(config.temp_config_path):
        config_path = os.path.join(
            config.env_root, 'tools', 'scripts', 'cmds', '.config')

        log_info('restoring_config')
        shutil.copy2(config.temp_config_path, config_path)
        os.remove(config.temp_config_path)
        log_success('config_restored')
    else:
        log_info('no_config_to_restore')

# ============================================================================
# Check Existing ENV Functions
# ============================================================================


def check_existing_env(config):
    """
    Check if existing ENV exists and handle deletion

    Args:
        config: TouchEnvConfig instance

    Raises:
        SystemExit: If user cancels installation
    """
    if not os.path.exists(config.env_root):
        return

    log_raw(get_message('env_root_exists').format(config.env_root))
    print()

    if config.auto_mode:
        # Auto mode: preserve config and delete others
        remove_env_directory(config, preserve=True)
    else:
        # Interactive mode: ask user
        response = show_deletion_options(config)

        if response.lower() == 'y':
            # Preserve config and local_pkgs
            remove_env_directory(config, preserve=True)
        elif response.lower() == 'a':
            # Delete everything
            remove_env_directory(config, preserve=False)
        else:
            # Cancel installation
            log_info('installation_cancelled')
            sys.exit(0)


def show_deletion_options(config):
    """
    Show deletion options to user

    Args:
        config: TouchEnvConfig instance

    Returns:
        str: User response
    """
    print(get_message('env_root_prompt'))
    print(get_message('env_root_confirm'), end='', flush=True)
    print()
    print(get_message('env_root_confirm_help'))
    print(get_message('env_root_confirm_all'))
    print(get_message('env_root_confirm_no'))
    print('> ', end='', flush=True)

    response = input()

    if not response:
        return 'y'  # Default is y (preserve)
    return response


def remove_env_directory(config, preserve=True):
    """
    Remove ENV directory with optional preservation

    Args:
        config: TouchEnvConfig instance
        preserve: If True, preserve config, local_pkgs, and portable python
    """
    # Set restore_config flag
    config.restore_config = False

    # Paths to preserve
    local_pkgs_path = os.path.join(config.env_root, 'local_pkgs')
    portable_python_path = os.path.join(config.env_root, PORTABLE_PYTHON_DIR)
    config_backup_path = config.temp_config_path

    # Always backup config file before deletion
    config_path = os.path.join(
        config.env_root, 'tools', 'scripts', 'cmds', '.config')
    if os.path.exists(config_path):
        shutil.copy2(config_path, config_backup_path)
        config.restore_config = True

    # Delete all items
    if preserve:
        log_info('removing_env_preserving', config.env_root)
    else:
        log_info('removing_env_all', config.env_root)

    try:
        for item in os.listdir(config.env_root):
            item_path = os.path.join(config.env_root, item)

            # Skip local_pkgs if preserving
            if preserve and item == 'local_pkgs':
                continue

            # Skip portable python if preserving
            if preserve and (item == PORTABLE_PYTHON_DIR or item_path == portable_python_path):
                continue

            # Skip .config.backup if preserving
            if preserve and (item == '.config.backup' or item_path == config_backup_path):
                continue

            # Delete item
            if os.path.isfile(item_path):
                try:
                    os.remove(item_path)
                except OSError as e:
                    log_error('file_delete_failed', item_path, str(e))
            else:
                try:
                    shutil.rmtree(item_path)
                except OSError as e:
                    log_error('dir_delete_failed', item_path, str(e))
                    # If deletion fails, try to delete recursively
                    try:
                        for root, dirs, files in os.walk(item_path, topdown=False):
                            for file in files:
                                file_path = os.path.join(root, file)
                                try:
                                    os.remove(file_path)
                                except OSError:
                                    pass
                            for dir in dirs:
                                dir_path = os.path.join(root, dir)
                                try:
                                    os.rmdir(dir_path)
                                except OSError:
                                    pass
                        try:
                            os.rmdir(item_path)
                        except OSError:
                            pass
                    except OSError:
                        pass

        log_success('env_root_removed', config.env_root)
    except (OSError, PermissionError) as e:
        log_error('removing_failed', str(e))

# ============================================================================
# User Interaction Functions
# ============================================================================


def prompt_pyocd(config):
    """
    Prompt user for pyocd installation

    Args:
        config: TouchEnvConfig instance

    Returns:
        bool: Whether to install pyocd
    """
    # Skip in auto mode
    if config.auto_mode:
        return False

    # Only prompt on Windows and macOS
    if platform.system() not in ['Windows', 'Darwin']:
        return False

    print()
    print(get_message('pyocd_install_prompt'))
    response = input(get_message('pyocd_install_confirm'))

    return response.lower() != 'n'


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
    print(get_message('activate_env'))
    if platform.system() == 'Windows':
        print(f"   . {config.env_root}\\env.ps1")
    else:
        print(f"   source {config.env_root}/env.sh")
    print()

    # Add to profile
    print(get_message('add_to_profile'))
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
    print(get_message('install_toolchain'))
    print(f"   {get_message('install_toolchain_cmd')}")
    print()

    # Available commands
    print(get_message('after_activation'))
    print(f"   - menuconfig    : {get_message('menuconfig')}")
    print(f"   - pkgs          : {get_message('pkgs')}")
    print(f"   - scons         : {get_message('scons')}")
    print(f"   - sdk           : {get_message('sdk')}")
    print()

# ============================================================================
# Argument Parsing
# ============================================================================


def parse_arguments():
    """Parse command line arguments"""
    parser = argparse.ArgumentParser(
        description='RT-Thread ENV Setup Script',
        formatter_class=argparse.RawDescriptionHelpFormatter
    )

    parser.add_argument(
        '--env-root',
        required=True,
        help='Installation root directory'
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
        '--install-pyocd',
        action='store_true',
        help='Install pyocd for debugging'
    )
    parser.add_argument(
        '--restore-config',
        action='store_true',
        help='Restore preserved configuration'
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
    parser.add_argument(
        '--branch-env',
        type=str,
        default='',
        help='Branch for custom env repository'
    )
    parser.add_argument(
        '--branch-packages',
        type=str,
        default='',
        help='Branch for custom packages repository'
    )
    parser.add_argument(
        '--branch-sdk',
        type=str,
        default='',
        help='Branch for custom sdk repository'
    )

    args = parser.parse_args()

    # Build custom_repos dictionary from individual arguments
    args.custom_repos = {}
    if args.repo_env:
        args.custom_repos['env'] = {'url': args.repo_env}
        if args.branch_env:
            args.custom_repos['env']['branch'] = args.branch_env
    if args.repo_packages:
        args.custom_repos['packages'] = {'url': args.repo_packages}
        if args.branch_packages:
            args.custom_repos['packages']['branch'] = args.branch_packages
    if args.repo_sdk:
        args.custom_repos['sdk'] = {'url': args.repo_sdk}
        if args.branch_sdk:
            args.custom_repos['sdk']['branch'] = args.branch_sdk

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
    try:
        # Initialize configuration
        config = TouchEnvConfig(args)

        # Step 1: Check existing ENV and handle deletion
        check_existing_env(config)

        # Step 2: Backup configuration file
        backup_config_file(config)

        # Step 3: Setup repositories
        setup_repositories(config)

        # Step 4: Create virtual environment
        create_venv(config)

        # Step 5: Prompt for pyocd installation
        if not config.install_pyocd:
            config.install_pyocd = prompt_pyocd(config)

        # Step 6: Install packages
        install_packages(config)

        # Step 7: Restore configuration
        restore_config(config)

        # Step 8: Show next steps
        show_next_steps(config)

        return 0

    except Exception as e:
        log_error('installation_failed', str(e))
        return 1


def main():
    """Main entry point"""
    log_info('touch_env.py start ...')
    args = parse_arguments()
    sys.exit(run_touch_env(args))


if __name__ == '__main__':
    main()
