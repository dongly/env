#!/usr/bin/env bash
# Ubuntu 快速安装脚本
# 用法:
#   ./install_ubuntu.sh              # 自动安装（使用 GitHub 或 Gitee）
#   ./install_ubuntu.sh --cn        # 自动安装（使用中国镜像）
#   ./install_ubuntu.sh --gitee     # 自动安装（使用 Gitee）
#   ./install_ubuntu.sh --en        # 自动安装（英文界面）

# 获取脚本所在目录
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 检查是否传递了 -y 参数，如果没有则添加
if [[ ! " $@ " =~ " -y " ]]; then
    exec "$SCRIPT_DIR/install.sh" -y "$@"
else
    exec "$SCRIPT_DIR/install.sh" "$@"
fi
