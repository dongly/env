#!/usr/bin/env bash
#
# DEPRECATED / 已废弃
#
# 此脚本已废弃，推荐直接使用 tools/install.sh
#
# Ubuntu Quick Install Script (Deprecated)
# Usage:
#   ./install_ubuntu.sh              # Auto-install (auto-detect mirror)
#   ./install_ubuntu.sh --cn        # Auto-install (China mirror)
#   ./install_ubuntu.sh --gitee     # Auto-install (Gitee)
#
# Deprecated: Please use tools/install.sh directly
#   bash -c "$(wget https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.sh -O -)"
#   bash -c "$(wget https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/install.sh -O -)" -- --cn
#
# This script maintains backward compatibility with old versions while
# delegating to the new unified install.sh script
#

set -e

# ============================================================================
# Configuration
# ============================================================================

# URL configurations
URL_GITHUB="https://raw.githubusercontent.com/RT-Thread/env/master/tools/install.sh"
URL_GITEE="https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/install.sh"

# IP detection service
IPINFO_URL="https://ipinfo.io/json"

# Environment directory (compatible with old versions - use .env by default)
ENV_DEFAULT_DIR=".env"
: "${ENV_ROOT:=$HOME/$ENV_DEFAULT_DIR}"

# Function to detect if user is in China
detect_china() {
    # Check if user is in China (by IP or system locale)
    # Return "true" if in China, "false" otherwise
    if [ "$USE_CN_SET" = "true" ]; then
        echo "$USE_CN"  # Return the explicitly set value
        return
    fi

    # Check IP-based detection (works on all systems)
    if command -v curl &> /dev/null 2>&1; then
        local ip_info=$(curl -s -m 5 --connect-timeout 3 "$IPINFO_URL" 2>&1)
        if [[ "$ip_info" == *"\"country\":\"CN\""* ]]; then
            echo "true"
            return
        fi
    fi

    # Fallback: check system timezone
    local timezone=$(date +%Z 2>/dev/null || timedatectl show -p Timezone --value 2>/dev/null || echo "")
    if [[ "$timezone" == *"CST"* ]] || [[ "$timezone" == *"Shanghai"* ]] || [[ "$timezone" == *"Beijing"* ]] || [[ "$timezone" == *"Asia/Shanghai"* ]]; then
        echo "true"
        return
    fi

    # Fallback: check system locale
    case "${LC_ALL}:${LANG}" in
        *zh*|*CN*)
            echo "true"
            ;;
        *)
            echo "false"
            ;;
    esac
}

# ============================================================================
# Activate Virtual Environment (for backward compatibility)
# ============================================================================

activate_venv() {
    # Activate the virtual environment if it exists
    local venv_path="$ENV_ROOT/venv/rt-env/bin/activate"
    if [ -f "$venv_path" ]; then
        source "$venv_path"
        echo "✓ Virtual environment activated"
    else
        echo "⚠ Virtual environment not found at $venv_path"
    fi
}

# ============================================================================
# Main
# ============================================================================

# Show deprecation notice
echo "============================================================"
echo "   DEPRECATED / 已废弃"
echo "============================================================"
echo ""
echo "此脚本已废弃，推荐直接使用 tools/install.sh"
echo "This script is deprecated, please use tools/install.sh directly"
echo ""
echo "使用 GitHub / Using GitHub:"
echo "  bash -c \"\$(wget $URL_GITHUB -O -)\""
echo ""
echo "使用中国镜像 / Using China Mirror:"
echo "  bash -c \"\$(wget $URL_GITEE -O -)\" -- --cn"
echo ""
echo "============================================================"
echo ""

# Parse arguments
USE_CN=""
USE_CN_SET="false"
OTHER_ARGS=""
INSTALL_URL=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--cn|--gitee)
            USE_CN="true"
            USE_CN_SET="true"
            ;;
        -o|--official)
            USE_CN="false"
            USE_CN_SET="true"
            ;;
        -i|--install)
            INSTALL_URL="$2"
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --cn, --gitee       Use China mirror (Gitee)"
            echo "  -o, --official      Force use official GitHub source"
            echo "  -i, --install url  Specify custom install.sh URL"
            echo "  --help, -h          Show this help"
            echo ""
            echo "This script downloads and executes the new install.sh with"
            echo "backward compatibility settings for old .env path."
            exit 0
            ;;
        *)
            OTHER_ARGS="$OTHER_ARGS $1"
            ;;
    esac
    shift
done

# Auto-detect China if not explicitly set
if [[ "$USE_CN_SET" == "false" ]]; then
    USE_CN=$(detect_china)
fi

# Determine URL
if [[ "$INSTALL_URL" == "" ]]; then
    if [[ "$USE_CN" == "true" ]]; then
        INSTALL_URL="$URL_GITEE"
    else
        INSTALL_URL="$URL_GITHUB"
    fi
fi

echo "检测到位置: $([ "$USE_CN" == "true" ] && echo "中国大陆" || echo "其他地区")"
echo "下载地址: $INSTALL_URL"
echo ""

# Download and execute install.sh directly (without writing to disk)
bash -c "$(wget $INSTALL_URL -qO -)" -- -y --env-root "$ENV_ROOT" $OTHER_ARGS

# Activate virtual environment after installation
if [ -d "$ENV_ROOT" ]; then
    echo ""
    echo "============================================================"
    echo "激活虚拟环境 / Activating Virtual Environment"
    echo "============================================================"
    echo ""
    activate_venv
    echo ""
    echo "To activate the environment manually, run:"
    echo "  source $ENV_ROOT/env.sh"
    echo ""
fi
