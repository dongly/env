#!/usr/bin/env bash
#
# RT-Thread ENV Installation Script (Unix)
# Unified installation script for Linux and macOS
# Supports: English / 中文
#
# Usage:
#   ./install.sh [-y] [-c] [-o] [-d] [-r <path>] [-e|-z] [-P <repo>[#<branch>]] [-E <repo>[#<branch>]] [-S <repo>[#<branch>]] [-b <strategy>] [-t <url>] [-h]
#
# Options:
#   -y, --yes, --auto    Auto-install without prompts
#   -c, --cn, --gitee    Use China mirror (Gitee, PyPI TUNA)
#   -o, --official       Force use official source
#   -d, --pyocd          Install pyocd for debugging
#   -r, --env-root <path> Set custom install directory
#   -e, --en, --english  Force English messages
#   -z, --zh, --chinese  Force Chinese messages
#   -P, --packages <repo>[#<branch>]  Specify custom packages repository and branch
#   -E, --env <repo>[#<branch>]  Specify custom env repository and branch
#   -S, --sdk <repo>[#<branch>]  Specify custom sdk repository and branch
#   -b, --backup <strategy> Backup strategy (preserve/delete_all/backup_all)
#   -t, --touch-env-url <url> Specify touch_env.py download URL
#   -h, --help           Show this help message
#

# ============================================================================
# Configuration
# ============================================================================

# Verify script is running in bash or zsh
if [ -z "$BASH_VERSION" ] && [ -z "$ZSH_VERSION" ]; then
    echo "Error: This script must be run with bash or zsh, not sh" >&2
    exit 1
fi

# Global configuration variables (like $script:Config in PowerShell)
CONFIG_AUTO_MODE=false
CONFIG_HELP_MODE=false
CONFIG_CN_MODE=false
CONFIG_OFFICIAL_MODE=false
CONFIG_PYOCD_MODE=false
CONFIG_ENV_ROOT=""
CONFIG_EN_MODE=false
CONFIG_ZH_MODE=false
CONFIG_LANG="en"
CONFIG_USE_CN_SET=false
CONFIG_USE_CN=false
CONFIG_CUSTOM_PACKAGES_REPO=""
CONFIG_CUSTOM_PACKAGES_BRANCH=""
CONFIG_CUSTOM_ENV_REPO=""
CONFIG_CUSTOM_ENV_BRANCH=""
CONFIG_CUSTOM_SDK_REPO=""
CONFIG_CUSTOM_SDK_BRANCH=""
CONFIG_BACKUP_STRATEGY=""
CONFIG_TOUCH_ENV_URL_VALUE=""
CONFIG_TEMP_FILES=()
PYTHON_CMD=""

# Get real user's home directory (handles sudo case)
if [ -n "$SUDO_USER" ]; then
    # Running with sudo, use the original user's home
    REAL_USER_HOME=$(getent passwd "$SUDO_USER" | cut -d: -f6)
    REAL_USER="$SUDO_USER"
    # Get the real user's default shell from /etc/passwd
    REAL_USER_SHELL=$(getent passwd "$SUDO_USER" | cut -d: -f7)
else
    # Running without sudo
    REAL_USER_HOME="$HOME"
    REAL_USER="$USER"
    REAL_USER_SHELL="$SHELL"
fi

# Environment directory (can be overridden by --env-root or $ENV_ROOT)
ENV_DEFAULT_DIR=".rtenv"
: "${ENV_ROOT:=$REAL_USER_HOME/$ENV_DEFAULT_DIR}"

# Validate ENV_ROOT (no spaces or special characters)
if [[ "$ENV_ROOT" == *" "* ]] || [[ "$ENV_ROOT" == *$'\t'* ]]; then
    echo "Error: ENV_ROOT cannot contain spaces or tabs" >&2
    exit 1
fi

# Validate ENV_ROOT (no non-ASCII characters)
if LC_ALL=C.UTF-8 locale -ck "$ENV_ROOT" 2>&1 | grep -q "non-ASCII"; then
    echo "Error: ENV_ROOT cannot contain non-ASCII characters" >&2
    exit 1
fi

# Repository configurations
# GitHub (default)
REPO_PACKAGES_GITHUB="https://github.com/RT-Thread/packages.git"
REPO_ENV_GITHUB="https://github.com/RT-Thread/env.git"
REPO_SDK_GITHUB="https://github.com/RT-Thread/sdk.git"

# Gitee (China mirror)
REPO_PACKAGES_GITEE="https://gitee.com/RT-Thread-Mirror/packages.git"
REPO_ENV_GITEE="https://gitee.com/RT-Thread-Mirror/env.git"
REPO_SDK_GITEE="https://gitee.com/RT-Thread-Mirror/sdk.git"

# PyPI mirror configurations
PYPI_MIRROR_CN="https://pypi.tuna.tsinghua.edu.cn/simple"

# IP detection service
IPINFO_URL="https://ipinfo.io/json"

# Homebrew installation script
HOMEBREW_INSTALL_URL="https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh"

# touch_env.py download URLs
TOUCH_ENV_URL_GITHUB="https://raw.githubusercontent.com/RT-Thread/env/master/tools/touch_env.py"
TOUCH_ENV_URL_GITEE="https://gitee.com/RT-Thread-Mirror/env/raw/master/tools/touch_env.py"

# ============================================================================
# Message Dictionary (Centralized i18n messages like PowerShell $script:Messages)
# ============================================================================

