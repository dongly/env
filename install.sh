#!/usr/bin/env bash
#
# RT-Thread ENV Installation Script (Unix)
# Unified installation script for Linux and macOS
# Supports: English / 中文
#
# Usage:
#   ./install.sh [-y] [--cn|--gitee|--no-mirror] [--pyocd] [--env-root <path>] [--en|--zh] [-h|--help]
#
# Options:
#   -y           Auto-install without prompts
#   --cn/--gitee Use China mirror (Gitee, PyPI TUNA)
#   --no-mirror  Force use official source
#   --pyocd      Install pyocd for debugging
#   --env-root   Set custom install directory
#   --en/--zh    Force language (English/Chinese)
#   -h/--help    Show this help message
#

# ============================================================================
# Configuration
# ============================================================================

# Get the real user's home directory (handles sudo case)
if [ -n "$SUDO_USER" ]; then
    # Running with sudo, use the original user's home
    REAL_USER_HOME=$(eval echo ~$SUDO_USER)
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

# Virtual environment directory name
VENV_DIR="rt-venv"

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
    log_success "git_found" "$git_version"
    return 0
}

clone_repo() {
    local url="$1"
    local destination="$2"
    local depth="${3:-1}"

    if [ ! -d "$destination" ]; then
        log_info "cloning" "$url" "$destination"
        if ! git clone --depth "$depth" "$url" "$destination" 2>&1; then
            log_error "clone_failed" "$url"
            exit 1
        fi
        log_success "cloned" "$destination"
    else
        log_success "dir_exists" "$destination"
    fi
}

generate_kconfig_file() {
    local env_dir="$1"

    mkdir -p "$env_dir/packages"

    local kconfig_path="$env_dir/packages/Kconfig"
    echo 'source "$PKGS_DIR/packages/Kconfig"' > "$kconfig_path"

    log_success "generating_kconfig" "$kconfig_path"
}

# ============================================================================
# Argument Parsing
# ============================================================================

LANG_CURRENT="en"

print_help() {
    if [ "$LANG_CURRENT" = "zh" ]; then
        echo "RT-Thread ENV 安装程序"
        echo ""
        echo "用法: $0 [选项]"
        echo ""
        echo "选项:"
        echo "  -y, --yes, --auto    自动安装，无需提示"
        echo "  --cn, --gitee        使用中国镜像（Gitee，清华 PyPI）"
        echo "  --no-mirror          强制使用官方源"
        echo "  --pyocd              安装 pyocd（用于调试）"
        echo "  --env-root <path>    设置自定义安装目录"
        echo "  --en, --english      强制显示英文信息"
        echo "  --zh, --chinese      强制显示中文信息"
        echo "  -h, --help           显示此帮助信息"
        echo ""
    else
        echo "RT-Thread ENV Installation Script"
        echo ""
        echo "Usage: $0 [OPTIONS]"
        echo ""
        echo "Options:"
        echo "  -y, --yes, --auto    Auto-install without prompts"
        echo "  --cn, --gitee        Use China mirror (Gitee, PyPI TUNA)"
        echo "  --no-mirror          Force use official source"
        echo "  --pyocd              Install pyocd for debugging"
        echo "  --env-root <path>    Set custom install directory"
        echo "  --en, --english      Force English messages"
        echo "  --zh, --chinese      Force Chinese messages"
        echo "  -h, --help           Show this help message"
        echo ""
    fi
    exit 0
}

detect_china() {
    # Check if user is in China (by IP or system locale)
    use_cn="false"

    # Check IP-based detection (works on all systems)
    if command -v curl &> /dev/null 2>&1; then
        local ip_info=$(curl -s -m 5 --connect-timeout 3 "$IPINFO_URL" 2>&1)
        if [[ "$ip_info" == *"\"country\":\"CN\""* ]]; then
            use_cn="true"
            LANG_CURRENT="zh"
        fi
    fi

    # Fallback: check system timezone
    if [ "$use_cn" = "false" ]; then
        local timezone=$(date +%Z 2>/dev/null || timedatectl show -p Timezone --value 2>/dev/null || echo "")
        if [[ "$timezone" == *"CST"* ]] || [[ "$timezone" == *"Shanghai"* ]] || [[ "$timezone" == *"Beijing"* ]] || [[ "$timezone" == *"Asia/Shanghai"* ]]; then
            use_cn="true"
            LANG_CURRENT="zh"
        fi
    fi

    # Fallback: check system locale
    if [ "$use_cn" = "false" ]; then
        case "${LC_ALL}:${LANG}" in
            *zh*|*CN*)
                LANG_CURRENT="zh"
                ;;
            *)
                LANG_CURRENT="en"
                ;;
        esac
    fi
}

