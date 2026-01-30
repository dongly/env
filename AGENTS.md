# RT-Thread ENV - Agent 指南

## 项目概述

这是 RT-Thread ENV v2.0 工具的 Python 项目，用于 RT-Thread 嵌入式操作系统的环境配置、包管理和构建系统集成。

**关键变化**（v2.0 vs v1.5.x）：
- Python 版本从 v2 升级到 v3
- 用 Python kconfiglib 替代 kconfig-frontends
- 仅完全支持 RT-Thread > v5.1.0 或 master 分支

## 构建和安装

### 安装依赖
```bash
pip install -e .
```

或手动安装：
```bash
pip install SCons>=4.0.0 requests psutil tqdm kconfiglib pyyaml
pip install windows-curses  # Windows 平台
```

### 构建命令
```bash
# 构建源码分发包
python setup.py sdist

# 构建 wheel 包
python setup.py bdist_wheel
```

### 代码格式化和检查
```bash
# 使用 Black 格式化代码（行长度 128）
black --line-length 128 --skip-string-normalization .

# 检查格式问题（不修改）
black --check --line-length 128 --skip-string-normalization .
```

### 运行工具
```bash
# 查看环境信息
rt-env -v

# 或使用入口点命令
menuconfig  # 配置菜单
pkgs        # 包管理
sdk         # SDK 管理
system      # 系统信息
```

## 代码风格规范

### 文件编码
- **必须**在文件开头包含编码声明：`# -*- coding:utf-8 -*-`

### 版权和文档头
每个 Python 文件应包含标准化的版权头和变更日志：
```python
# -*- coding:utf-8 -*-
#
# File      : filename.py
# This file is part of RT-Thread RTOS
# COPYRIGHT (C) 2006 - 2018, RT-Thread Development Team
#
# [GPL 许可证文本...]
#
# Change Logs:
# Date           Author          Notes
# YYYY-MM-DD     AuthorName      Description
```

### 导入顺序
```python
# 1. 标准库
import os
import sys

# 2. 第三方库
import requests

# 3. 本地模块
from cmds import *
from vars import Export
```

### 命名约定
- **函数/变量**：snake_case，如 `get_packages()`, `env_root`
- **类**：PascalCase，如 `PackageOperation`
- **常量**：UPPER_CASE，如 `ENV_ROOT`

### 错误处理
```python
# 使用 try-except 处理可能的异常
try:
    # 操作
    pass
except Exception as e:
    # 打印友好的错误信息
    print('Error description: %s' % str(e))
    # 或返回空列表/默认值
    return []

# 使用 noinspection 注释抑制 PyCharm 警告（必要时）
# noinspection PyBroadException
```

### 日志记录
```python
import logging

# 初始化日志（已在 env.py 中统一配置）
log_format = "%(module)s %(lineno)d %(levelname)s %(message)s \n"
logging.basicConfig(level=logging.WARNING, format=log_format)

# 使用日志记录
logging.warning('Warning message')
logging.error('Error message')
```

### 字符串处理
```python
# 注意中文字符编码
package_name_in_json = package.get_name().encode("utf-8")

# Windows 平台的代码页处理（必要时）
if platform.system() == "Windows":
    os.system('chcp 65001  > nul')
    # ... UTF-8 操作
    os.system('chcp 437  > nul')
```

### 文档字符串
主要函数应包含 docstring：
```python
def get_packages():
    """Get the packages list in env.

    Read the.config file in the BSP directory,
    and return the version number of the selected package.
    """
    # 实现
```

## 项目结构

```
env/
├── env.py              # 主入口，命令行解析
├── cmds/               # 子命令实现
│   ├── cmd_package/    # 包管理命令（list、update、upgrade、wizard等）
│   ├── cmd_menuconfig.py
│   ├── cmd_sdk.py
│   └── cmd_system.py
├── ebuild/             # 构建配置和编译器支持
│   ├── configs/        # 各种编译器配置（arm_gcc、armclang、msvc等）
│   └── ...
├── tools/              # 辅助工具
├── package.py          # 包操作核心类
├── kconfig.py          # Kconfig 解析
├── vars.py             # 环境变量导入/导出
└── version.py          # 版本信息
```

## 关键环境变量

```python
ENV_ROOT   # ENV 工具根目录
PKGS_ROOT  # 包根目录（默认 ENV_ROOT/packages）
BSP_DIR    # BSP 目录（当前工作目录）
RTT_ROOT   # RT-Thread 内核目录（自动检测）
```

## 重要注意事项

1. **路径要求**：项目路径必须使用纯英文，不支持非 ASCII 字符
2. **版本兼容**：env v2.0 只支持 RT-Thread > v5.1.0
3. **kconfiglib**：需要安装（`pip install kconfiglib`），与 v1.5.x 冲突
4. **Python 版本**：要求 Python >= 3.6

## 测试

项目目前没有配置自动测试框架。如有测试需求，建议：
```bash
# 安装 pytest
pip install pytest

# 运行特定测试文件
pytest tests/test_specific.py

# 运行特定测试用例
pytest tests/test_specific.py::test_function_name

# 运行所有测试
pytest tests/
```

## 包管理常用操作

```bash
# 列出已安装的包
pkgs --list

# 更新包索引
pkgs --update

# 安装特定包
pkgs --install package_name

# 升级包
pkgs --upgrade

# 环境配置
menuconfig
```