declare -A MESSAGES_EN=(
    ["banner_title"]="RT-Thread ENV Installation"
    ["info"]="INFO"
    ["success"]="SUCCESS"
    ["warning"]="WARNING"
    ["error"]="ERROR"
    ["git_not_found"]="Git is not installed. Please install Git first."
    ["please_install_git"]="Please install Git first"
    ["install_git_macos"]="macOS: brew install git"
    ["install_git_linux"]="Linux: sudo apt-get install git (Ubuntu/Debian) or sudo dnf install git (Fedora/RHEL)"
    ["cloning"]="Cloning %s to %s"
    ["cloned"]="Cloned %s"
    ["dir_exists"]="Directory already exists: %s"
    ["generating_kconfig"]="Generating Kconfig: %s"
    ["installing_ubuntu"]="Installing dependencies (Ubuntu/Debian)..."
    ["installing_suse"]="Installing dependencies (SUSE/openSUSE)..."
    ["installing_arch"]="Installing dependencies (Arch/Manjaro)..."
    ["installing_fedora"]="Installing dependencies (Fedora/RHEL/CentOS)..."
    ["installing_alpine"]="Installing dependencies (Alpine)..."
    ["unsupported_os"]="Unsupported OS: %s"
    ["missing_gcc"]="Missing GCC compiler, please install manually"
    ["installing_macos"]="Installing dependencies (macOS)..."
    ["installing_packages"]="Installing Python packages..."
    ["env_root_exists"]="RT-Thread ENV directory already exists: %s"
    ["env_root_prompt"]="Existing RT-Thread ENV detected. Do you want to delete and reinstall?"
    ["env_root_confirm"]="Are you sure you want to delete? [Y/a/n]: "
    ["env_root_confirm_help"]="  Y/y: Preserve config and toolchain, delete others (default)"
    ["env_root_confirm_all"]="  A/a: Delete entire directory (including config and toolchain)"
    ["env_root_confirm_no"]="  N/n: Cancel installation"
    ["removing_env_root"]="Removing existing RT-Thread ENV: %s..."
    ["removing_env_root_preserving"]="Removing (preserving config and toolchain): %s..."
    ["removing_env_root_all"]="Removing entire directory: %s..."
    ["env_root_removed"]="Existing RT-Thread ENV removed: %s"
    ["installation_cancelled"]="Installation cancelled"
    ["installation_skip_existing"]="RT-Thread ENV already exists, skipping installation (use -y to force reinstall)"
    ["upgrading_pip"]="Upgrading pip..."
    ["package_install_failed"]="Package installation failed, please check network connection or permissions"
    ["installing_pyocd"]="Installing pyocd..."
    ["pyocd_install_prompt"]="Do you want to install pyocd (for debugging Cortex-M devices)?"
    ["pyocd_install_confirm"]="Install pyocd? [y/N] "
    ["next_steps"]="Next steps:"
    ["activate_env"]="1. Activate RT-Thread ENV:"
    ["activate_cmd"]="   source %s/env.sh"
    ["add_to_profile"]="2. Add to profile:"
    ["add_bashrc"]="   echo 'source %s/env.sh' >> ~/.bashrc"
    ["add_zshrc"]="   echo 'source %s/env.sh' >> ~/.zshrc"
    ["source_bashrc"]="   source ~/.bashrc"
    ["source_zshrc"]="   source ~/.zshrc"
    ["install_toolchain"]="3. Install toolchains:"
    ["install_toolchain_cmd"]="   Run 'sdk' command to install required toolchains"
    ["after_activation"]="4. After activation, you can use:"
    ["menuconfig"]="     - menuconfig    : Configure RT-Thread"
    ["pkgs"]="     - pkgs          : Package manager"
    ["scons"]="     - scons         : Build RT-Thread"
    ["sdk"]="     - sdk           : Install toolchains"
    ["fixing_ownership"]="Fixing file ownership..."
    ["ownership_fixed"]="File ownership fixed"
    ["using_custom_repo"]="Using custom repository: %s"
    ["using_custom_branch"]="Using branch: %s"
    ["using_custom_repo_branch"]="Using custom repository: %s (branch: %s)"
    ["missing_python"]="Python 3 not found. Please install Python first."
    ["python_version_check"]="Checking Python version..."
    ["python_version"]="Python version: %s"
    ["python_version_failed"]="Failed to get Python version information"
    ["using_cn_mirror"]="Using China mirror"
    ["using_official_source"]="Using official source"
    ["using_pypi_mirror"]="Using PyPI mirror: %s"
    ["installed_packages"]="Python packages installed"
    ["copied_env_script"]="Copied env.sh: %s"
    ["setup_complete"]="RT-Thread ENV installation complete!"
    ["downloading_touch_env"]="Downloading touch_env.py from: %s"
    ["touch_env_downloaded"]="touch_env.py downloaded successfully."
    ["touch_env_failed"]="touch_env.py execution failed with exit code: %s"
    ["touch_env_download_failed"]="Failed to download touch_env.py: %s"
    ["check_list"]="Please check:"
    ["check_list_connection"]="  1. Your internet connection"
    ["check_list_url"]="  2. The URL is correct: %s"
    ["check_list_alt_url"]="  3. Try using -t parameter to specify a different URL"
)

