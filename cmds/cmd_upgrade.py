#!/usr/bin/env python
# -*- coding: utf-8 -*-
#
# RT-Thread env tool
# Copyright (c) 2026 dongly
#
# Change Logs:
# Date           Author       Notes
# 2026-09-12     Dongly       first version

"""Upgrade the env toolchain itself (packages index + env repo)."""


def add_parser(sub):
    parser = sub.add_parser('upgrade', help=__doc__, description=__doc__)
    parser.set_defaults(func=cmd)


def cmd(args):
    from cmds.cmd_package.cmd_package_upgrade import package_upgrade

    package_upgrade(force_upgrade=True, upgrade_script=True)