parse_args() {
    LANG_CURRENT="en"
    use_cn="false"
    use_cn_set="false"
    install_pyocd="false"
    auto_mode="false"
    need_help="false"

    for arg in "$@"; do
        case "$arg" in
            -h|--help)
                need_help="true"
                ;;
            -y|--yes|--auto)
                auto_mode="true"
                ;;
            --en|--english)
                LANG_CURRENT="en"
                ;;
            --zh|--chinese|--中文)
                LANG_CURRENT="zh"
                ;;
            --env-root)
                shift
                ENV_ROOT="$1"
                ;;
            --cn|--gitee)
                use_cn="true"
                use_cn_set="true"
                LANG_CURRENT="zh"
                ;;
            --no-mirror)
                use_cn="false"
                use_cn_set="true"
                ;;
            --pyocd)
                install_pyocd="true"
                ;;
        esac
    done

    # IP detection (lower priority, only if not explicitly set)
    if [ "$use_cn_set" = "false" ]; then
        detect_china
    fi

    # Log IP detection result
    if [ "$use_cn" = "true" ]; then
        log_info "using_cn_mirror"
    else
        log_info "using_official_source"
    fi
    
    if [ "$need_help" = "true" ]; then
        print_help
        exit 0
    fi
}

# Message retrieval function
get_message() {
    local key="$1"
    case "$LANG_CURRENT" in
        zh)
            case "$key" in
                info) echo "信息" ;;
                success) echo "成功" ;;
                warning) echo "警告" ;;
                error) echo "错误" ;;
                banner_title) echo "RT-Thread ENV 安装程序" ;;
                git_not_found) echo "未安装 Git。请先安装 Git。" ;;
                please_install_git) echo "请先安装 Git" ;;
                install_git_macos) echo "macOS: brew install git" ;;
                install_git_linux) echo "Linux: sudo apt-get install git (Ubuntu/Debian) 或 sudo dnf install git (Fedora/RHEL)" ;;
                cloning) echo "正在克隆: %s 到 %s" ;;
                cloned) echo "已克隆: %s" ;;
                dir_exists) echo "目录已存在: %s" ;;
                generating_kconfig) echo "生成 Kconfig: %s" ;;
                installing_ubuntu) echo "正在安装依赖 (Ubuntu/Debian)..." ;;
                installing_suse) echo "正在安装依赖 (SUSE/openSUSE)..." ;;
                installing_arch) echo "正在安装依赖 (Arch/Manjaro)..." ;;
                installing_fedora) echo "正在安装依赖 (Fedora/RHEL/CentOS)..." ;;
                unsupported_os) echo "不支持的操作系统: %s" ;;
                missing_gcc) echo "缺少 GCC 编译器，请手动安装" ;;
                installing_macos) echo "正在安装依赖 (macOS)..." ;;
                installing_packages) echo "正在安装 Python 包..." ;;
                env_root_exists) echo "RT-Thread ENV 目录已存在: %s" ;;
                env_root_prompt) echo "检测到已存在的RT-Thread ENV。是否要删除并重新安装？" ;;
                env_root_confirm) echo "确定要删除吗？[y/N] " ;;
                removing_env_root) echo "正在删除现有RT-Thread ENV ..." ;;
                env_root_removed) echo "现有 RT-Thread ENV 已删除" ;;
                installation_cancelled) echo "安装已取消" ;;
                venv_not_found) echo "找不到虚拟环境，请重新创建" ;;
                upgrading_pip) echo "正在升级 pip..." ;;
                package_install_failed) echo "包安装失败，请检查网络连接或权限" ;;
                installing_pyocd) echo "正在安装 pyocd..." ;;
                pyocd_installed) echo "pyocd 安装成功" ;;
                pyocd_install_failed) echo "pyocd 安装失败，请检查网络连接或权限" ;;
                pyocd_install_prompt) echo "是否要安装 pyocd (用于调试 Cortex-M 设备)？" ;;
                pyocd_install_confirm) echo "安装 pyocd？[y/N] " ;;
                installation_skip_existing) echo "RT-Thread ENV 已存在，跳过安装（使用 -y 参数强制重新安装）" ;;
                missing_python) echo "未找到 Python 3，请先安装" ;;
                python_version_check) echo "正在检查 Python 版本..." ;;
                python_version) echo "Python 版本: %s" ;;
                python_version_failed) echo "无法获取 Python 版本信息" ;;
                creating_venv) echo "正在创建虚拟环境..." ;;
                venv_created) echo "虚拟环境创建完成" ;;
                venv_exists) echo "虚拟环境已存在" ;;
                activating_venv) echo "正在激活虚拟环境..." ;;
                using_cn_mirror) echo "使用中国镜像源" ;;
                using_official_source) echo "使用官方源" ;;
                using_pypi_mirror) echo "使用 PyPI 镜像: %s" ;;
                installed_packages) echo "Python 包安装完成" ;;
                copied_env_script) echo "已复制 env.sh: %s" ;;
                setup_complete) echo "RT-Thread ENV 安装完成！" ;;
                next_steps) echo "后续步骤:" ;;
                activate_env) echo "1. 激活 RT-Thread ENV:" ;;
                activate_cmd) echo "   source %s/env.sh" ;;
                add_to_profile) echo "2. 添加到配置文件:" ;;
                add_bashrc) echo "   echo 'source %s/env.sh' >> ~/.bashrc" ;;
                add_zshrc) echo "   echo 'source %s/env.sh' >> ~/.zshrc" ;;
                source_bashrc) echo "   source ~/.bashrc" ;;
                source_zshrc) echo "   source ~/.zshrc" ;;
                install_toolchain) echo "3. 安装工具链:" ;;
                install_toolchain_cmd) echo "   运行 sdk 命令安装所需的工具链" ;;
                after_activation) echo "4. 激活后可用命令:" ;;
                menuconfig) echo "     - menuconfig    : 配置 RT-Thread" ;;
                pkgs) echo "     - pkgs          : 包管理器" ;;
                scons) echo "     - scons         : 编译 RT-Thread" ;;
                sdk) echo "     - sdk           : 安装工具链" ;;
                fixing_ownership) echo "正在修复文件所有权..." ;;
                ownership_fixed) echo "文件所有权已修复" ;;
                *) echo "$key" ;;
            esac
            ;;
        *)
            case "$key" in
                info) echo "INFO" ;;
                success) echo "SUCCESS" ;;
                warning) echo "WARNING" ;;
                error) echo "ERROR" ;;
                banner_title) echo "RT-Thread ENV Installation" ;;
                git_not_found) echo "Git is not installed. Please install Git first." ;;
                please_install_git) echo "Please install Git first" ;;
                install_git_macos) echo "macOS: brew install git" ;;
                install_git_linux) echo "Linux: sudo apt-get install git (Ubuntu/Debian) or sudo dnf install git (Fedora/RHEL)" ;;
                cloning) echo "Cloning %s to %s" ;;
                cloned) echo "Cloned %s" ;;
                dir_exists) echo "Directory already exists: %s" ;;
                generating_kconfig) echo "Generating Kconfig: %s" ;;
                installing_ubuntu) echo "Installing dependencies (Ubuntu/Debian)..." ;;
                installing_suse) echo "Installing dependencies (SUSE/openSUSE)..." ;;
                installing_arch) echo "Installing dependencies (Arch/Manjaro)..." ;;
                installing_fedora) echo "Installing dependencies (Fedora/RHEL/CentOS)..." ;;
                unsupported_os) echo "Unsupported OS: %s" ;;
                missing_gcc) echo "Missing GCC compiler, please install manually" ;;
                installing_macos) echo "Installing dependencies (macOS)..." ;;
                installing_packages) echo "Installing Python packages..." ;;
                using_cn_mirror) echo "Using China mirror" ;;
                using_official_source) echo "Using official source" ;;
                using_pypi_mirror) echo "Using PyPI mirror: %s" ;;
                env_root_exists) echo "RT-Thread ENV directory already exists: %s" ;;
                env_root_prompt) echo "Existing RT-Thread ENV detected. Do you want to delete and reinstall?" ;;
                env_root_confirm) echo "Are you sure you want to delete? [y/N] " ;;
                removing_env_root) echo "Removing existing RT-Thread ENV..." ;;
                env_root_removed) echo "Existing RT-Thread ENV removed" ;;
                installation_cancelled) echo "Installation cancelled" ;;
                installation_skip_existing) echo "RT-Thread ENV already exists, skipping installation (use -y to force reinstall)" ;;
                venv_not_found) echo "Virtual environment not found, please recreate" ;;
                upgrading_pip) echo "Upgrading pip..." ;;
                package_install_failed) echo "Package installation failed, please check network connection or permissions" ;;
                installing_pyocd) echo "Installing pyocd..." ;;
                pyocd_installed) echo "pyocd installed successfully" ;;
                pyocd_install_failed) echo "pyocd installation failed, please check network connection or permissions" ;;
                pyocd_install_prompt) echo "Do you want to install pyocd (for debugging Cortex-M devices)?" ;;
                pyocd_install_confirm) echo "Install pyocd? [y/N] " ;;
                installation_skip_existing) echo "RT-Thread ENV already exists, skipping installation (use -y to force reinstall)" ;;
                next_steps) echo "Next steps:" ;;
                activate_env) echo "1. Activate RT-Thread ENV:" ;;
                activate_cmd) echo "   source %s/env.sh" ;;
                add_to_profile) echo "2. Add to profile:" ;;
                add_bashrc) echo "   echo 'source %s/env.sh' >> ~/.bashrc" ;;
                add_zshrc) echo "   echo 'source %s/env.sh' >> ~/.zshrc" ;;
                source_bashrc) echo "   source ~/.bashrc" ;;
                source_zshrc) echo "   source ~/.zshrc" ;;
                install_toolchain) echo "3. Install toolchains:" ;;
                install_toolchain_cmd) echo "   Run 'sdk' command to install required toolchains" ;;
                after_activation) echo "4. After activation, you can use:" ;;
                menuconfig) echo "     - menuconfig    : Configure RT-Thread" ;;
                pkgs) echo "     - pkgs          : Package manager" ;;
                scons) echo "     - scons         : Build RT-Thread" ;;
                sdk) echo "     - sdk           : Install toolchains" ;;
                fixing_ownership) echo "Fixing file ownership..." ;;
                ownership_fixed) echo "File ownership fixed" ;;
                *) echo "$key" ;;
            esac
            ;;
    esac
}