declare -A MESSAGES_ZH=(
    ["banner_title"]="RT-Thread ENV 安装程序"
    ["info"]="信息"
    ["success"]="成功"
    ["warning"]="警告"
    ["error"]="错误"
    ["git_not_found"]="未安装 Git。请先安装 Git。"
    ["please_install_git"]="请先安装 Git"
    ["install_git_macos"]="macOS: brew install git"
    ["install_git_linux"]="Linux: sudo apt-get install git (Ubuntu/Debian) 或 sudo dnf install git (Fedora/RHEL)"
    ["cloning"]="正在克隆: %s 到 %s"
    ["cloned"]="已克隆: %s"
    ["dir_exists"]="目录已存在: %s"
    ["generating_kconfig"]="生成 Kconfig: %s"
    ["installing_ubuntu"]="正在安装依赖 (Ubuntu/Debian)..."
    ["installing_suse"]="正在安装依赖 (SUSE/openSUSE)..."
    ["installing_arch"]="正在安装依赖 (Arch/Manjaro)..."
    ["installing_fedora"]="正在安装依赖 (Fedora/RHEL/CentOS)..."
    ["installing_alpine"]="正在安装依赖 (Alpine)..."
    ["unsupported_os"]="不支持的操作系统: %s"
    ["missing_gcc"]="缺少 GCC 编译器，请手动安装"
    ["installing_macos"]="正在安装依赖 (macOS)..."
    ["installing_packages"]="正在安装 Python 包..."
    ["env_root_exists"]="RT-Thread ENV 目录已存在: %s"
    ["env_root_prompt"]="检测到已存在的RT-Thread ENV。是否要删除并重新安装？"
    ["env_root_confirm"]="确定要删除吗？[Y/a/n]: "
    ["env_root_confirm_help"]="  Y/y: 保留配置和工具链，删除其他（默认）"
    ["env_root_confirm_all"]="  A/a: 删除整个目录（包括配置和工具链）"
    ["env_root_confirm_no"]="  N/n: 取消安装"
    ["removing_env_root"]="正在删除现有RT-Thread ENV: %s..."
    ["removing_env_root_preserving"]="正在删除（保留配置和工具链）: %s..."
    ["removing_env_root_all"]="正在删除整个目录: %s..."
    ["env_root_removed"]="已删除 RT-Thread ENV: %s"
    ["installation_cancelled"]="安装已取消"
    ["installation_skip_existing"]="RT-Thread ENV 已存在，跳过安装（使用 -y 参数强制重新安装）"
    ["venv_not_found"]="找不到虚拟环境，请重新创建"
    ["upgrading_pip"]="正在升级 pip..."
    ["package_install_failed"]="包安装失败，请检查网络连接或权限"
    ["installing_pyocd"]="正在安装 pyocd..."
    ["pyocd_install_prompt"]="是否要安装 pyocd (用于调试 Cortex-M 设备)？"
    ["pyocd_install_confirm"]="安装 pyocd？[y/N] "
    ["next_steps"]="后续步骤:"
    ["activate_env"]="1. 激活 RT-Thread ENV:"
    ["activate_cmd"]="   source %s/env.sh"
    ["add_to_profile"]="2. 添加到配置文件:"
    ["add_bashrc"]="   echo 'source %s/env.sh' >> ~/.bashrc"
    ["add_zshrc"]="   echo 'source %s/env.sh' >> ~/.zshrc"
    ["source_bashrc"]="   source ~/.bashrc"
    ["source_zshrc"]="   source ~/.zshrc"
    ["install_toolchain"]="3. 安装工具链:"
    ["install_toolchain_cmd"]="   运行 sdk 命令安装所需的工具链"
    ["after_activation"]="4. 激活后可用命令:"
    ["menuconfig"]="     - menuconfig    : 配置 RT-Thread"
    ["pkgs"]="     - pkgs          : 包管理器"
    ["scons"]="     - scons         : 编译 RT-Thread"
    ["sdk"]="     - sdk           : 安装工具链"
    ["fixing_ownership"]="正在修复文件所有权..."
    ["ownership_fixed"]="文件所有权已修复"
    ["using_custom_repo"]="使用自定义仓库: %s"
    ["using_custom_branch"]="使用分支: %s"
    ["using_custom_repo_branch"]="使用自定义仓库: %s (分支: %s)"
    ["missing_python"]="未找到 Python 3，请先安装"
    ["python_version_check"]="正在检查 Python 版本..."
    ["python_version"]="Python 版本: %s"
    ["python_version_failed"]="无法获取 Python 版本信息"
    ["using_cn_mirror"]="使用中国镜像源"
    ["using_official_source"]="使用官方源"
    ["using_pypi_mirror"]="使用 PyPI 镜像: %s"
    ["installed_packages"]="Python 包安装完成"
    ["copied_env_script"]="已复制 env.sh: %s"
    ["setup_complete"]="RT-Thread ENV 安装完成！"
    ["downloading_touch_env"]="正在下载 touch_env.py，自: %s"
    ["touch_env_downloaded"]="touch_env.py 下载完成。"
    ["touch_env_failed"]="touch_env.py 执行失败，退出码: %s"
    ["touch_env_download_failed"]="下载 touch_env.py 失败: %s"
    ["check_list"]="请检查:"
    ["check_list_connection"]="  1. 您的网络连接"
    ["check_list_url"]="  2. URL 是否正确: %s"
    ["check_list_alt_url"]="  3. 尝试使用 -t 参数指定不同的 URL"
)

# ============================================================================
# Download and Execute touch_env.py Functions
# ============================================================================

