# -*- coding:utf-8 -*-
#
# File      : cmd_sdk.py
# This file is part of RT-Thread RTOS
# COPYRIGHT (C) 2024, RT-Thread Development Team
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
# 2024-04-04     bernard         the first version
# 2026-09-13     Dongly          Save the sdk selection to $ENV_ROOT/sdk.config
# 2026-09-13     Dongly          Install sdk payloads under $ENV_ROOT/toolchain

import os
import json
import platform
import shutil
import sys
from vars import Import, Export

'''RT-Thread environment sdk setting'''


def cmd(args):
    import menuconfig
    from cmds.cmd_package import list_packages
    from cmds.cmd_package import get_packages
    from cmds.cmd_package import package_update

    # change to sdk root directory
    env_root = Import('env_root')
    tools_kconfig_path = os.path.join(env_root, 'tools', 'scripts')
    beforepath = os.getcwd()
    os.chdir(tools_kconfig_path)

    # set HOSTOS
    os.environ['HOSTOS'] = platform.system()

    # the sdk selection persists in $ENV_ROOT/sdk.config (read by sdk_manager),
    # not in a .config left in the working directory
    sdk_config = os.path.join(env_root, 'sdk.config')

    # migrate payloads installed by the legacy sdk flow
    # (tools/scripts/packages/<name>-<ver>) to the toolchain root
    legacy_packages = os.path.join(tools_kconfig_path, 'packages')
    toolchain_root = os.path.join(env_root, 'toolchain')
    if os.path.isdir(legacy_packages):
        for name in os.listdir(legacy_packages):
            source = os.path.join(legacy_packages, name)
            if not os.path.isdir(source):
                continue  # pkgs.json / SConscript / dbsqlite are files, stay
            target = os.path.join(toolchain_root, name)
            if not os.path.exists(target):
                os.makedirs(toolchain_root, exist_ok=True)
                shutil.move(source, target)

    # change bsp root to sdk root
    bsp_root = tools_kconfig_path
    before_bsp_root = Import('bsp_root')
    Export('bsp_root')

    try:
        # do menuconfig; kconfiglib resolves the config file from KCONFIG_CONFIG
        before_config_env = os.environ.get('KCONFIG_CONFIG')
        os.environ['KCONFIG_CONFIG'] = sdk_config
        try:
            sys.argv = ['menuconfig', 'Kconfig']
            menuconfig._main()
        finally:
            if before_config_env is None:
                os.environ.pop('KCONFIG_CONFIG', None)
            else:
                os.environ['KCONFIG_CONFIG'] = before_config_env

        # update package
        package_update(config_file=sdk_config)

        # update sdk list information
        packages = get_packages(config_file=sdk_config)
    finally:
        os.chdir(beforepath)

        # restore the old bsp_root
        bsp_root = before_bsp_root
        Export('bsp_root')

    sdk_packages = []
    for item in packages:
        sdk_item = {}
        sdk_item['name'] = item['name']
        sdk_item['path'] = item['name'] + '-' + item['ver']

        sdk_packages.append(sdk_item)

    # write sdk_packages to sdk_list.json
    with open(os.path.join(tools_kconfig_path, 'sdk_list.json'), 'w', encoding='utf-8') as f:
        json.dump(sdk_packages, f, ensure_ascii=False, indent=4)

    # refresh the derived state files (pkgs.json/sdk_list.json/sdk_cfg.json)
    # so the upstream build finds the payloads under toolchain/
    try:
        from sdk_manager import SdkManager

        SdkManager(env_root=env_root).rebuild_state_files()
    except Exception as e:
        print("Warning: could not rebuild the SDK state files: {0}".format(e))


def add_parser(sub):
    parser = sub.add_parser('sdk', help=__doc__, description=__doc__)

    parser.set_defaults(func=cmd)
