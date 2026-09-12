# -*- coding:utf-8 -*-
#
# File      : cmd_package.py
# This file is part of RT-Thread RTOS
# COPYRIGHT (C) 2006 - 2020, RT-Thread Development Team
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
# 2020-04-08     SummerGift      Optimize program structure
# 2026-09-12     Dongly      Resolve packages/env repo URLs and statistics endpoint
#                             via env.json (info.get_source / info.get_api_url); logical
#                             repos no longer query the mirror server
# 2026-09-12     Dongly      Refresh rt-env editable install and regenerate the
#                             root activator after env repo upgrades
#

import os
import shutil
import platform
import subprocess
import sys
import uuid
from vars import Import
from info import get_source, get_api_url
from .cmd_package_utils import execute_command, git_pull_repo, find_bool_macro_in_config
from .cmd_package_update import need_using_mirror_download

try:
    import requests
except ImportError:
    print(
        "****************************************\n"
        "* Import requests module error.\n"
        "* Please install requests module first.\n"
        "* pip install step:\n"
        "* $ pip install requests\n"
        "* command install step:\n"
        "* $ sudo apt-get install python-requests\n"
        "****************************************\n"
    )


def upgrade_packages_index(force_upgrade=False):
    """Update the package repository index."""

    pkgs_root = Import('pkgs_root')

    src = get_source('packages', use_mirror=need_using_mirror_download())
    git_repo = src.url

    packages_root = pkgs_root
    pkgs_path = os.path.join(packages_root, 'packages')

    if not os.path.isdir(pkgs_path):
        cmd = 'git clone ' + git_repo + ' ' + pkgs_path + ' --depth=1'
        execute_command(cmd, cwd=packages_root)
        print("upgrade from :%s" % (git_repo.encode("utf-8")))
    else:
        if force_upgrade:
            execute_command('git fetch --all', cwd=pkgs_path)
            execute_command('git reset --hard origin/%s' % src.branch, cwd=pkgs_path)
        print("Begin to upgrade env packages.")
        git_pull_repo(pkgs_path, git_repo)
        print("==============================>  Env packages upgrade done \n")

    for filename in os.listdir(packages_root):
        package_path = os.path.join(packages_root, filename)
        if os.path.isdir(package_path):

            if package_path == pkgs_path:
                continue

            if os.path.isdir(os.path.join(package_path, '.git')):
                print("Begin to upgrade %s." % filename)
                if force_upgrade:
                    execute_command('git fetch --all', cwd=package_path)
                    execute_command('git reset --hard origin/master', cwd=package_path)
                git_pull_repo(package_path)
                print("==============================>  Env %s update done \n" % filename)


def upgrade_env_script(force_upgrade=False):
    """Update env function scripts."""

    env_root = Import('env_root')

    src = get_source('env', use_mirror=need_using_mirror_download())

    env_scripts_root = os.path.join(env_root, 'tools', 'scripts')
    if force_upgrade:
        execute_command('git fetch --all', cwd=env_scripts_root)
        execute_command('git reset --hard origin/%s' % src.branch, cwd=env_scripts_root)
    print("Begin to upgrade env scripts.")
    git_pull_repo(env_scripts_root, src.url)
    print("==============================>  Env scripts upgrade done \n")

    _post_upgrade_refresh(env_root, env_scripts_root)


def _post_upgrade_refresh(env_root, env_scripts_root):
    """Best-effort post-upgrade steps after the env repo changed.

    1. pip install -e so new console scripts and dependency changes take
       effect (the editable .pth only redirects code, not entry points).
    2. Regenerate the root activator to match the upgraded env scripts.
    The user customization file ($ENV_ROOT/env.user.*) is never touched.
    """
    print("Refreshing rt-env installation (pip install -e) ...")
    try:
        subprocess.run(
            [sys.executable, '-m', 'pip', 'install', '-q', '-e', env_scripts_root],
            stdout=subprocess.PIPE, stderr=subprocess.STDOUT, check=True)
        print("==============================>  rt-env package refreshed \n")
    except (OSError, subprocess.SubprocessError) as e:
        output = getattr(e, 'output', b'')
        detail = output.decode(errors='replace') if isinstance(output, bytes) else str(e)
        print("Warning: pip install -e failed:\n{0}".format(detail.strip() or str(e)))
        print("Run manually: \"{0}\" -m pip install -e \"{1}\"".format(sys.executable, env_scripts_root))

    print("Refreshing root activator ...")
    try:
        _write_root_activator(env_root, env_scripts_root)
        print("==============================>  Root activator refreshed \n")
    except (OSError, UnicodeDecodeError) as e:
        print("Warning: could not refresh root activator: {0}".format(e))