download_and_run_touch_env() {
    # Download touch_env.py script if not already downloaded
    local touch_env_script="$ENV_ROOT/tools/touch_env.py"
    local touch_env_download_url="$TOUCH_ENV_URL_GITHUB"

    # Determine touch_env.py download URL (priority: -t > --env > UseCN/Gitee > GitHub)
    if [ -n "$CONFIG_TOUCH_ENV_URL_VALUE" ]; then
        touch_env_download_url="$CONFIG_TOUCH_ENV_URL_VALUE"
    elif [ -n "$CONFIG_CUSTOM_ENV_REPO" ]; then
        # Use custom env repo for touch_env.py download
        # Parse URL and branch from string (format: url[#branch])
        local repo="$CONFIG_CUSTOM_ENV_REPO"
        local branch="master"
        if [[ "$repo" == *"#"* ]]; then
            branch="${repo#*#}"
            repo="${repo%#*}"
        fi

        # Convert GitHub repo URL to raw.githubusercontent.com URL
        if [[ "$repo" =~ ^https?://github\.com/([^/]+)/([^/]+?)(\.git)?$ ]]; then
            local owner="${BASH_REMATCH[1]}"
            local repo_name="${BASH_REMATCH[2]%.git}"
            touch_env_download_url="https://raw.githubusercontent.com/$owner/$repo_name/$branch/tools/touch_env.py"
        else
            # Non-GitHub repository: use /raw/ format
            touch_env_download_url="$repo/raw/$branch/tools/touch_env.py"
        fi
    elif [ "$CONFIG_USE_CN" = "true" ]; then
        touch_env_download_url="$TOUCH_ENV_URL_GITEE"
    fi

    log_info "downloading_touch_env" "$touch_env_download_url"

    # Create tools directory if needed
    mkdir -p "$ENV_ROOT/tools"

    local touch_env_dest="$touch_env_script"

    if [ ! -f "$touch_env_dest" ] || [ ! -s "$touch_env_dest" ]; then
        # Download touch_env.py
        if command -v curl &> /dev/null 2>&1; then
            curl -fsSL --connect-timeout 30 "$touch_env_download_url" -o "$touch_env_dest"
        elif command -v wget &> /dev/null 2>&1; then
            wget --timeout=30 -O "$touch_env_dest" "$touch_env_download_url"
        else
            log_error "touch_env_download_failed" "$touch_env_download_url"
            echo ""
            log_info "check_list"
            log_info "check_list_connection"
            log_info "check_list_url" "$touch_env_download_url"
            log_info "check_list_alt_url"
            return 1
        fi

        if [ ! -s "$touch_env_dest" ]; then
            log_error "touch_env_download_failed" "$touch_env_download_url"
            echo ""
            log_info "check_list"
            log_info "check_list_connection"
            log_info "check_list_url" "$touch_env_download_url"
            log_info "check_list_alt_url"
            return 1
        fi

        log_success "touch_env_downloaded"
    fi

    # Build Python command arguments for touch_env.py
    local python_args=()

    if [ -n "$CONFIG_ENV_ROOT" ]; then
        python_args+=("--env-root" "$CONFIG_ENV_ROOT")
    fi

    if [ "$CONFIG_USE_CN" = "true" ]; then
        python_args+=("--use-cn")
    fi

    if [ "$CONFIG_LANG" = "en" ]; then
        python_args+=("--language" "en")
    elif [ "$CONFIG_LANG" = "zh" ]; then
        python_args+=("--language" "zh")
    fi

    if [ "$CONFIG_AUTO_MODE" = "true" ]; then
        python_args+=("--auto-mode")
    fi

    if [ -n "$CONFIG_BACKUP_STRATEGY" ]; then
        python_args+=("--backup" "$CONFIG_BACKUP_STRATEGY")
    fi

    if [ "$CONFIG_PYOCD_MODE" = "true" ]; then
        python_args+=("--install-pyocd")
    fi

    if [ "$CONFIG_RESTORE_CONFIG" = "true" ]; then
        python_args+=("--restore-config")
    fi

    # Custom repositories
    if [ -n "$CONFIG_CUSTOM_PACKAGES_REPO" ]; then
        python_args+=("--repo-packages" "$CONFIG_CUSTOM_PACKAGES_REPO")
        if [ -n "$CONFIG_CUSTOM_PACKAGES_BRANCH" ]; then
            python_args+=("${CONFIG_CUSTOM_PACKAGES_REPO}#${CONFIG_CUSTOM_PACKAGES_BRANCH}")
        fi
    fi

    if [ -n "$CONFIG_CUSTOM_ENV_REPO" ]; then
        python_args+=("--repo-env" "$CONFIG_CUSTOM_ENV_REPO")
        if [ -n "$CONFIG_CUSTOM_ENV_BRANCH" ]; then
            python_args+=("${CONFIG_CUSTOM_ENV_REPO}#${CONFIG_CUSTOM_ENV_BRANCH}")
        fi
    fi

    if [ -n "$CONFIG_CUSTOM_SDK_REPO" ]; then
        python_args+=("--repo-sdk" "$CONFIG_CUSTOM_SDK_REPO")
        if [ -n "$CONFIG_CUSTOM_SDK_BRANCH" ]; then
            python_args+=("${CONFIG_CUSTOM_SDK_REPO}#${CONFIG_CUSTOM_SDK_BRANCH}")
        fi
    fi

    log_info "start"

    # Execute touch_env.py
    local python_cmd
    python_cmd=$(check_python)

    if "$python_cmd" = "" ]; then
        log_error "missing_python"
        return 1
    fi

    if ! python3 "$touch_env_dest" "${python_args[@]}"; then
        log_error "touch_env_failed" "$?"
        return 1
    fi

    return 0
}

# ============================================================================
# Message Functions
# ============================================================================

# Get message from dictionary (similar to PowerShell Get-Message)
get_message() {
    local key="$1"

    # Select appropriate language dictionary
    if [ "$CONFIG_LANG" = "zh" ]; then
        if [ -n "${MESSAGES_ZH[$key]+isset}" ]; then
            echo "${MESSAGES_ZH[$key]}"
        else
            echo "Unknown message: $key"
        fi
    else
        if [ -n "${MESSAGES_EN[$key]+isset}" ]; then
            echo "${MESSAGES_EN[$key]}"
        else
            echo "Unknown message: $key"
        fi
    fi
}

# Log functions (similar to PowerShell Write-LogInfo/Success/Warning/Error)
log_info() {
    local key="$1"
    shift
    local msg
    msg=$(get_message "$key")

    # Format message with arguments
    if [ $# -gt 0 ]; then
        # shellcheck disable=SC2059
        printf "\033[0;34m[%s]\033[0m ${msg}\n" "$(get_message 'info')" "$@" >&2
    else
        printf "\033[0;34m[%s]\033[0m ${msg}\n" "$(get_message 'info')" >&2
    fi
}

log_success() {
    local key="$1"
    shift
    local msg
    msg=$(get_message "$key")

    if [ $# -gt 0 ]; then
        # shellcheck disable=SC2059
        printf "\033[0;32m[%s]\033[0m ${msg}\n" "$(get_message 'success')" "$@" >&2
    else
        printf "\033[0;32m[%s]\033[0m ${msg}\n" "$(get_message 'success')" >&2
    fi
}

log_warning() {
    local key="$1"
    shift
    local msg
    msg=$(get_message "$key")

    if [ $# -gt 0 ]; then
        # shellcheck disable=SC2059
        printf "\033[1;33m[%s]\033[0m ${msg}\n" "$(get_message 'warning')" "$@" >&2
    else
        printf "\033[1;33m[%s]\033[0m ${msg}\n" "$(get_message 'warning')" >&2
    fi
}

log_error() {
    local key="$1"
    shift
    local msg
    msg=$(get_message "$key")

    if [ $# -gt 0 ]; then
        # shellcheck disable=SC2059
        printf "\033[0;31m[%s]\033[0m ${msg}\n" "$(get_message 'error')" "$@" >&2
    else
        printf "\033[0;31m[%s]\033[0m ${msg}\n" "$(get_message 'error')" >&2
    fi
}

# ============================================================================
# Git and Repository Functions
# ============================================================================

check_git() {
    if ! command -v git &> /dev/null; then
        log_info "git_not_found"
        log_info "please_install_git"
        if [[ "$OSTYPE" == "darwin"* ]]; then
            log_info "install_git_macos"
        else
            log_info "install_git_linux"
        fi
        return 1
    fi
    local git_version
    git_version=$(git --version 2>&1 | grep -E 'git version' | awk '{print $3}')
    log_info "git_found" "$git_version"
    return 0
}

clone_repo() {
    local url="$1"
    local destination="$2"
    local depth="${3:-1}"
    local branch="${4:-}"

    if [ ! -d "$destination" ]; then
        log_info "cloning" "$url" "$destination"
        local clone_args=("--depth" "$depth")
        if [ -n "$branch" ]; then
            clone_args+=("--branch" "$branch")
        fi
        if ! git clone "${clone_args[@]}" "$url" "$destination" 2>&1; then
            log_error "clone_failed" "$url"
            # Clean up partial clone
            rm -rf "$destination" 2>/dev/null || true
            exit 1
        fi
        log_success "cloned" "$destination"
    else
        # Verify it's a valid git repository
        if ! git -C "$destination" rev-parse --git-dir &>/dev/null; then
            log_error "invalid_git_repo" "$destination"
            rm -rf "$destination" 2>/dev/null || true
            exit 1
        fi
        log_success "dir_exists" "$destination"
    fi
}

generate_kconfig_file() {
    local env_dir="$1"

    mkdir -p "$env_dir/packages"

    local kconfig_path="$env_dir/packages/Kconfig"
    echo 'source "$PKGS_DIR/packages/Kconfig"' > "$kconfig_path"

    # Create local_pkgs directory for local package storage
    mkdir -p "$env_dir/local_pkgs"

    log_success "generating_kconfig" "$kconfig_path"
}

# ============================================================================
# Argument Parsing
# ============================================================================

print_help() {
    echo "$(get_message 'banner_title')"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -y, --yes, --auto    Auto-install without prompts"
    echo "  -c, --cn, --gitee    Use China mirror (Gitee, PyPI TUNA)"
    echo "  -o, --official       Force use official source"
    echo "  -d, --pyocd          Install pyocd for debugging"
    echo "  -r, --env-root <path> Set custom install directory"
    echo "  -e, --en, --english  Force English messages"
    echo "  -z, --zh, --chinese  Force Chinese messages"
    echo "  -P, --packages <repo>[#<branch>]  Specify custom packages repository and branch"
    echo "  -E, --env <repo>[#<branch>]  Specify custom env repository and branch"
    echo "  -S, --sdk <repo>[#<branch>]  Specify custom sdk repository and branch"
    echo "  -b, --backup <strategy> Backup strategy (preserve/delete_all/backup_all)"
    echo "  -t, --touch-env-url <url> Specify touch_env.py download URL"
    echo "  -h, --help           Show this help message"
    echo ""
}

parse_repo_arg() {
    local repo_arg="$1"
    local repo_name="$2"

    # Parse repo and branch (format: repo_url[:branch])
    if [[ "$repo_arg" == *":"* ]]; then
        printf "%s\n%s" "${repo_arg%:*}" "${repo_arg##*:}"
    else
        printf "%s\n%s" "$repo_arg" ""
    fi
}

detect_china() {
    # Check if user is in China (by IP or system locale)
    CONFIG_USE_CN="false"

    # Check IP-based detection (works on all systems)
    if command -v curl &> /dev/null 2>&1; then
        local ip_info=$(curl -s -m 5 --connect-timeout 3 "$IPINFO_URL" 2>&1)
        if [[ "$ip_info" == *"\"country\":\"CN\""* ]]; then
            CONFIG_USE_CN="true"
            CONFIG_LANG="zh"
        fi
    fi

    # Fallback: check system timezone
    if [ "$CONFIG_USE_CN" = "false" ]; then
        local timezone=$(date +%Z 2>/dev/null || timedatectl show -p Timezone --value 2>/dev/null || echo "")
        if [[ "$timezone" == *"CST"* ]] || [[ "$timezone" == *"Shanghai"* ]] || [[ "$timezone" == *"Beijing"* ]] || [[ "$timezone" == *"Asia/Shanghai"* ]]; then
            CONFIG_USE_CN="true"
            CONFIG_LANG="zh"
        fi
    fi

    # Fallback: check system locale
    if [ "$CONFIG_USE_CN" = "false" ]; then
        case "${LC_ALL}:${LANG}" in
            *zh*|*CN*)
                CONFIG_LANG="zh"
                ;;
            *)
                CONFIG_LANG="en"
                ;;
        esac
    fi
}

parse_args() {
    CONFIG_LANG="en"
    CONFIG_USE_CN="false"
    CONFIG_USE_CN_SET="false"
    CONFIG_OFFICIAL_MODE="false"
    CONFIG_PYOCD_MODE="false"
    CONFIG_AUTO_MODE="false"
    CONFIG_HELP_MODE="false"
    CONFIG_CUSTOM_PACKAGES_REPO=""
    CONFIG_CUSTOM_PACKAGES_BRANCH=""
    CONFIG_CUSTOM_ENV_REPO=""
    CONFIG_CUSTOM_ENV_BRANCH=""
    CONFIG_CUSTOM_SDK_REPO=""
    CONFIG_CUSTOM_SDK_BRANCH=""
    CONFIG_ENV_ROOT=""
    CONFIG_BACKUP_STRATEGY=""
    CONFIG_TOUCH_ENV_URL_VALUE=""

    while [ $# -gt 0 ]; do
        case "$1" in
            -h|--help)
                CONFIG_HELP_MODE="true"
                ;;
            -y|--yes|--auto)
                CONFIG_AUTO_MODE="true"
                ;;
            -e|--en|--english)
                CONFIG_EN_MODE="true"
                CONFIG_LANG="en"
                ;;
            -z|--zh|--chinese)
                CONFIG_ZH_MODE="true"
                CONFIG_LANG="zh"
                ;;
            -r|--env-root)
                shift
                CONFIG_ENV_ROOT="$1"
                ENV_ROOT="$1"
                ;;
            -P|--packages)
                shift
                read -r CONFIG_CUSTOM_PACKAGES_REPO CONFIG_CUSTOM_PACKAGES_BRANCH <<< "$(parse_repo_arg "$1" "packages")"
                ;;
            -E|--env)
                shift
                read -r CONFIG_CUSTOM_ENV_REPO CONFIG_CUSTOM_ENV_BRANCH <<< "$(parse_repo_arg "$1" "env")"
                ;;
            -S|--sdk)
                shift
                read -r CONFIG_CUSTOM_SDK_REPO CONFIG_CUSTOM_SDK_BRANCH <<< "$(parse_repo_arg "$1" "sdk")"
                ;;
            -c|--cn|--gitee)
                CONFIG_CN_MODE="true"
                CONFIG_USE_CN_SET="true"
                CONFIG_USE_CN="true"
                CONFIG_LANG="zh"
                ;;
            -o|--official)
                CONFIG_OFFICIAL_MODE="true"
                CONFIG_USE_CN_SET="true"
                ;;
            -d|--pyocd)
                CONFIG_PYOCD_MODE="true"
                ;;
            -b|--backup)
                shift
                CONFIG_BACKUP_STRATEGY="$1"
                ;;
            -t|--touch-env-url)
                shift
                CONFIG_TOUCH_ENV_URL_VALUE="$1"
                ;;
            --packages)
                shift
                read -r CONFIG_CUSTOM_PACKAGES_REPO CONFIG_CUSTOM_PACKAGES_BRANCH <<< "$(parse_repo_arg "$1" "packages")"
                ;;
            *)
                # Unknown argument, skip
                ;;
        esac
        shift
    done

    # IP detection (lower priority, only if not explicitly set)
    if [ "$CONFIG_USE_CN_SET" = "false" ]; then
        detect_china
    fi

    # Override with --official flag
    if [ "$CONFIG_OFFICIAL_MODE" = "true" ]; then
        CONFIG_USE_CN="false"
    fi

    # Log mirror selection result
    if [ "$CONFIG_USE_CN" = "true" ]; then
        log_info "using_cn_mirror"
    else
        log_info "using_official_source"
    fi
}