# Print colored messages
log_info() {
    local msg
    msg=$(get_message "$1")
    shift
    # shellcheck disable=SC2059
    printf "\033[0;34m[%s]\033[0m ${msg}\n" "$(get_message 'info')" "$@" >&2
}

log_success() {
    local msg
    msg=$(get_message "$1")
    shift
    # shellcheck disable=SC2059
    printf "\033[0;32m[%s]\033[0m ${msg}\n" "$(get_message 'success')" "$@" >&2
}

log_warning() {
    local msg
    msg=$(get_message "$1")
    shift
    # shellcheck disable=SC2059
    printf "\033[1;33m[%s]\033[0m ${msg}\n" "$(get_message 'warning')" "$@" >&2
}

log_error() {
    local msg
    msg=$(get_message "$1")
    shift
    # shellcheck disable=SC2059
    printf "\033[0;31m[%s]\033[0m ${msg}\n" "$(get_message 'error')" "$@" >&2
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
        log_info "installing_pyocd"
        pip_args="$pip_args pyocd"
    fi

    # Install all packages in one command
    log_info "installing_packages"
    if pip install $pip_args; then
        log_success "installed_packages"
        if [ "$install_pyocd" = "true" ]; then
            log_success "pyocd_installed"
        fi
    else
        log_error "package_install_failed"
        if [ "$install_pyocd" = "true" ]; then
            log_error "pyocd_install_failed"
        fi
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
    echo "   - menuconfig    : $(get_message 'menuconfig' | sed 's/- menuconfig    : //')"
    echo "   - pkgs          : $(get_message 'pkgs' | sed 's/- pkgs          : //')"
    echo "   - scons         : $(get_message 'scons' | sed 's/- scons         : //')"
    echo "   - sdk           : $(get_message 'sdk' | sed 's/- sdk           : //')"
    echo ""
}

