#!/usr/bin/env bash
#
# DEPRECATED / 已废弃
#
# 此脚本已废弃，推荐直接使用 install.sh
#
# Ubuntu Quick Install Script (Deprecated)
# Usage:
#   ./install_ubuntu.sh              # Auto-install (auto-detect mirror)
#   ./install_ubuntu.sh --cn        # Auto-install (China mirror)
#   ./install_ubuntu.sh --gitee     # Auto-install (Gitee)
#
# Deprecated: Please use install.sh directly
#   curl https://raw.githubusercontent.com/RT-Thread/env/master/install.sh | bash -s -- -y
#   curl https://gitee.com/RT-Thread-Mirror/env/raw/master/install.sh | bash -s -- -y --cn
#

set -e

# ============================================================================
# Configuration
# ============================================================================

# URL configurations
URL_GITHUB="https://raw.githubusercontent.com/RT-Thread/env/master/install.sh"
URL_GITEE="https://gitee.com/RT-Thread-Mirror/env/raw/master/install.sh"

# IP detection service
IPINFO_URL="https://ipinfo.io/json"

# ============================================================================
# China Detection
# ============================================================================

detect_china() {
    # Check if user is in China (by IP or system locale)
    local use_cn="false"

    # Check IP-based detection (works on all systems)
    if command -v curl &> /dev/null 2>&1; then
        local ip_info
        ip_info=$(curl -s -m 5 --connect-timeout 3 "$IPINFO_URL" 2>&1 || echo "")
        if [[ "$ip_info" == *"\"country\":\"CN\""* ]]; then
            use_cn="true"
        fi
    fi

    # Fallback: check system timezone
    if [[ "$use_cn" == "false" ]]; then
        local timezone
        timezone=$(date +%Z 2>/dev/null || echo "")
        if [[ "$timezone" == *"CST"* ]] || [[ "$timezone" == *"Shanghai"* ]] || \
           [[ "$timezone" == *"Beijing"* ]] || [[ "$timezone" == *"Asia/Shanghai"* ]]; then
            use_cn="true"
        fi
    fi

    # Fallback: check system locale
    if [[ "$use_cn" == "false" ]]; then
        case "${LC_ALL}:${LANG}" in
            *zh*|*CN*)
                use_cn="true"
                ;;
        esac
    fi

    echo "$use_cn"
}

# ============================================================================
# Main
# ============================================================================

# Show deprecation notice
echo "============================================================"
echo "   DEPRECATED / 已废弃"
echo "============================================================"
echo ""
echo "此脚本已废弃，推荐直接使用 install.sh:"
echo ""
echo "  # 使用 GitHub:"
echo "  curl $URL_GITHUB | bash -s -- -y"
echo ""
echo "  # 使用中国镜像:"
echo "  curl $URL_GITEE | bash -s -- -y --cn"
echo ""
echo "============================================================"
echo ""

# Parse arguments
USE_CN=""
USE_CN_SET="false"
OTHER_ARGS=""

for arg in "$@"; do
    case "$arg" in
        --cn|--gitee)
            USE_CN="true"
            USE_CN_SET="true"
            ;;
        --no-mirror)
            USE_CN="false"
            USE_CN_SET="true"
            ;;
        --help|-h)
            exit 0
            ;;
        *)
            OTHER_ARGS="$OTHER_ARGS $arg"
            ;;
    esac
done

# Auto-detect China if not explicitly set
if [[ "$USE_CN_SET" == "false" ]]; then
    USE_CN=$(detect_china)
fi

# Determine URL
if [[ "$USE_CN" == "true" ]]; then
    INSTALL_URL="$URL_GITEE"
else
    INSTALL_URL="$URL_GITHUB"
fi

echo "检测到位置: $([ "$USE_CN" == "true" ] && echo "中国大陆" || echo "其他地区")"
echo "下载地址: $INSTALL_URL"
echo ""

# Download and execute install.sh directly (without writing to disk)
wget -qO- "$INSTALL_URL" | bash -s -- -y $OTHER_ARGS