# ============================================================================
# System Detection
# ============================================================================

detect_os() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        echo "linux"
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

detect_linux_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/redhat-release ]; then
        echo "rhel"
    else
        echo "unknown"
    fi
}

detect_shell() {
    # Use REAL_USER_SHELL if available (handles sudo case), otherwise use $SHELL
    local shell_to_check="${REAL_USER_SHELL:-$SHELL}"

    if [[ "$shell_to_check" == *"zsh"* ]]; then
        echo "zsh"
    elif [[ "$shell_to_check" == *"bash"* ]]; then
        echo "bash"
    else
        echo "bash"  # Default to bash
    fi
}

# ============================================================================
# Dependency Installation
# ============================================================================

install_dependencies_linux() {
    local distro
    distro=$(detect_linux_distro)

    case "$distro" in
        ubuntu|debian)
            log_info "installing_ubuntu"
            sudo apt-get update -qq
            sudo apt-get install -y python3 python3-venv python3-pip git gcc libncurses-dev
            ;;
        suse|opensuse*)
            log_info "installing_suse"
            sudo zypper install -y python3 python3-pip git gcc ncurses-devel
            ;;
        arch|manjaro)
            log_info "installing_arch"
            sudo pacman -S --noconfirm python python-pip git gcc ncurses
            ;;
        rhel|centos|fedora)
            log_info "installing_fedora"
            sudo dnf install -y python3 python3-pip git gcc ncurses-devel
            ;;
        alpine)
            log_info "installing_alpine"
            apk add --no-cache python3 py3-pip git gcc ncurses-dev linux-headers musl-dev
            ;;
        *)
            log_error "unsupported_os" "$distro"
            log_info "missing_gcc"
            exit 1
            ;;
    esac
}