# ============================================================================
# Main Function
# ============================================================================

# Check if ENV_ROOT already exists and prompt for reinstallation
check_existing_env() {
    if [ -d "$ENV_ROOT" ] && [ -f "$ENV_ROOT/env.sh" ]; then
        log_warning "env_root_exists" "$ENV_ROOT"
        if [ "$auto_mode" = "true" ]; then
            log_info "removing_env_root"
            rm -rf "$ENV_ROOT"
            log_success "env_root_removed"
        else
            echo ""
            echo "$(get_message 'env_root_prompt')"
            printf "%s" "$(get_message 'env_root_confirm')" >&2
            read -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                log_info "removing_env_root"
                rm -rf "$ENV_ROOT"
                log_success "env_root_removed"
            else
                log_info "installation_cancelled"
                exit 0
            fi
        fi
    fi
}

# Clone repositories and generate configuration
setup_repos() {
    local repo_config
    if [ "$use_cn" = "true" ]; then
        repo_config="$REPO_PACKAGES_GITEE|$REPO_ENV_GITEE|$REPO_SDK_GITEE"
    else
        repo_config="$REPO_PACKAGES_GITHUB|$REPO_ENV_GITHUB|$REPO_SDK_GITHUB"
    fi

    local url_packages url_env url_sdk
    IFS='|' read -r url_packages url_env url_sdk <<< "$repo_config"

    clone_repo "$url_packages" "$ENV_ROOT/packages/packages" 1
    clone_repo "$url_sdk" "$ENV_ROOT/packages/sdk" 1
    generate_kconfig_file "$ENV_ROOT"
    clone_repo "$url_env" "$ENV_ROOT/tools/scripts" 1

    if [ -f "$ENV_ROOT/tools/scripts/env.sh" ]; then
        cp "$ENV_ROOT/tools/scripts/env.sh" "$ENV_ROOT/env.sh"
        log_success "copied_env_script" "$ENV_ROOT/env.sh"
    fi
}