def _sh_quote(text):
    """Escape single quotes for a single-quoted shell literal."""
    return text.replace("'", "'\\''")


def _ps_quote(text):
    """Escape single quotes for a single-quoted PowerShell literal."""
    return text.replace("'", "''")


def _write_root_activator(env_root, env_scripts_root):
    """Regenerate $ENV_ROOT/env.sh(ps1) to match the upgraded env scripts.

    Thin delegator (RT_ENV_ROOT signal) when the inner script supports it,
    full copy otherwise. Mirrors tools/touch_env.py copy_env_scripts
    (kept local: tools/ is not importable from the installed package).
    """
    name = 'env.ps1' if platform.system() == 'Windows' else 'env.sh'
    src = os.path.join(env_scripts_root, name)
    dst = os.path.join(env_root, name)
    if not os.path.isfile(src):
        return
    with open(src, encoding='utf-8') as f:
        inner = f.read()
    if 'RT_ENV_ROOT' in inner:
        if name.endswith('.ps1'):
            content = (
                "# Generated by the RT-Thread ENV installer. Do not edit.\r\n"
                "$env:RT_ENV_ROOT = '{0}'\r\n"
                ". '{1}'\r\n".format(_ps_quote(env_root), _ps_quote(src))
            )
            encoding = 'utf-8-sig'
        else:
            content = (
                "# Generated by the RT-Thread ENV installer. Do not edit.\n"
                "RT_ENV_ROOT='{0}'\n"
                ". '{1}'\n".format(_sh_quote(env_root), _sh_quote(src))
            )
            encoding = 'utf-8'
        with open(dst, 'w', encoding=encoding, newline='') as f:
            f.write(content)
    else:
        shutil.copy2(src, dst)


def get_mac_address():
    mac = uuid.UUID(int=uuid.getnode()).hex[-12:]
    return ":".join([mac[e : e + 2] for e in range(0, 11, 2)])


def Information_statistics():
    env_root = Import('env_root')
    # get the .config file from env
    env_kconfig_path = os.path.join(env_root, 'tools', 'scripts', 'cmds')
    env_config_file = os.path.join(env_kconfig_path, '.config')

    if os.path.isfile(env_config_file) and find_bool_macro_in_config(env_config_file, 'SYS_PKGS_USING_STATISTICS'):
        mac_addr = get_mac_address()
        response = requests.get(
            get_api_url('statistics')
            + '?userid='
            + str(mac_addr)
            + '&username='
            + str(mac_addr)
            + '&envversion=1.0&studioversion=2.0&ip=127.0.0.1'
        )
        if response.status_code != 200:
            return
    else:
        return


def package_upgrade(force_upgrade=False, upgrade_script=False):
    """Update the package repository directory and env function scripts."""

    if os.environ.get('RTTS_PLATFROM') != 'STUDIO':  # not used in studio
        Information_statistics()

    upgrade_packages_index(force_upgrade=force_upgrade)

    if upgrade_script:
        upgrade_env_script(force_upgrade=force_upgrade)


# upgrade python modules
def package_upgrade_modules():
    try:
        from subprocess import call

        call('python -m pip install --upgrade pip', shell=True)

        import pip
        from pip._internal.utils.misc import get_installed_distributions

        for dist in get_installed_distributions():
            call('python -m pip install --upgrade ' + dist.project_name, shell=True)
    except:
        print('Fail to upgrade python modules!')