install_dependencies_macos() {
    log_info "installing_macos"

    # Install Homebrew if not installed
    if ! command -v brew &> /dev/null; then
        log_info "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL "$HOMEBREW_INSTALL_URL")"
    fi

    # Update Homebrew
    brew update

    # Install dependencies
    brew list python &> /dev/null || brew install python
    brew list git &> /dev/null || brew install git
    brew list ncurses &> /dev/null || brew install ncurses
}

install_dependencies() {
    local os_type
    os_type=$(detect_os)

    case "$os_type" in
        linux)
            install_dependencies_linux
            ;;
        macos)
            install_dependencies_macos
            ;;
        *)
            log_error "unsupported_os" "$os_type"
            exit 1
            ;;
    esac
}

# ============================================================================
# Python Environment Setup
# ============================================================================

check_python() {
    local python_cmd=""

    # Find Python 3.x
    for cmd in python3 python; do
        if command -v "$cmd" &> /dev/null; then
            python_cmd="$cmd"
            break
        fi
    done

    if [ -z "$python_cmd" ]; then
        log_error "missing_python"
        exit 1
    fi

    # Check Python version
    log_info "python_version_check"
    local version
    version=$($python_cmd --version 2>&1)
    if [ $? -eq 0 ]; then
        # Extract version number more reliably
        version=$(echo "$version" | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+')
        log_info "python_version" "$version"
    else
        log_error "python_version_failed"
        exit 1
    fi

    echo "$python_cmd"
}

install_python_packages() {
    local use_cn_mirror="$1"
    local scripts_dir="$2"
    local install_pyocd="$3"

    local python_cmd
    python_cmd=$(check_python)

    # Upgrade pip first
    log_info "upgrading_pip"
    $python_cmd -m pip install --upgrade pip

    # Build pip install command arguments
    local pip_args=""

    if [ "$use_cn_mirror" = "true" ]; then
        log_info "using_cn_mirror"
        log_info "using_pypi_mirror" "$PYPI_MIRROR_CN"
        pip_args="--index-url $PYPI_MIRROR_CN"
    else
        log_info "using_official_source"
    fi

    pip_args="$pip_args -e $scripts_dir"

    # Add pyocd if requested
    if [ "$install_pyocd" = "true" ]; then
        pip_args="$pip_args pyocd"
    fi

    # Install all packages in one command
    log_info "installing_packages"
    if $python_cmd -m pip install $pip_args; then
        log_success "installed_packages"
    else
        log_error "package_install_failed"
        exit1
    fi
}

create_venv() {
    local python_cmd
    python_cmd=$(check_python)

    # Create virtual environment if it doesn't exist
    if [ ! -d "$ENV_ROOT/$VENV_DIR" ]; then
        log_info "creating_venv"
        $python_cmd -m venv "$ENV_ROOT/$VENV_DIR"
        log_success "venv_created"
    else
        log_success "venv_exists"
    fi
}

install_python_packages() {
    local use_cn_mirror="$1"
    local scripts_dir="$2"
    local install_pyocd="$3"

    log_info "activating_venv"

    # Activate virtual environment
    # shellcheck source=/dev/null
    if [ -f "$ENV_ROOT/$VENV_DIR/bin/activate" ]; then
        source "$ENV_ROOT/$VENV_DIR/bin/activate"
    else
        log_error "venv_not_found"
        exit 1
    fi

    # Upgrade pip first
    log_info "upgrading_pip"
    pip install --upgrade pip

    # Build pip install command arguments
    local pip_args=""

    if [ "$use_cn_mirror" = "true" ]; then
        log_info "using_cn_mirror"
        log_info "using_pypi_mirror" "$PYPI_MIRROR_CN"
        pip_args="--index-url $PYPI_MIRROR_CN"
    else
        log_info "using_official_source"
    fi

    pip_args="$pip_args -e $scripts_dir"

    # Add pyocd if requested
    if [ "$install_pyocd" = "true" ]; then
        pip_args="$pip_args pyocd"
    fi

    # Install all packages in one command
    log_info "installing_packages"
    if pip install $pip_args; then
        log_success "installed_packages"
    else
        log_error "package_install_failed"
        exit 1
    fi
}

# ============================================================================
# Banner and Next Steps
# ============================================================================

print_banner() {
    echo ""
    echo "============================================================"
    echo "   $(get_message 'banner_title')   "
    echo "============================================================"
    echo ""
}

print_next_steps() {
    local env_dir="$ENV_ROOT"
    local current_shell
    current_shell=$(detect_shell)

    local shell_config
    if [[ "$OSTYPE" == "darwin"* ]]; then
        shell_config="~/.zshrc"
    else
        if [ "$current_shell" = "zsh" ]; then
            shell_config="~/.zshrc"
        else
            shell_config="~/.bashrc"
        fi
    fi

    echo ""
    echo "============================================================"
    log_success "setup_complete"
    echo "============================================================"
    echo ""
    log_info "$(get_message 'next_steps')"
    echo ""
    echo "$(get_message 'activate_env')"
    echo "   source $env_dir/env.sh"
    echo ""
    echo "$(get_message 'add_to_profile')"
    echo "   echo 'source $env_dir/env.sh' >> $shell_config"
    echo "   source $shell_config"
    echo ""
    echo "$(get_message 'install_toolchain')"
    echo "   $(get_message 'install_toolchain_cmd')"
    echo ""
    echo "$(get_message 'after_activation')"
    echo "   - menuconfig    : $(get_message 'menuconfig')"
    echo "   - pkgs          : $(get_message 'pkgs')"
    echo "   - scons         : $(get_message 'scons')"
    echo "   - sdk           : $(get_message 'sdk')"
    echo ""
}

# ============================================================================
# Main Function
# ============================================================================

# Check if ENV_ROOT already exists and prompt for reinstallation
check_existing_env() {
    # Check if any ENV subdirectory exists
    local existing_dirs=()
    [ -d "$ENV_ROOT/tools" ] && existing_dirs+=("$ENV_ROOT/tools")
    [ -d "$ENV_ROOT/packages" ] && existing_dirs+=("$ENV_ROOT/packages")

    local env_script="$ENV_ROOT/env.sh"
    local env_script_exists=false
    [ -f "$env_script" ] && env_script_exists=true

    if [ ${#existing_dirs[@]} -gt 0 ] || [ "$env_script_exists" = true ]; then
        log_warning "env_root_exists" "$ENV_ROOT"
        # Show what will be deleted
        echo "  将删除以下目录/文件:" >&2
        for dir in "${existing_dirs[@]}"; do
            echo "    - $dir" >&2
        done
        [ "$env_script_exists" = true ] && echo "    - $env_script" >&2
        echo ""
        if [ "$CONFIG_AUTO_MODE" = "true" ]; then
            log_info "removing_env_root_preserving" "$ENV_ROOT"
            # Preserve config and local_pkgs
            local config_backup=""
            [ -f "$ENV_ROOT/tools/scripts/cmds/.config" ] && config_backup="$ENV_ROOT/tools/scripts/cmds/.config"
            for dir in "${existing_dirs[@]}"; do
                rm -rf "$dir" 2>/dev/null || true
            done
            [ "$env_script_exists" = true ] && rm -f "$env_script"
            # Restore config if backed up
            if [ -n "$config_backup" ]; then
                mkdir -p "$ENV_ROOT/tools/scripts/cmds" 2>/dev/null || true
                cp "$config_backup" "$ENV_ROOT/tools/scripts/cmds/.config" 2>/dev/null || true
            fi
            log_success "env_root_removed" "$ENV_ROOT"
        else
            echo ""
            echo "$(get_message 'env_root_prompt')"
            printf "%s" "$(get_message 'env_root_confirm')" >&2
            read -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                # Preserve config and toolchain
                log_info "removing_env_root_preserving" "$ENV_ROOT"
                local config_backup=""
                [ -f "$ENV_ROOT/tools/scripts/cmds/.config" ] && config_backup="$ENV_ROOT/tools/scripts/cmds/.config"
                for dir in "${existing_dirs[@]}"; do
                    rm -rf "$dir" 2>/dev/null || true
                done
                [ "$env_script_exists" = true ] && rm -f "$env_script"
                # Restore config if backed up
                if [ -n "$config_backup" ]; then
                    mkdir -p "$ENV_ROOT/tools/scripts/cmds" 2>/dev/null || true
                    cp "$config_backup" "$ENV_ROOT/tools/scripts/cmds/.config" 2>/dev/null || true
                fi
                log_success "env_root_removed" "$ENV_ROOT"
            elif [[ $REPLY =~ ^[Aa]$ ]]; then
                # Delete entire directory
                log_info "removing_env_root_all" "$ENV_ROOT"
                rm -rf "$ENV_ROOT" 2>/dev/null || true
                log_success "env_root_removed" "$ENV_ROOT"
            else
                log_info "installation_cancelled"
                exit 0
            fi
        fi
    fi
}

# Clone repositories and generate configuration
setup_repos() {
    local url_packages url_env url_sdk

    # Determine repository URLs based on individual custom options
    local use_custom_packages=false
    local use_custom_env=false
    local use_custom_sdk=false

    if [ -n "$CONFIG_CUSTOM_PACKAGES_REPO" ]; then
        use_custom_packages=true
        url_packages="$CONFIG_CUSTOM_PACKAGES_REPO"
        if [ -n "$CONFIG_CUSTOM_PACKAGES_BRANCH" ]; then
            log_info "using_custom_repo_branch" "$CONFIG_CUSTOM_PACKAGES_REPO" "$CONFIG_CUSTOM_PACKAGES_BRANCH"
        else
            log_info "using_custom_repo" "$CONFIG_CUSTOM_PACKAGES_REPO"
        fi
    fi

    if [ -n "$CONFIG_CUSTOM_ENV_REPO" ]; then
        use_custom_env=true
        url_env="$CONFIG_CUSTOM_ENV_REPO"
        if [ -n "$CONFIG_CUSTOM_ENV_BRANCH" ]; then
            log_info "using_custom_repo_branch" "$CONFIG_CUSTOM_ENV_REPO" "$CONFIG_CUSTOM_ENV_BRANCH"
        else
            log_info "using_custom_repo" "$CONFIG_CUSTOM_ENV_REPO"
        fi
    fi

    if [ -n "$CONFIG_CUSTOM_SDK_REPO" ]; then
        use_custom_sdk=true
        url_sdk="$CONFIG_CUSTOM_SDK_REPO"
        if [ -n "$CONFIG_CUSTOM_SDK_BRANCH" ]; then
            log_info "using_custom_repo_branch" "$CONFIG_CUSTOM_SDK_REPO" "$CONFIG_CUSTOM_SDK_BRANCH"
        else
            log_info "using_custom_repo" "$CONFIG_CUSTOM_SDK_REPO"
        fi
    fi

    # Use standard repositories for any not specified
    if [ "$use_custom_packages" = "false" ]; then
        url_packages=$(if [ "$CONFIG_USE_CN" = "true" ]; then echo "$REPO_PACKAGES_GITEE"; else echo "$REPO_PACKAGES_GITHUB"; fi)
    fi

    if [ "$use_custom_env" = "false" ]; then
        url_env=$(if [ "$CONFIG_USE_CN" = "true" ]; then echo "$REPO_ENV_GITEE"; else echo "$REPO_ENV_GITHUB"; fi)
    fi

    if [ "$use_custom_sdk" = "false" ]; then
        url_sdk=$(if [ "$CONFIG_USE_CN" = "true" ]; then echo "$REPO_SDK_GITEE"; else echo "$REPO_SDK_GITHUB"; fi)
    fi

    # Clone repositories
    clone_repo "$url_packages" "$ENV_ROOT/packages/packages" 1 "$CONFIG_CUSTOM_PACKAGES_BRANCH"
    clone_repo "$url_sdk" "$ENV_ROOT/packages/sdk" 1 "$CONFIG_CUSTOM_SDK_BRANCH"
    clone_repo "$url_env" "$ENV_ROOT/tools/scripts" 1 "$CONFIG_CUSTOM_ENV_BRANCH"

    generate_kconfig_file "$ENV_ROOT"

    if [ -f "$ENV_ROOT/tools/scripts/env.sh" ]; then
        cp "$ENV_ROOT/tools/scripts/env.sh" "$ENV_ROOT/env.sh"
        log_success "copied_env_script" "$ENV_ROOT/env.sh"
    fi
}

# Prompt user for pyocd installation
prompt_pyocd() {
    # If --pyocd was specified, skip prompt and install directly
    if [ "$CONFIG_PYOCD_MODE" = "true" ]; then
        return
    fi

    if [ "$CONFIG_PYOCD_MODE" = "false" ]; then
        if [ "$CONFIG_AUTO_MODE" = "true" ]; then
            CONFIG_PYOCD_MODE="false"
        else
            echo ""
            echo "$(get_message 'pyocd_install_prompt')"
            printf "%s" "$(get_message 'pyocd_install_confirm')" >&2
            read -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                CONFIG_PYOCD_MODE="true"
            fi
        fi
    fi
}

# Fix file ownership if running with sudo
fix_ownership() {
    if [ -n "$SUDO_USER" ]; then
        log_info "fixing_ownership"
        chown -R "$REAL_USER:$REAL_USER" "$ENV_ROOT"
        log_success "ownership_fixed"
    fi
}

main() {
    set -e  # Exit on error

    # Step 1: Parse command line arguments
    parse_args "$@"

    # Step 2: Print help if requested
    if [ "$CONFIG_HELP_MODE" = "true" ]; then
        print_help
        exit 0
    fi

    # Step 3: Print installation banner
    print_banner

    # Step 4: Check if ENV_ROOT already exists and handle reinstallation
    check_existing_env

    # Step 5: Install system dependencies (python3, git, gcc, ncurses)
    install_dependencies

    # Step 6: Download and execute touch_env.py (handles setup, venv, packages, etc.)
    download_and_run_touch_env

    # Step 7: Fix file ownership if running with sudo
    fix_ownership

    # Step 8: Print next steps for user
    print_next_steps
}

# ============================================================================
# Run Main Function
# ============================================================================

main "$@"