# Prompt user for pyocd installation
prompt_pyocd() {
    if [ "$install_pyocd" = "false" ]; then
        if [ "$auto_mode" = "true" ]; then
            install_pyocd="false"
        else
            echo ""
            echo "$(get_message 'pyocd_install_prompt')"
            printf "%s" "$(get_message 'pyocd_install_confirm')" >&2
            read -n 1 -r
            echo ""
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                install_pyocd="true"
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

    # Step 2: Print installation banner
    print_banner

    # Step 3: Check if ENV_ROOT already exists and handle reinstallation
    check_existing_env

    # Step 4: Install system dependencies (python3, git, gcc, ncurses)
    install_dependencies

    # Step 5: Clone repositories (packages, sdk, env) and generate Kconfig
    setup_repos

    # Step 6: Create Python virtual environment
    echo ""
    create_venv

    # Step 7: Prompt user for pyocd installation (optional debugging tool)
    prompt_pyocd

    # Step 8: Install Python packages (from setup.py) and pyocd (if requested)
    echo ""
    install_python_packages "$use_cn" "$ENV_ROOT/tools/scripts" "$install_pyocd"
    echo ""

    # Step 9: Fix file ownership if running with sudo
    fix_ownership

    # Step 10: Print next steps for user
    print_next_steps
}

# ============================================================================
# Run Main Function
# ============================================================================

main "$@"
