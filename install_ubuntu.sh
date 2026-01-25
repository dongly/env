#!/usr/bin/env bash
#
# DEPRECATED: 此脚本已废弃，请直接使用 install.sh
#
# 此脚本已废弃，推荐直接使用 install.sh
#
# Ubuntu Quick Install Script (Deprecated)
# Usage:
#   ./install_ubuntu.sh              # Auto-install (GitHub)
#   ./install_ubuntu.sh --cn        # Auto-install (China mirror)
#   ./install_ubuntu.sh --gitee     # Auto-install (Gitee)
#
# Deprecated: Please use install.sh directly
#   curl https://raw.githubusercontent.com/RT-Thread/env/master/install.sh | bash -s -- -y
#   curl https://gitee.com/RT-Thread-Mirror/env/raw/master/install.sh | bash -s -- -y --cn
#

set -e

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Show deprecation notice
echo "============================================================"
echo "   DEPRECATED / 已废弃"
echo "============================================================"
echo ""
echo "This script is deprecated. Please use install.sh directly:"
echo ""
echo "  # Using GitHub:"
echo "  curl https://raw.githubusercontent.com/RT-Thread/env/master/install.sh | bash -s -- -y"
echo ""
echo "  # Using China mirror (Gitee):"
echo "  curl https://gitee.com/RT-Thread-Mirror/env/raw/master/install.sh | bash -s -- -y --cn"
echo ""
echo "============================================================"
echo ""

# Check for --help or no arguments
if [[ "$1" == "--help" ]] || [[ "$1" == "-h" ]] || [[ $# -eq 0 ]]; then
    exit 0
fi

# Parse arguments for mirror selection
USE_CN="false"
USE_GITEE="false"
OTHER_ARGS=""

for arg in "$@"; do
    case "$arg" in
        --cn)
            USE_CN="true"
            ;;
        --gitee)
            USE_GITEE="true"
            USE_CN="true"
            ;;
        *)
            OTHER_ARGS="$OTHER_ARGS $arg"
            ;;
    esac
done

# Determine URL
if [[ "$USE_CN" == "true" ]]; then
    INSTALL_URL="https://gitee.com/RT-Thread-Mirror/env/raw/master/install.sh"
else
    INSTALL_URL="https://raw.githubusercontent.com/RT-Thread/env/master/install.sh"
fi

echo "Downloading install.sh from: $INSTALL_URL"
echo ""

# Download and execute install.sh directly (without writing to disk)
curl -fsSL "$INSTALL_URL" | bash -s -- -y $OTHER_ARGS