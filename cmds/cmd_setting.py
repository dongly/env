#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# RT-Thread env tool
# Copyright (c) 2026 dongly
#
# Change Logs:
# Date           Author       Notes
# 2026-09-12     Dongly       first version

"""Open the env settings menuconfig (same as menuconfig -s)."""

import os
import sys


def run_env_settings(env_root):
    """Run the env-settings menuconfig; saves to $ENV_ROOT/rt-env.config."""
    env_kconfig_path = os.path.join(env_root, 'tools', 'scripts', 'cmds')
    beforepath = os.getcwd()
    os.chdir(env_kconfig_path)
    old_config_env = os.environ.get('KCONFIG_CONFIG')
    os.environ['KCONFIG_CONFIG'] = os.path.join(env_root, 'rt-env.config')
    try:
        import menuconfig

        sys.argv = ['menuconfig', 'Kconfig']
        menuconfig._main()
    finally:
        if old_config_env is None:
            os.environ.pop('KCONFIG_CONFIG', None)
        else:
            os.environ['KCONFIG_CONFIG'] = old_config_env
        os.chdir(beforepath)


def add_parser(sub):
    parser = sub.add_parser('setting', help=__doc__, description=__doc__)
    parser.set_defaults(func=cmd)


def cmd(args):
    from vars import Import

    run_env_settings(Import('env_root'))
