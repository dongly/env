#
# RT-Thread ENV Installation Script (Windows)
# Unified installation script for Windows
# Supports: English / 中文
#
# Usage:
#   .\install.ps1 [-y] [-c] [-o] [-p] [-e <path>] [-E|-Z] [-P] [--packages <repo>[#<branch>]] [--env <repo>[#<branch>]] [--sdk <repo>[#<branch>]] [--skip-long-path] [-h]
#
# Options:
#   -y, --yes, --auto    Auto-install without prompts
#   -c, --cn, --gitee    Use China mirror (Gitee, PyPI TUNA)
#   -o, --official       Force use official source
#   -p, --pyocd          Install pyocd for debugging
#   -e, --env-root <path> Set custom install directory
#   -E, --en, --english  Force English messages
#   -Z, --zh, --chinese  Force Chinese messages
#   -P, --python         Force install portable Python (ignore system Python)
#   --packages <repo>[#<branch>]  Specify custom packages repository and branch
#   --env <repo>[#<branch>]  Specify custom env repository and branch
#   --sdk <repo>[#<branch>]  Specify custom sdk repository and branch
#   --skip-long-path     Skip enabling Windows long path support
#   -h, --help           Show this help message
#

# Parameter variables
$autoMode = $false
$helpMode = $false
$cnMode = $false
$officialMode = $false
$pyocdMode = $false
$pythonMode = $false
$enMode = $false
$zhMode = $false
$skipLongPath = $false
$envRootValue = ""
$customPackagesRepo = ""
$customPackagesBranch = ""
$customEnvRepo = ""
$customEnvBranch = ""
$customSdkRepo = ""
$customSdkBranch = ""

# Parse-RepoArg function must be defined before it's used in argument parsing
function Parse-RepoArg {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoArg
    )
    
    # Parse repo and branch (format: repo_url[#branch])
    # Use # as separator to avoid conflicts with URL protocols and SSH ports
    
    if ($RepoArg -match "#") {
        $parts = $RepoArg -split "#", 2
        if ($parts.Count -ne 2) {
            throw "Invalid repository format: $RepoArg"
        }
        if ([string]::IsNullOrWhiteSpace($parts[0])) {
            throw "Repository URL cannot be empty"
        }
        return @{
            Repo   = $parts[0].Trim()
            Branch = $parts[1].Trim()
        }
    }
    else {
        return @{
            Repo   = $RepoArg.Trim()
            Branch = ""
        }
    }
}

# Process all arguments (support both - and -- formats)
foreach ($arg in $args) {
    switch -CaseSensitive ($arg) {
        "-y" { $autoMode = $true }
        "--yes" { $autoMode = $true }
        "--auto" { $autoMode = $true }
        "-h" { $helpMode = $true }
        "--help" { $helpMode = $true }
        "-c" { $cnMode = $true }
        "--cn" { $cnMode = $true }
        "--gitee" { $cnMode = $true }
        "-o" { $officialMode = $true }
        "--official" { $officialMode = $true }
        "-p" { $pyocdMode = $true }
        "--pyocd" { $pyocdMode = $true }
        "-P" { $pythonMode = $true }
        "--python" { $pythonMode = $true }
        "-e" { $enMode = $true }
        "--en" { $enMode = $true }
        "--english" { $enMode = $true }
        "-z" { $zhMode = $true }
        "--zh" { $zhMode = $true }
        "--chinese" { $zhMode = $true }
        "--packages" {
            $idx = $args.IndexOf($arg) + 1
            if ($idx -lt $args.Count) {
                $result = Parse-RepoArg -RepoArg $args[$idx]
                $customPackagesRepo = $result.Repo
                $customPackagesBranch = $result.Branch
            }
        }
        "--env" {
            $idx = $args.IndexOf($arg) + 1
            if ($idx -lt $args.Count) {
                $result = Parse-RepoArg -RepoArg $args[$idx]
                $customEnvRepo = $result.Repo
                $customEnvBranch = $result.Branch
            }
        }
        "--sdk" {
            $idx = $args.IndexOf($arg) + 1
            if ($idx -lt $args.Count) {
                $result = Parse-RepoArg -RepoArg $args[$idx]
                $customSdkRepo = $result.Repo
                $customSdkBranch = $result.Branch
            }
        }
        "-e" {
            # Get next argument as env_root value
            $idx = $args.IndexOf($arg) + 1
            if ($idx -lt $args.Count) {
                $envRootValue = $args[$idx]
            }
        }
        "--env-root" {
            # Get next argument as env_root value
            $idx = $args.IndexOf($arg) + 1
            if ($idx -lt $args.Count) {
                $envRootValue = $args[$idx]
            }
        }
        "--skip-long-path" {
            $skipLongPath = $true
        }
    }
}

# ============================================================================
# Check PowerShell Version
# ============================================================================

$requiredPSVersion = "5.1"
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -lt 5 -or ($psVersion.Major -eq 5 -and $psVersion.Minor -lt 1)) {
    Write-Host "Error: This script requires PowerShell $requiredPSVersion or later." -ForegroundColor Red
    Write-Host "Current version: $($psVersion)" -ForegroundColor Red
    exit 1
}

# ============================================================================
# Configuration
# ============================================================================

# Environment directory (can be overridden by --env-root or $env:ENV_ROOT)
$ENV_DEFAULT_DIR = ".rtenv"
$env:ENV_ROOT = if ($env:ENV_ROOT) { $env:ENV_ROOT } else { "$env:USERPROFILE\$ENV_DEFAULT_DIR" }

# Virtual environment directory name
$Global:VENV_DIR = "venv\rt-env"

# Flag to indicate if config and toolchain should be restored after installation
$Global:RESTORE_CONFIG_AFTER_INSTALL = $false
$Global:TEMP_CONFIG_PATH = ""

# Selected Python path (used during installation and activation)
$Global:SELECTED_PYTHON = ""

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Repository configurations
# GitHub (default)
$REPO_PACKAGES_GITHUB = "https://github.com/RT-Thread/packages.git"
$REPO_ENV_GITHUB = "https://github.com/RT-Thread/env.git"
$REPO_SDK_GITHUB = "https://github.com/RT-Thread/sdk.git"

# Gitee (China mirror)
$REPO_PACKAGES_GITEE = "https://gitee.com/RT-Thread-Mirror/packages.git"
$REPO_ENV_GITEE = "https://gitee.com/RT-Thread-Mirror/env.git"
$REPO_SDK_GITEE = "https://gitee.com/RT-Thread-Mirror/sdk.git"

# PyPI mirror configurations
$PYPI_MIRROR_CN = "https://pypi.tuna.tsinghua.edu.cn/simple"

# IP detection service
$IPINFO_URL = "https://ipinfo.io/json"

# Git download URL (for manual installation message)
$GIT_DOWNLOAD_URL = "https://git-scm.com/download/win"

# ============================================================================
# Argument Parsing
# ============================================================================

# Detect system language as default
function Get-SystemLanguage {
    $locale = [System.Globalization.CultureInfo]::CurrentUICulture.Name
    if ($locale -like "*zh*" -or $locale -like "*CN*") {
        return "zh"
    }
    return "en"
}

$Global:LANG_CURRENT = Get-SystemLanguage
$Global:USE_CN = $false
$Global:USE_CN_SET = $false
$Global:INSTALL_PYOCD = $false
$Global:AUTO_MODE = $false
$Global:NEED_HELP = $false
$Global:USE_EMBED_PYTHON = $false
$Global:CUSTOM_PACKAGES_REPO = ""
$Global:CUSTOM_PACKAGES_BRANCH = ""
$Global:CUSTOM_ENV_REPO = ""
$Global:CUSTOM_ENV_BRANCH = ""
$Global:CUSTOM_SDK_REPO = ""
$Global:CUSTOM_SDK_BRANCH = ""

function Print-Help {
    if ($Global:LANG_CURRENT -eq "zh") {
        Write-Host "RT-Thread ENV 安装程序"
        Write-Host ""
        Write-Host "用法: .\install.ps1 [选项]"
        Write-Host ""
        Write-Host "选项:"
        Write-Host "  -y, --yes, --auto    自动安装，无需提示"
        Write-Host "  -c, --cn, --gitee    使用中国镜像（Gitee，清华 PyPI）"
        Write-Host "  -o, --official       强制使用官方源"
        Write-Host "  -p, --pyocd          安装 pyocd（用于调试）"
        Write-Host "  -e, --env-root <path> 设置自定义安装目录"
        Write-Host "  -E, --en, --english  强制显示英文信息"
        Write-Host "  -Z, --zh, --chinese  强制显示中文信息"
        Write-Host "  -P, --python         强制安装便携式 Python（忽略系统 Python）"
        Write-Host "  --packages <repo>    指定 packages 仓库地址和分支"
        Write-Host "                        格式: url[#branch]"
        Write-Host "  --env <repo>         指定 env 仓库地址和分支"
        Write-Host "                        格式: url[#branch]"
        Write-Host "  --sdk <repo>         指定 sdk 仓库地址和分支"
        Write-Host "                        格式: url[#branch]"
        Write-Host "  --skip-long-path     跳过启用 Windows 长路径支持"
        Write-Host "  -h, --help           显示此帮助信息"
        Write-Host ""
    }
    else {
        Write-Host "RT-Thread ENV Installation Script"
        Write-Host ""
        Write-Host "Usage: .\install.ps1 [OPTIONS]"
        Write-Host ""
        Write-Host "Options:"
        Write-Host "  -y, --yes, --auto    Auto-install without prompts"
        Write-Host "  -c, --cn, --gitee    Use China mirror (Gitee, PyPI TUNA)"
        Write-Host "  -o, --official       Force use official source"
        Write-Host "  -p, --pyocd          Install pyocd for debugging"
        Write-Host "  -e, --env-root <path> Set custom install directory"
        Write-Host "  -E, --en, --english  Force English messages"
        Write-Host "  -Z, --zh, --chinese  Force Chinese messages"
        Write-Host "  -P, --python         Force install portable Python (ignore system Python)"
        Write-Host "  --packages <repo>    Specify custom packages repository and branch"
        Write-Host "                        Format: url[#branch]"
        Write-Host "  --env <repo>         Specify custom env repository and branch"
        Write-Host "                        Format: url[#branch]"
        Write-Host "  --sdk <repo>         Specify custom sdk repository and branch"
        Write-Host "                        Format: url[#branch]"
        Write-Host "  --skip-long-path     Skip enabling Windows long path support"
        Write-Host "  -h, --help           Show this help message"
        Write-Host ""
    }
    exit 0
}

function Detect-China {
    param(
        [bool]$LangEn = $false,
        [bool]$LangZh = $false
    )

    # Check if user is in China (by IP or system locale)
    $use_cn = $false

    # Check IP-based detection (works on all systems)
    try {
        $ip_info = Invoke-RestMethod -Uri $IPINFO_URL -Method Get -UseBasicParsing -TimeoutSec 5
        if ($ip_info.country -eq "CN") {
            $use_cn = $true
        }
    }
    catch {
        # Fallback to timezone
    }

    # Fallback: check system timezone
    if (-not $use_cn) {
        try {
            $timezone = [System.TimeZoneInfo]::Local.Id
            if ($timezone -like "*Shanghai*" -or $timezone -like "*China*" -or $timezone -like "*Beijing*") {
                $use_cn = $true
            }
        }
        catch {
            # Fallback to locale
        }
    }
    return $use_cn
}

# ============================================================================
# Messages
# ============================================================================

# English messages
$MSG_EN_banner_title = "RT-Thread ENV Installation"
$MSG_EN_info = "INFO"
$MSG_EN_success = "SUCCESS"
$MSG_EN_warning = "WARNING"
$MSG_EN_error = "ERROR"
$MSG_EN_checking_python = "Checking Python..."
$MSG_EN_python_found = "Python found: {0}"
$MSG_EN_checking_python_version = "Checking Python version..."
$MSG_EN_python_version = "Python version: {0}"
$MSG_EN_python_version_too_low = "Python version {0} is too old (requires >= 3.6). Installing portable Python..."
$MSG_EN_python_not_found = "Python not found. Installing portable Python..."
$MSG_EN_missing_python = "Python not found. Please install Python first."
$MSG_EN_using_system_python = "Using system Python..."
$MSG_EN_using_portable_python = "Will use portable Python..."
$MSG_EN_installing_portable_python = "Installing portable Python {0}..."
$MSG_EN_downloading_portable_python = "Downloading portable Python..."
$MSG_EN_python_installed = "Python installed successfully."
$MSG_EN_checking_git = "Checking Git..."
$MSG_EN_git_found = "Git found: {0}"
$MSG_EN_installing_pip = "Installing pip..."
$MSG_EN_pip_installed = "pip installed successfully"
$MSG_EN_downloading_git = "Downloading Git..."
$MSG_EN_installing_git = "Installing Git..."
$MSG_EN_git_installed = "Git installed. Please restart terminal and run this script again."
$MSG_EN_admin_required = "Error: The -y/--yes flag requires administrator privileges."
$MSG_EN_run_as_admin = "Please run this script as administrator."
$MSG_EN_fetching_git_from_npmmirror = "Fetching Git version from npmmirror..."
$MSG_EN_fetching_git_from_github = "Fetching Git version from GitHub API..."
$MSG_EN_git_version_found = "Git version found: {0}"
$MSG_EN_npmmirror_fetch_failed = "Failed to fetch Git version from npmmirror, trying GitHub API..."
$MSG_EN_download_failed = "Download failed: {0}"
$MSG_EN_github_api_failed = "GitHub API request failed, using fallback version..."
$MSG_EN_using_fixed_git_version = "Using fixed Git version: {0}"
$MSG_EN_git_clone_failed = "Git clone failed: {0}"
$MSG_EN_restart_required = "Please restart terminal and run this script again to continue."
$MSG_EN_git_not_found = "Git is not installed. Please install Git first."
$MSG_EN_please_install_git = "Please install Git first"
$MSG_EN_install_git_windows = "Windows: Download and install Git from $GIT_DOWNLOAD_URL"
$MSG_EN_enabling_long_paths = "Enabling Windows long path support..."
$MSG_EN_long_paths_enabled = "Windows long path support enabled"
$MSG_EN_long_paths_enable_failed = "Failed to enable long path support (may require admin privileges)"
$MSG_EN_need_admin_privilege = "Enabling long paths requires administrator privileges"
$MSG_EN_elevating_to_enable_long_paths = "Attempting to enable long paths (UAC prompt may appear)"
$MSG_EN_cloning = "Cloning {0} to {1}"
$MSG_EN_cloned = "Cloned {0}"
$MSG_EN_dir_exists = "Directory already exists: {0}"
$MSG_EN_generating_kconfig = "Generating Kconfig: {0}"
$MSG_EN_installing_windows = "Installing dependencies (Windows)..."
$MSG_EN_unsupported_os = "Unsupported OS: {0}"
$MSG_EN_missing_gcc = "Missing GCC compiler, please install manually"
$MSG_EN_installing_packages = "Installing Python packages..."
$MSG_EN_env_root_exists = "RT-Thread ENV directory already exists: {0}"
$MSG_EN_env_root_prompt = "Existing RT-Thread ENV detected. Do you want to delete and reinstall?"
$MSG_EN_env_root_confirm = "Are you sure you want to delete? [Y/a/N]: "
$MSG_EN_env_root_confirm_help = "  Y/y: Preserve config and local_pkgs, delete others (default)"
$MSG_EN_env_root_confirm_all = "  A/a: Delete entire directory (including config and local_pkgs)"
$MSG_EN_env_root_confirm_no = "  N/n: Cancel installation"
$MSG_EN_removing_env_root = "Removing existing RT-Thread ENV: {0}..."
$MSG_EN_removing_env_root_preserving = "Removing (preserving config and local_pkgs): {0}..."
$MSG_EN_removing_env_root_all = "Removing entire directory: {0}..."
$MSG_EN_env_root_removed = "Existing RT-Thread ENV removed: {0}"
$MSG_EN_restoring_config = "Restoring config..."
$MSG_EN_config_restored = "Config restored"
$MSG_EN_installation_cancelled = "Installation cancelled"
$MSG_EN_venv_not_found = "Virtual environment not found, please recreate"
$MSG_EN_upgrading_pip = "Upgrading pip..."
$MSG_EN_pip_install_failed = "pip installation failed"
$MSG_EN_package_install_failed = "Package installation failed, please check network connection or permissions"
$MSG_EN_pyocd_install_prompt = "Do you want to install pyocd (for debugging Cortex-M devices)?"
$MSG_EN_pyocd_install_confirm = "Install pyocd? [Y/n]: "
$MSG_EN_installation_skip_existing = "RT-Thread ENV already exists, skipping installation (use -y to force reinstall)"
$MSG_EN_python_version_failed = "Failed to get Python version information"
$MSG_EN_creating_venv = "Creating virtual environment at: {0}"
$MSG_EN_venv_created = "Virtual environment created"
$MSG_EN_venv_exists = "Virtual environment already exists"
$MSG_EN_venv_exists_confirm = "Virtual environment already exists, do you want to delete and recreate?"
$MSG_EN_skip_venv_creation = "Skipping virtual environment creation"
$MSG_EN_removing_existing_venv = "Removing existing virtual environment..."
$MSG_EN_activating_venv = "Activating virtual environment at: {0}"
$MSG_EN_using_cn_mirror = "Using China mirror"
$MSG_EN_using_official_source = "Using official source"
$MSG_EN_using_github = "Using GitHub"
$MSG_EN_using_pypi_mirror = "Using PyPI mirror: {0}"
$MSG_EN_installed_packages = "Python packages installed successfully"
$MSG_EN_fixed_guiconfig = "Fixed guiconfig.py (added missing import)"
$MSG_EN_pyocd_installed = "Will install pyocd package"
$MSG_EN_pyocd_not_installed = "Skipping pyocd installation"
$MSG_EN_copied_env_script = "Copied env.ps1: {0}"
$MSG_EN_setup_complete = "RT-Thread ENV installation completed!"
$MSG_EN_next_steps = "Next steps:"
$MSG_EN_activate_env = "1. Activate environment:"
$MSG_EN_activate_cmd = "   > . {0}\env.ps1"
$MSG_EN_add_to_profile = "2. Add to profile:"
$MSG_EN_add_profile_cmd = "   > echo '. {0}\env.ps1' >> \$PROFILE"
$MSG_EN_reload_profile = "   > . \$PROFILE"
$MSG_EN_install_toolchain = "3. Install toolchains:"
$MSG_EN_install_toolchain_cmd = "   Run 'sdk' command to install required toolchains"
$MSG_EN_after_activation = "4. After activation, you can use:"
$MSG_EN_menuconfig = "     - menuconfig    : Configure RT-Thread"
$MSG_EN_pkgs = "     - pkgs          : Package manager"
$MSG_EN_scons = "     - scons         : Build RT-Thread"
$MSG_EN_sdk = "     - sdk           : Install toolchains"
$MSG_EN_using_custom_repo = "Using custom repository: {0}"
$MSG_EN_using_custom_branch = "Using branch: {0}"
$MSG_EN_using_custom_repo_branch = "Using custom repository: {0} (branch: {1})"
$MSG_EN_multiple_python_found = "Multiple Python installations found:"
$MSG_EN_select_python = "Select Python installation (1-{0}) [default: {1}]: "
$MSG_EN_auto_selected = "Auto-selected: {0} (latest version)"

# Chinese messages
$MSG_ZH_banner_title = "RT-Thread ENV 安装程序"
$MSG_ZH_info = "信息"
$MSG_ZH_success = "成功"
$MSG_ZH_warning = "警告"
$MSG_ZH_error = "错误"
$MSG_ZH_checking_python = "正在检查 Python..."
$MSG_ZH_python_found = "找到 Python: {0}"
$MSG_ZH_checking_python_version = "正在检查 Python 版本..."
$MSG_ZH_python_version = "Python 版本: {0}"
$MSG_ZH_python_version_too_low = "Python 版本 {0} 过低（需要 >= 3.6）。将安装便携式 Python..."
$MSG_ZH_python_not_found = "未安装 Python。将安装便携式 Python。"
$MSG_ZH_missing_python = "未安装 Python。请先安装 Python。"
$MSG_ZH_using_system_python = "使用系统 Python..."
$MSG_ZH_using_portable_python = "将使用便携式 Python..."
$MSG_ZH_installing_portable_python = "正在安装便携式 Python {0}..."
$MSG_ZH_downloading_portable_python = "正在下载便携式 Python..."
$MSG_ZH_python_installed = "Python 已安装成功。"
$MSG_ZH_checking_git = "正在检查 Git..."
$MSG_ZH_git_found = "找到 Git: {0}"
$MSG_ZH_git_not_found = "未安装 Git。将安装 Git v2.52.0.windows.1。"
$MSG_ZH_installing_pip = "正在安装 pip..."
$MSG_ZH_pip_installed = "pip 安装成功"
$MSG_ZH_pip_install_failed = "pip 安装失败"
$MSG_ZH_downloading_git = "正在下载 Git..."
$MSG_ZH_installing_git = "正在安装 Git..."
$MSG_ZH_git_installed = "Git 已安装。请重新启动终端并再次运行此脚本。"
$MSG_ZH_admin_required = "错误: -y/--yes 参数需要管理员权限。"
$MSG_ZH_run_as_admin = "请以管理员身份运行此脚本。"
$MSG_ZH_fetching_git_from_npmmirror = "正在从 npmmirror 获取 Git 版本..."
$MSG_ZH_fetching_git_from_github = "正在从 GitHub API 获取 Git 版本..."
$MSG_ZH_git_version_found = "找到 Git 版本: {0}"
$MSG_ZH_npmmirror_fetch_failed = "从 npmmirror 获取 Git 版本失败，尝试 GitHub API..."
$MSG_ZH_download_failed = "下载失败: {0}"
$MSG_ZH_github_api_failed = "GitHub API 请求失败，使用备选版本..."
$MSG_ZH_using_fixed_git_version = "使用固定 Git 版本: {0}"
$MSG_ZH_git_clone_failed = "Git 克隆失败: {0}"
$MSG_ZH_restart_required = "请重新启动终端并再次运行此脚本以继续。"
$MSG_ZH_git_not_found = "未安装 Git。请先安装 Git。"
$MSG_ZH_please_install_git = "请先安装 Git"
$MSG_ZH_install_git_windows = "Windows: 从 $GIT_DOWNLOAD_URL 下载并安装 Git"
$MSG_ZH_enabling_long_paths = "正在启用 Windows 长路径支持..."
$MSG_ZH_long_paths_enabled = "Windows 长路径支持已启用"
$MSG_ZH_long_paths_enable_failed = "启用长路径支持失败（可能需要管理员权限）"
$MSG_ZH_need_admin_privilege = "启用长路径需要管理员权限"
$MSG_ZH_elevating_to_enable_long_paths = "正在尝试启用长路径（可能会弹出 UAC 提示）"
$MSG_ZH_cloning = "正在克隆: {0} 到 {1}"
$MSG_ZH_cloned = "已克隆: {0}"
$MSG_ZH_dir_exists = "目录已存在: {0}"
$MSG_ZH_generating_kconfig = "生成 Kconfig: {0}"
$MSG_ZH_installing_windows = "正在安装依赖 (Windows)..."
$MSG_ZH_unsupported_os = "不支持的操作系统: {0}"
$MSG_ZH_missing_gcc = "缺少 GCC 编译器，请手动安装"
$MSG_ZH_installing_packages = "正在安装 Python 包..."
$MSG_ZH_env_root_exists = "RT-Thread ENV 目录已存在: {0}"
$MSG_ZH_env_root_prompt = "检测到已存在的RT-Thread ENV。是否要删除并重新安装？"
$MSG_ZH_env_root_confirm = "确定要删除吗？[Y/a/N]: "
$MSG_ZH_env_root_confirm_help = "  Y/y: 保留配置和 local_pkgs，删除其他（默认）"
$MSG_ZH_env_root_confirm_all = "  A/a: 删除整个目录（包括配置和 local_pkgs）"
$MSG_ZH_env_root_confirm_no = "  N/n: 取消安装"
$MSG_ZH_removing_env_root = "正在删除现有RT-Thread ENV: {0}..."
$MSG_ZH_removing_env_root_preserving = "正在删除（保留配置和 local_pkgs）: {0}..."
$MSG_ZH_removing_env_root_all = "正在删除整个目录: {0}..."
$MSG_ZH_env_root_removed = "已删除 RT-Thread ENV: {0}"
$MSG_ZH_restoring_config = "正在恢复配置..."
$MSG_ZH_config_restored = "配置已恢复"
$MSG_ZH_installation_cancelled = "安装已取消"
$MSG_ZH_venv_not_found = "找不到虚拟环境，请重新创建"
$MSG_ZH_upgrading_pip = "正在升级 pip..."
$MSG_ZH_package_install_failed = "包安装失败，请检查网络连接或权限"
$MSG_ZH_installing_pyocd = "正在安装 pyocd..."
$MSG_ZH_pyocd_install_prompt = "是否要安装 pyocd (用于调试 Cortex-M 设备)？"
$MSG_ZH_pyocd_install_confirm = "安装 pyocd？[Y/n]: "
$MSG_ZH_installation_skip_existing = "RT-Thread ENV 已存在，跳过安装（使用 -y 参数强制重新安装）"
$MSG_ZH_python_version_failed = "无法获取 Python 版本信息"
$MSG_ZH_creating_venv = "正在创建虚拟环境: {0}"
$MSG_ZH_venv_created = "虚拟环境创建完成"
$MSG_ZH_venv_exists = "虚拟环境已存在"
$MSG_ZH_venv_exists_confirm = "虚拟环境已存在，是否删除并重新创建？"
$MSG_ZH_skip_venv_creation = "跳过虚拟环境创建"
$MSG_ZH_removing_existing_venv = "正在删除现有虚拟环境..."
$MSG_ZH_activating_venv = "正在激活虚拟环境: {0}"
$MSG_ZH_using_cn_mirror = "使用中国镜像源"
$MSG_ZH_using_official_source = "使用官方源"
$MSG_ZH_using_github = "使用 GitHub 源"
$MSG_ZH_using_pypi_mirror = "使用 PyPI 镜像: {0}"
$MSG_ZH_installed_packages = "Python 包安装完成"
$MSG_ZH_fixed_guiconfig = "已修复 guiconfig.py（添加缺失的导入）"
$MSG_ZH_pyocd_installed = "将安装 pyocd 包"
$MSG_ZH_pyocd_not_installed = "跳过 pyocd 安装"
$MSG_ZH_copied_env_script = "已复制 env.ps1: {0}"
$MSG_ZH_multiple_python_found = "发现多个 Python 安装:"
$MSG_ZH_select_python = "选择 Python 安装 (1-{0}) [默认: {1}]: "
$MSG_ZH_auto_selected = "自动选择: {0} (最新版本)"

$MSG_ZH_setup_complete = "RT-Thread ENV 安装完成！"
$MSG_ZH_next_steps = "后续步骤:"
$MSG_ZH_activate_env = "1. 激活环境:"
$MSG_ZH_activate_cmd = "   > . {0}\env.ps1"
$MSG_ZH_add_to_profile = "2. 添加到配置文件:"
$MSG_ZH_add_profile_cmd = "   > echo '. {0}\env.ps1' >> \$PROFILE"
$MSG_ZH_reload_profile = "   > . \$PROFILE"
$MSG_ZH_install_toolchain = "3. 安装工具链:"
$MSG_ZH_install_toolchain_cmd = "   运行 sdk 命令安装所需的工具链"
$MSG_ZH_after_activation = "4. 激活后可用命令:"
$MSG_ZH_menuconfig = "     - menuconfig    : 配置 RT-Thread"
$MSG_ZH_pkgs = "     - pkgs          : 包管理器"
$MSG_ZH_scons = "     - scons         : 编译 RT-Thread"
$MSG_ZH_sdk = "     - sdk           : 安装工具链"
$MSG_ZH_using_custom_repo = "使用自定义仓库: {0}"
$MSG_ZH_using_custom_branch = "使用分支: {0}"
$MSG_ZH_using_custom_repo_branch = "使用自定义仓库: {0} (分支: {1})"

# Message retrieval function
function Get-Message {
    param([string]$Key)

    $varName = "MSG_${Global:LANG_CURRENT}_${Key}"
    $value = (Get-Variable -Name $varName -ValueOnly -ErrorAction SilentlyContinue)

    if ($null -eq $value) {
        return "Unknown message: $Key"
    }

    return $value
}

function Write-LogInfo {
    param([string]$Key, [string]$Arg1, [string]$Arg2)
    $msg = Get-Message $Key
    $formatted = $msg
    if ($null -ne $Arg1) {
        $formatted = $formatted -replace '\{0\}', $Arg1
    }
    if ($null -ne $Arg2) {
        $formatted = $formatted -replace '\{1\}', $Arg2
    }
    Write-Host "[$(Get-Message 'info')] $formatted" -ForegroundColor Cyan
}

function Write-LogSuccess {
    param([string]$Key, [string]$Arg1, [string]$Arg2)
    $msg = Get-Message $Key
    $formatted = $msg
    if ($null -ne $Arg1) {
        $formatted = $formatted -replace '\{0\}', $Arg1
    }
    if ($null -ne $Arg2) {
        $formatted = $formatted -replace '\{1\}', $Arg2
    }
    Write-Host "[$(Get-Message 'success')] $formatted" -ForegroundColor Green
}

function Write-LogWarning {
    param([string]$Key, [string]$Arg1, [string]$Arg2)
    $msg = Get-Message $Key
    $formatted = $msg
    if ($null -ne $Arg1) {
        $formatted = $formatted -replace '\{0\}', $Arg1
    }
    if ($null -ne $Arg2) {
        $formatted = $formatted -replace '\{1\}', $Arg2
    }
    Write-Host "[$(Get-Message 'warning')] $formatted" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Key, [string]$Arg1, [string]$Arg2)
    $msg = Get-Message $Key
    $formatted = $msg
    if ($null -ne $Arg1) {
        $formatted = $formatted -replace '\{0\}', $Arg1
    }
    if ($null -ne $Arg2) {
        $formatted = $formatted -replace '\{1\}', $Arg2
    }
    Write-Host "[$(Get-Message 'error')] $formatted" -ForegroundColor Red
}

# ============================================================================
# Git and Repository Functions
# ============================================================================

function Test-Command {
    param([string]$CommandName)

    try {
        Get-Command $CommandName -ErrorAction Stop | Out-Null
        return $true
    }
    catch {
        return $false
    }
}

function Clone-Repository {
    param([string]$Url, [string]$Destination, [int]$Depth = 1, [string]$Branch = "")

    if (-not (Test-Path -Path $Destination)) {
        Write-LogInfo "cloning" $Url $Destination
        
        $cloneArgs = @("clone", "--depth", $Depth)
        if ($Branch) {
            $cloneArgs += @("--branch", $Branch)
        }
        $cloneArgs += @($Url, $Destination)
        
        $process = Start-Process -FilePath "git" -ArgumentList $cloneArgs -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-LogError "git_clone_failed" "Exit code: $($process.ExitCode)"
            exit 1
        }
        Write-LogSuccess "cloned" $Destination
    }
    else {
        Write-LogSuccess "dir_exists" $Destination
    }
}

function Generate-KconfigFile {
    param([string]$EnvRoot)

    $kconfigPath = Join-Path $EnvRoot "packages\Kconfig"

    $content = 'source "$PKGS_DIR/packages/Kconfig"' + "`n"
    Set-Content -Path $kconfigPath -Value $content

    # Create local_pkgs directory for local package storage
    $localPkgsPath = Join-Path $EnvRoot "local_pkgs"
    if (-not (Test-Path $localPkgsPath)) {
        New-Item -ItemType Directory -Path $localPkgsPath -Force | Out-Null
    }

    Write-LogSuccess "generating_kconfig" $kconfigPath
}

# ============================================================================
# Git Installation (Windows-specific)
# ============================================================================

function Get-LatestGitVersion {
    param([bool]$UseCNMirror)

    # For CN users, try npmmirror first
    if ($UseCNMirror) {
        try {
            Write-LogInfo "fetching_git_from_npmmirror"
            $response = Invoke-RestMethod -Uri $GIT_NPMMIRROR_URL -Method Get -UseBasicParsing

            # Parse versions from response (JSON array)
            $versions = $response

            # Filter out rc, prerelease, mingit versions
            $filteredVersions = $versions | Where-Object {
                $_.name -notmatch "-rc[0-9]" -and
                $_.name -notmatch "-prerelease$" -and
                $_.name -notmatch "-mingit$"
            }

            if ($filteredVersions.Count -gt 0) {
                # Sort versions by name (descending)
                $sortedVersions = $filteredVersions | Sort-Object -Property Name -Descending

                $latest = $sortedVersions[0]
                $versionNumber = $latest.name -replace '/$', ''

                # Query the specific version directory to get file list
                $versionUrl = "$GIT_NPMMIRROR_URL$versionNumber/"
                $versionResponse = Invoke-RestMethod -Uri $versionUrl -Method Get -UseBasicParsing

                # Find the 64-bit installer (Git-X.X.X-64-bit.exe)
                $installerFile = $versionResponse | Where-Object {
                    $_.name -match "^Git-\d+\.\d+\.\d+-64-bit\.exe$"
                }

                if ($installerFile) {
                    Write-LogSuccess "git_version_found" "$versionNumber (from npmmirror)"
                    return @{
                        Version   = $versionNumber
                        Installer = $installerFile.name
                        Url       = $installerFile.url
                        Source    = "npmmirror"
                    }
                }
            }
        }
        catch {
            Write-LogWarning "npmmirror_fetch_failed"
        }
    }

    # Fallback to GitHub API (for non-CN users or if npmmirror fails)
    try {
        Write-LogInfo "fetching_git_from_github"
        $response = Invoke-RestMethod -Uri $GIT_GITHUB_API_URL -Method Get -UseBasicParsing -ErrorAction Stop

        # Check if response is valid JSON (not HTML page)
        if ($response -is [string]) {
            throw "Received HTML instead of JSON"
        }

        $tagName = $response.tag_name
        $versionNumber = $tagName -replace '^v', ''

        # Find the 64-bit installer
        # Note: The installer filename uses version number without the ".windows.1" suffix
        # e.g., "Git-2.52.0-64-bit.exe" not "Git-v2.52.0.windows.1-64-bit.exe"
        $installerAsset = $response.assets | Where-Object {
            $_.name -match "^Git-\d+\.\d+\.\d+-64-bit\.exe$"
        }

        if ($installerAsset) {
            Write-LogSuccess "git_version_found" "$versionNumber (from GitHub)"
            return @{
                Version   = $versionNumber
                Installer = $installerAsset.name
                Url       = $installerAsset.browser_download_url
                Source    = "github"
            }
        }
    }
    catch {
        Write-LogWarning "github_api_failed"
    }

    # Ultimate fallback: use fixed version
    Write-LogWarning "using_fixed_git_version" "$GIT_FALLBACK_VERSION"
    return @{
        Version   = $GIT_FALLBACK_VERSION
        Installer = "Git-$GIT_FALLBACK_VERSION-64-bit.exe"
        Url       = $GIT_FALLBACK_URL
        Source    = "fallback"
    }
}

function Install-Git {
    param(
        [bool]$UseCNMirror,
        [bool]$Interactive = $false
    )

    # Get latest Git version dynamically
    $gitInfo = Get-LatestGitVersion -UseCNMirror $UseCNMirror

    Write-LogInfo "downloading_git"

    $installerPath = Join-Path $env:TEMP $gitInfo.Installer
    $gitUrl = $gitInfo.Url

    # Download Git installer
    Invoke-WebRequest -Uri $gitUrl -OutFile $installerPath -UseBasicParsing

    Write-LogInfo "installing_git"

    if ($Interactive) {
        # Interactive installation - show installer UI with default options
        Start-Process -FilePath $installerPath -Wait
    }
    else {
        # Silent installation with progress display
        # /SILENT: Silent installation with progress bar
        # /SUPPRESSMSGBOXES: Suppress message boxes
        # /NORESTART: Prevent restart
        # /COMPONENTS="": Install all components
        # /TASKS="desktopicon,winterminal": Add desktop icon and Windows Terminal profile
        # /MERGETASKS="desktopicon,winterminal": Additional tasks to merge
        # /DEFAULTBRANCH="main": Set default branch name to main
        Start-Process -FilePath $installerPath -ArgumentList @(
            "/SILENT",
            "/SUPPRESSMSGBOXES",
            "/NORESTART",
            "/COMPONENTS=",
            '/TASKS="desktopicon,winterminal"',
            "/DEFAULTBRANCH=main"
        ) -Wait
    }

    # Cleanup
    Remove-Item $installerPath -ErrorAction SilentlyContinue

    Write-LogSuccess "git_installed"
}

# ============================================================================
# Python Installation (Windows-specific)
# ============================================================================

$PYTHON_VERSION = "3.13.11"
$PYTHON_ARCHIVE = "python-3.13.11-amd64.zip"
# Python download URLs
$PYTHON_URL_DEFAULT = "https://www.python.org/ftp/python/$PYTHON_VERSION/$PYTHON_ARCHIVE"
$PYTHON_URL_CN = "https://registry.npmmirror.com/-/binary/python/$PYTHON_VERSION/$PYTHON_ARCHIVE"

# Git download URLs
$GIT_NPMMIRROR_URL = "https://registry.npmmirror.com/-/binary/git-for-windows/"
$GIT_GITHUB_API_URL = "https://api.github.com/repos/git-for-windows/git/releases/latest"
$GIT_FALLBACK_VERSION = "v2.52.0.windows.1"
$GIT_FALLBACK_URL = "https://github.com/git-for-windows/git/releases/download/v2.52.0.windows.1/Git-v2.52.0.windows.1-64-bit.exe"

function Install-Python {
    param([bool]$UseCNMirror)

    Download-PortablePython -UseCNMirror $UseCNMirror
    Extract-PortablePython
    if (-not $skipLongPath) {
        Enable-LongPathSupport
    }
    Configure-PythonPth
    Install-Pip -UseCNMirror $UseCNMirror

    # Save portable Python path to global variable
    $portablePython = Join-Path $env:ENV_ROOT "python\python.exe"
 
    Write-LogSuccess "python_installed"
    return $portablePython
}

function Download-PortablePython {
    param([bool]$UseCNMirror)

    Write-LogInfo "downloading_portable_python"
    $archivePath = Join-Path $env:TEMP $PYTHON_ARCHIVE

    # Determine download URL based on mirror setting
    $pythonUrl = if ($UseCNMirror) { $PYTHON_URL_CN } else { $PYTHON_URL_DEFAULT }

    # Download Python embed archive
    try {
        Invoke-WebRequest -Uri $pythonUrl -OutFile $archivePath -UseBasicParsing -ErrorAction Stop
    }
    catch {
        Write-LogError "download_failed" $_.Exception.Message
        exit 1
    }
    
    # Verify file was downloaded successfully
    if (-not (Test-Path $archivePath) -or (Get-Item $archivePath).Length -eq 0) {
        Write-LogError "download_failed" "File not found or empty"
        exit 1
    }
}

function Extract-PortablePython {
    Write-LogInfo "installing_portable_python" $PYTHON_VERSION

    $archivePath = Join-Path $env:TEMP $PYTHON_ARCHIVE
    $pythonTargetDir = "$env:ENV_ROOT\python"
    
    if (Test-Path $pythonTargetDir) {
        Remove-Item -Path $pythonTargetDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $pythonTargetDir -Force | Out-Null

    # Extract zip file, excluding Doc directory
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    Add-Type -AssemblyName System.IO.Compression
    $zip = [System.IO.Compression.ZipFile]::OpenRead($archivePath)
    try {
        foreach ($entry in $zip.Entries) {
            if ($entry.FullName -like 'Doc/*' -or $entry.FullName -eq 'Doc') { continue }
            $entryPath = Join-Path $pythonTargetDir $entry.FullName
            if ($entry.Name -eq '') {
                # Directory entry
                New-Item -ItemType Directory -Path $entryPath -Force | Out-Null
            }
            else {
                $entryDir = Split-Path $entryPath -Parent
                if (-not (Test-Path $entryDir)) {
                    New-Item -ItemType Directory -Path $entryDir -Force | Out-Null
                }
                # Use .NET 4.5+ method to extract file
                $stream = [System.IO.File]::Create($entryPath)
                try {
                    $entryStream = $entry.Open()
                    try {
                        $entryStream.CopyTo($stream)
                    }
                    finally {
                        $entryStream.Dispose()
                    }
                }
                finally {
                    $stream.Dispose()
                }
            }
        }
    }
    finally {
        $zip.Dispose()
    }

    # Cleanup archive
    Remove-Item $archivePath -ErrorAction SilentlyContinue
}

function Enable-LongPathSupport {
    # Enable Windows long path support (260 character limit)
    # This requires administrator privileges
    try {
        $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem"
        $registryKey = "LongPathsEnabled"
        $currentValue = (Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue).$registryKey

        if ($currentValue -eq 1) {
            # Long paths already enabled
            Write-LogSuccess "long_paths_enabled"
            return
        }

        # Check if running as administrator
        $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
        
        if (-not $isAdmin) {
            Write-LogWarning "need_admin_privilege"
            # Create a temporary script to enable long paths
            $tempScript = [System.IO.Path]::GetTempFileName() + ".ps1"
            @"
# Enable long paths in registry
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Type DWord -Force
    Write-Host "Long paths enabled successfully"
}
catch {
    Write-Host "Failed to enable long paths: `$`_"
    exit 1
}
"@ | Out-File -FilePath $tempScript -Encoding UTF8
            
            # Start new process with administrator privileges to run the temp script
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = "powershell.exe"
            $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$tempScript`""
            $psi.Verb = "RunAs"
            $psi.UseShellExecute = $true
            try {
                $process = [System.Diagnostics.Process]::Start($psi)
                Write-LogInfo "elevating_to_enable_long_paths"
                
                # Wait for the process to complete
                $process.WaitForExit()
                $exitCode = $process.ExitCode
                
                # Check if long paths were enabled based on exit code
                if ($exitCode -eq 0) {
                    Write-LogSuccess "long_paths_enabled"
                }
                else {
                    Write-LogWarning "long_paths_enable_failed"
                }
            }
            catch {
                Write-LogWarning "long_paths_enable_failed"
            }
            finally {
                # Clean up temporary script
                if (Test-Path $tempScript) {
                    Remove-Item $tempScript -ErrorAction SilentlyContinue
                }
            }
        }
        else {
            Write-LogInfo "enabling_long_paths"
            Set-ItemProperty -Path $registryPath -Name $registryKey -Value 1 -Type DWord -Force
            Write-LogSuccess "long_paths_enabled"
        }
    }
    catch {
        Write-LogWarning "long_paths_enable_failed"
    }
}

function Configure-PythonPth {
    # Modify python3xx._pth to enable site-packages and ensurepip
    $pythonTargetDir = "$env:ENV_ROOT\python"
    try {
        $pthFile = Get-ChildItem -Path $pythonTargetDir -Filter "*._pth" -ErrorAction Stop
        if ($pthFile) {
            $pthContent = Get-Content -Path $pthFile.FullName -Raw -ErrorAction Stop
            # Uncomment import site to enable site-packages
            $pthContent = $pthContent -replace "#import site", "import site"
            Set-Content -Path $pthFile.FullName -Value $pthContent -NoNewline -ErrorAction Stop
        }
    }
    catch {
        Write-LogWarning "pip_install_failed"
    }
}

function Install-Pip {
    param([bool]$UseCNMirror)

    $pythonTargetDir = "$env:ENV_ROOT\python"
    $pythonExe = Join-Path $pythonTargetDir "python.exe"
    
    if (Test-Path $pythonExe) {
        Write-LogInfo "installing_pip"
        
        # Use ensurepip to install pip
        $process = Start-Process -FilePath $pythonExe -ArgumentList "-m", "ensurepip", "--upgrade" -NoNewWindow -Wait -PassThru
        if ($process.ExitCode -ne 0) {
            Write-LogError "pip_install_failed"
            exit 1
        }
        
        Write-LogSuccess "pip_installed"
    }
}

# ============================================================================
# Python Environment Setup
# ============================================================================

function Find-SystemPython {
    # Find Python in common installation paths first, then system PATH
    # Returns: array of python paths, empty array if not found

    $userProfile = $env:USERPROFILE
    $localAppData = $env:LOCALAPPDATA
    $programFiles = $env:ProgramFiles
    $programFilesX86 = ${env:ProgramFiles(x86)}
    $drives = Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root
    $foundPaths = @()

    $searchPaths = @()
    $searchPaths += "$localAppData\Programs\Python\python.exe"
    $searchPaths += "$localAppData\Programs\Python\Python*\python.exe"
    $searchPaths += "$programFiles\Python\python.exe"
    $searchPaths += "$programFilesX86\Python\python.exe"
    $searchPaths += "$programFiles\Python\Python*\python.exe"
    $searchPaths += "$programFilesX86\Python\Python*\python.exe"
    $searchPaths += "$localAppData\Microsoft\WindowsApps\python.exe"
    $searchPaths += "$userProfile\Anaconda3\python.exe"
    $searchPaths += "$userProfile\Miniconda3\python.exe"
    $searchPaths += "$userProfile\conda\python.exe"

    foreach ($drive in $drives) {
        $searchPaths += "$drive\Python*\python.exe"
        $searchPaths += "$drive\Anaconda3\python.exe"
        $searchPaths += "$drive\Miniconda3\python.exe"
    }

    # Collect all valid Python paths
    foreach ($pythonPath in $searchPaths) {
        # Handle wildcard paths
        if ($pythonPath -like '*\*') {
            try {
                $resolvedPaths = Resolve-Path -Path $pythonPath -ErrorAction SilentlyContinue
                if ($resolvedPaths) {
                    foreach ($resolvedPath in $resolvedPaths) {
                        try {
                            $version = & $resolvedPath.Path --version 2>&1 | Select-String "Python"
                            if ($?) {
                                $foundPaths += $resolvedPath.Path
                            }
                        }
                        catch {
                            continue
                        }
                    }
                }
            }
            catch {
                continue
            }
        }
        elseif (Test-Path $pythonPath) {
            try {
                $version = & $pythonPath --version 2>&1 | Select-String "Python"
                if ($?) {
                    $foundPaths += $pythonPath
                }
            }
            catch {
                continue
            }
        }
    }

    # Also check system PATH
    foreach ($cmd in @("python", "python3", "py")) {
        try {
            $version = & $cmd --version 2>&1 | Select-String "Python"
            if ($?) {
                $foundPaths += $cmd
            }
        }
        catch {
            continue
        }
    }

    # Remove duplicates and ensure array
    $uniquePaths = @()
    if ($foundPaths.Count -gt 0) {
        $uniquePaths = @($foundPaths | Get-Unique | Where-Object { $_ })
    }

    return $uniquePaths
}

function Select-PythonInstallation {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$PythonPaths
    )

    $selectedPython = $null

    if ($PythonPaths.Count -eq 0) {
        return $null
    }
    elseif ($PythonPaths.Count -eq 1) {
        $selectedPython = $PythonPaths[0]
    }
    else {
        # Multiple Python found
        Write-Host ""
        $msgKey = "multiple_python_found"
        Write-LogInfo $msgKey
        for ($i = 0; $i -lt $PythonPaths.Count; $i++) {
            $ver = & $PythonPaths[$i] --version 2>&1 | Select-String "Python"
            Write-Host "  $($i + 1)). $($PythonPaths[$i]) - $($ver.Line)"
        }
        Write-Host ""

        # In auto mode, automatically select the latest version
        if ($Global:AUTO_MODE) {
            # Find the latest version by comparing version strings
            $latestPython = $null
            $latestVersion = [version]"0.0.0"
            $latestIndex = 0

            for ($i = 0; $i -lt $PythonPaths.Count; $i++) {
                $verString = & $PythonPaths[$i] --version 2>&1 | Select-String "Python"
                $verString = $verString.Line -replace 'Python ', ''
                try {
                    $currentVersion = [version]$verString
                    if ($currentVersion -gt $latestVersion) {
                        $latestVersion = $currentVersion
                        $latestPython = $PythonPaths[$i]
                        $latestIndex = $i
                    }
                }
                catch {
                    # If version parsing fails, use this Python if we haven't found one yet
                    if (-not $latestPython) {
                        $latestPython = $PythonPaths[$i]
                        $latestIndex = $i
                    }
                    continue
                }
            }

            # Fallback: if no Python was selected (all version parsing failed), use the first one
            if (-not $latestPython) {
                $latestPython = $PythonPaths[0]
                $latestIndex = 0
            }

            $msgKey = "auto_selected"
            $msg = Get-Message $msgKey
            $formatted = $msg -f $latestPython
            Write-Host $formatted -ForegroundColor Yellow
            $selectedPython = $latestPython
        }
        else {
            # Interactive mode, let user choose
            # Find the latest version to use as default
            $latestPython = $null
            $latestVersion = [version]"0.0.0"
            $latestIndex = 0

            for ($i = 0; $i -lt $PythonPaths.Count; $i++) {
                $verString = & $PythonPaths[$i] --version 2>&1 | Select-String "Python"
                $verString = $verString.Line -replace 'Python ', ''
                try {
                    $currentVersion = [version]$verString
                    if ($currentVersion -gt $latestVersion) {
                        $latestVersion = $currentVersion
                        $latestPython = $PythonPaths[$i]
                        $latestIndex = $i
                    }
                }
                catch {
                    continue
                }
            }

            $msgKey = "select_python"
            $msg = Get-Message $msgKey
            $formatted = $msg -f $PythonPaths.Count, ($latestIndex + 1)
            Write-Host $formatted -NoNewline -ForegroundColor Yellow
            $choice = Read-Host

            if ([string]::IsNullOrEmpty($choice)) {
                # Use default (latest)
                $selectedPython = $PythonPaths[$latestIndex]
            }
            else {
                $idx = [int]$choice - 1
                if ($idx -ge 0 -and $idx -lt $PythonPaths.Count) {
                    $selectedPython = $PythonPaths[$idx]
                }
                else {
                    $selectedPython = $PythonPaths[$latestIndex]
                }
            }
        }
    }

    return $selectedPython
}

function Get-PythonVersionString {
    param([Parameter(Mandatory = $true)][string]$PythonPath)
    # Get Python version string
    # Returns: version string like "3.12.10", $null if not found

    try {
        $version = & $PythonPath --version 2>&1 | Select-String "Python"
        if ($?) {
            return $version.Line -replace 'Python ', ''
        }
    }
    catch {
        return $null
    }
    return $null
}

function Test-PythonVersion {
    param([Parameter(Mandatory = $true)][string]$VersionString)
    # Test if Python version >= 3.6
    # Returns: $true if >= 3.6, $false if < 3.6 or invalid

    $versionParts = $VersionString -split '[ .]'
    if ($versionParts.Count -ge 2) {
        $major = [int]$versionParts[0]
        $minor = [int]$versionParts[1]
        if ($major -gt 3 -or ($major -eq 3 -and $minor -ge 6)) {
            return $true
        }
    }
    return $false
}

function Create-Venv {
    $pythonCmd = $Global:SELECTED_PYTHON 
    if (-not $pythonCmd) {
        Write-LogError "missing_python"
        exit 1
    }

    $venvPath = Join-Path $env:ENV_ROOT $Global:VENV_DIR
    $shouldCreate = $false

    # Check if venv exists
    if (Test-Path $venvPath) {
        if ($Global:AUTO_MODE) {
            Write-LogInfo "skip_venv_creation"
            return
        }
        else {
            $response = Read-Host "$(Get-Message 'venv_exists_confirm') (y/n)"
            if ($response -ne 'y' -and $response -ne 'Y') {
                Write-LogInfo "skip_venv_creation"
                return
            }
            Write-LogInfo "removing_existing_venv"
            Remove-Item -Path $venvPath -Recurse -Force
            $shouldCreate = $true
        }
    }
    else {
        $shouldCreate = $true
    }

    if ($shouldCreate) {
        Write-LogInfo "creating_venv" $venvPath
        & $pythonCmd -m venv $venvPath

        # Check if venv was created successfully
        if (Test-Path (Join-Path $venvPath "Scripts\python.exe")) {
            Write-LogSuccess "venv_created"
        }
        else {
            Write-LogError "venv_not_found"
            exit 1
        }
    }
}

function Install-PythonPackages {
    param([bool]$UseCNMirror, [string]$ScriptsDir, [bool]$InstallPyocd)

    $venvPath = Join-Path $env:ENV_ROOT $Global:VENV_DIR
    Write-LogInfo "activating_venv" $venvPath
    $activateScript = Join-Path $venvPath "Scripts\Activate.ps1"
    $venvPython = Join-Path $venvPath "Scripts\python.exe"

    if (-not (Test-Path $venvPython)) {
        Write-LogError "venv_not_found"
        exit 1
    }

    # Build common pip arguments
    $pipArgs = @()
    if ($UseCNMirror) {
        Write-LogInfo "using_cn_mirror"
        Write-LogInfo "using_pypi_mirror" $PYPI_MIRROR_CN
        $pipArgs += @("--index-url", $PYPI_MIRROR_CN)
    }

    # Upgrade pip using virtual environment's Python
    Write-LogInfo "upgrading_pip"
    & $venvPython -m pip install @pipArgs --upgrade pip
    if ($LASTEXITCODE -ne 0) {
        Write-LogError "pip_install_failed"
        exit 1
    }

    # Install packages and pyocd (if requested)
    $pipArgs += @("-e", $ScriptsDir)
    if ($InstallPyocd) {
        Write-LogInfo "pyocd_installed"
        $pipArgs += @("pyocd")
    }
    else {
        Write-LogInfo "pyocd_not_installed"
    }

    # Install all packages in one command
    & $venvPython -m pip install @pipArgs
    if ($LASTEXITCODE -eq 0) {
        Write-LogSuccess "installed_packages"

        # Fix guiconfig.py missing 'import re'
        $guiconfigPath = Join-Path $venvPath "Lib\site-packages\guiconfig.py"
        if (Test-Path $guiconfigPath) {
            $content = Get-Content -Path $guiconfigPath -Raw
            if (-not ($content -match "^import re")) {
                # Add 'import re' after 'import sys'
                $content = $content -replace "(?m)(^import sys)", "`$1`nimport re"
                Set-Content -Path $guiconfigPath -Value $content -NoNewline
                Write-LogInfo "fixed_guiconfig"
            }
        }
    }
    else {
        Write-LogError "package_install_failed"
        exit 1
    }
}

function Restore-PreservedConfig {
    # Restore preserved configuration files after installation
    
    if (-not $Global:RESTORE_CONFIG_AFTER_INSTALL) {
        return
    }
    
    Write-Host ""
    Write-LogInfo "restoring_config"
    
    $configPath = "$env:ENV_ROOT\tools\scripts\cmds\.config"
    
    # Restore config from backup
    if ($Global:TEMP_CONFIG_PATH -and (Test-Path $Global:TEMP_CONFIG_PATH)) {
        $parentDir = Split-Path $configPath -Parent
        if (-not (Test-Path $parentDir)) {
            New-Item -ItemType Directory -Path $parentDir -Force | Out-Null
        }
        Copy-Item -Path $Global:TEMP_CONFIG_PATH -Destination $configPath -Force
        Remove-Item -Path $Global:TEMP_CONFIG_PATH -Force -ErrorAction SilentlyContinue
    }
    
    # Note: local_pkgs was not deleted, no need to restore
    
    Write-LogSuccess "config_restored"
}

# ============================================================================
# Banner and Next Steps
# ============================================================================

function Show-Banner {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   $(Get-Message 'banner_title')   " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

function Show-NextSteps {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Green
    Write-LogSuccess "setup_complete"
    Write-Host "============================================================" -ForegroundColor Green
    Write-Host ""
    Write-LogInfo "next_steps"
    Write-Host ""
    Write-LogInfo "activate_env"
    $envDir = $env:ENV_ROOT
    $activateCmd = ". $envDir\env.ps1"
    Write-Host "   $activateCmd"
    Write-Host ""
    Write-LogInfo "add_to_profile"
    Write-Host "   echo '. $envDir\env.ps1' >> \$PROFILE"
    Write-Host "   . \$PROFILE"
    Write-Host ""
    Write-LogInfo "install_toolchain"
    Write-Host "   $(Get-Message 'install_toolchain_cmd')"
    Write-Host ""
    Write-LogInfo "after_activation"
    Write-Host "$(Get-Message 'menuconfig')"
    Write-Host "$(Get-Message 'pkgs')"
    Write-Host "$(Get-Message 'scons')"
    Write-Host "$(Get-Message 'sdk')"
    Write-Host ""
}

# ============================================================================
# Installation Steps Functions
# ============================================================================

function Check-ExistingEnv {
    # Check if any ENV subdirectory exists
    $toolsPath = "$env:ENV_ROOT\tools"
    $packagesPath = "$env:ENV_ROOT\packages"
    $pythonPath = "$env:ENV_ROOT\python"
    $venvPath = "$env:ENV_ROOT\$Global:VENV_DIR"
    $envScript = "$env:ENV_ROOT\env.ps1"

    $existingDirs = @()
    if (Test-Path $toolsPath) { $existingDirs += $toolsPath }
    if (Test-Path $packagesPath) { $existingDirs += $packagesPath }
    if (Test-Path $pythonPath) { $existingDirs += $pythonPath }
    if (Test-Path $venvPath) { $existingDirs += $venvPath }

    $envScriptExists = Test-Path $envScript

    if ($existingDirs.Count -gt 0 -or $envScriptExists) {
        Write-LogWarning "env_root_exists" $env:ENV_ROOT
        # Show what will be deleted
        Write-Host "  将删除以下目录/文件:" -ForegroundColor Yellow
        foreach ($dir in $existingDirs) {
            Write-Host "    - $dir" -ForegroundColor DarkGray
        }
        if ($envScriptExists) {
            Write-Host "    - $envScript" -ForegroundColor DarkGray
        }
        Write-Host ""
        if ($Global:AUTO_MODE) {
            # Auto mode: preserve config and toolchain by default
            Write-LogInfo "removing_env_root_preserving" $env:ENV_ROOT
            
            # Define paths to preserve
            $configPath = "$env:ENV_ROOT\tools\scripts\cmds\.config"
            $localPkgsPath = "$env:ENV_ROOT\local_pkgs"
            $tempConfigPath = "$env:ENV_ROOT\.config.backup"
            
            # Set global flags for restoration after installation
            $Global:RESTORE_CONFIG_AFTER_INSTALL = $false
            $Global:TEMP_CONFIG_PATH = ""
            
            # Move config to ENV_ROOT root temporarily
            if (Test-Path $configPath) {
                Copy-Item -Path $configPath -Destination $tempConfigPath -Force -ErrorAction SilentlyContinue
                $Global:RESTORE_CONFIG_AFTER_INSTALL = $true
                $Global:TEMP_CONFIG_PATH = $tempConfigPath
            }
            
            # Note: local_pkgs is not deleted, no need to backup
            
            # Remove directories (excluding local_pkgs)
            foreach ($dir in $existingDirs) {
                # Skip local_pkgs directory
                if ($dir -eq $localPkgsPath) {
                    continue
                }
                Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
            }
            if ($envScriptExists) {
                Remove-Item -Path $envScript -ErrorAction SilentlyContinue
            }
            
            # Note: Config will be restored after installation completes
            Write-LogSuccess "env_root_removed" $env:ENV_ROOT
        }
        else {
            Write-Host ""
            Write-Host "$(Get-Message 'env_root_prompt')"
            $confirmMsg = "$(Get-Message 'env_root_confirm')"
            $confirmHelp = "$(Get-Message 'env_root_confirm_help')"
            $confirmAll = "$(Get-Message 'env_root_confirm_all')"
            $confirmNo = "$(Get-Message 'env_root_confirm_no')"
            
            Write-Host "$confirmMsg" -NoNewline -ForegroundColor Red
            Write-Host ""
            Write-Host $confirmHelp -ForegroundColor Cyan
            Write-Host $confirmAll -ForegroundColor Cyan
            Write-Host $confirmNo -ForegroundColor Cyan
            Write-Host "> " -NoNewline -ForegroundColor Yellow
            $response = Read-Host
            
            if ([string]::IsNullOrEmpty($response)) {
                $response = "y"  # Default is y (preserve)
            }
            
            if ($response -match "^[Yy]$") {
                # Preserve config and toolchain
                Write-LogInfo "removing_env_root_preserving" $env:ENV_ROOT
                
                # Define paths to preserve
                $configPath = "$env:ENV_ROOT\tools\scripts\cmds\.config"
                $localPkgsPath = "$env:ENV_ROOT\local_pkgs"
                $tempConfigPath = "$env:ENV_ROOT\.config.backup"
                
                # Set global flags for restoration after installation
                $Global:RESTORE_CONFIG_AFTER_INSTALL = $false
                $Global:TEMP_CONFIG_PATH = ""
                
                if (Test-Path $configPath) {
                    Copy-Item -Path $configPath -Destination $tempConfigPath -Force
                    $Global:RESTORE_CONFIG_AFTER_INSTALL = $true
                    $Global:TEMP_CONFIG_PATH = $tempConfigPath
                }
                
                # Note: local_pkgs is not deleted, no need to backup
                
                # Remove directories (excluding local_pkgs)
                foreach ($dir in $existingDirs) {
                    # Skip local_pkgs directory
                    if ($dir -eq $localPkgsPath) {
                        continue
                    }
                    Remove-Item -Path $dir -Recurse -Force -ErrorAction SilentlyContinue
                }
                if ($envScriptExists) {
                    Remove-Item -Path $envScript -ErrorAction SilentlyContinue
                }
                
                # Note: Config will be restored after installation completes
                Write-LogSuccess "env_root_removed" $env:ENV_ROOT
            }
            elseif ($response -match "^[Aa]$") {
                # Delete entire directory
                Write-LogInfo "removing_env_root_all" $env:ENV_ROOT
                
                # Remove entire ENV_ROOT directory
                Remove-Item -Path $env:ENV_ROOT -Recurse -Force -ErrorAction SilentlyContinue
                
                Write-LogSuccess "env_root_removed" $env:ENV_ROOT
            }
            else {
                Write-LogInfo "installation_cancelled"
                exit 0
            }
        }
    }
}

function Ensure-Dependencies {
    # Check Python version and decide whether to use system Python or install portable version
    $pythonPaths = Find-SystemPython
    $pythonPath = Select-PythonInstallation -PythonPaths $pythonPaths

    if ($pythonPath) {
        $Global:SELECTED_PYTHON = $pythonPath
    }

    $usePortablePython = $false

    # If -P/--python flag is set, force use portable Python and skip system Python check
    if ($Global:USE_EMBED_PYTHON) {
        $usePortablePython = $true
        Write-LogInfo "using_portable_python"
    }
    elseif ($pythonPath) {
        # Python found, check version
        $pythonVersion = Get-PythonVersionString -PythonPath $pythonPath
        if ($pythonVersion) {
            $isValidVersion = Test-PythonVersion -VersionString $pythonVersion
            if (-not $isValidVersion) {
                # Version < 3.6, use portable Python
                $usePortablePython = $true
                Write-LogInfo "python_version_too_low"
            }
            else {
                # Version >= 3.6, use system Python
                $usePortablePython = $false
                Write-LogInfo "using_system_python"
            }
        }
        else {
            # Failed to get version, install portable Python
            $usePortablePython = $true
            Write-LogInfo "python_version_check_failed"
        }
    }
    else {
        # Python not found, install portable version
        $usePortablePython = $true
        Write-LogInfo "python_not_found"
    }

    # Install or use Python
    if ($usePortablePython) {
        $Global:SELECTED_PYTHON = Install-Python -UseCNMirror $Global:USE_CN
    }

    # Check and install Git if missing
    if (-not (Test-Command "git")) {
        Write-LogInfo "git_not_found"
        # When -y is used, install Git silently; otherwise show interactive installer
        Install-Git -UseCNMirror $Global:USE_CN -Interactive (-not $Global:AUTO_MODE)
        Write-Host ""
        Write-LogWarning "restart_required"
        Read-Host -Prompt "Press Enter to exit..."
        exit 0
    }

    $gitVersion = git --version 2>&1
    $gitVersion = $gitVersion.Trim()
    Write-LogSuccess "git_found" $gitVersion
}

function Setup-Repositories {
    # Set repository configuration based on mirror selection or custom mode
    $urlPackages = ""
    $urlEnv = ""
    $urlSdk = ""

    # Check for custom repositories
    $useCustomPackages = $false
    $useCustomEnv = $false
    $useCustomSdk = $false

    if ($Global:CUSTOM_PACKAGES_REPO) {
        $useCustomPackages = $true
        $urlPackages = $Global:CUSTOM_PACKAGES_REPO
        if ($Global:CUSTOM_PACKAGES_BRANCH) {
            Write-LogInfo "using_custom_repo_branch" $Global:CUSTOM_PACKAGES_REPO $Global:CUSTOM_PACKAGES_BRANCH
        }
        else {
            Write-LogInfo "using_custom_repo" $Global:CUSTOM_PACKAGES_REPO
        }
    }

    if ($Global:CUSTOM_ENV_REPO) {
        $useCustomEnv = $true
        $urlEnv = $Global:CUSTOM_ENV_REPO
        if ($Global:CUSTOM_ENV_BRANCH) {
            Write-LogInfo "using_custom_repo_branch" $Global:CUSTOM_ENV_REPO $Global:CUSTOM_ENV_BRANCH
        }
        else {
            Write-LogInfo "using_custom_repo" $Global:CUSTOM_ENV_REPO
        }
    }

    if ($Global:CUSTOM_SDK_REPO) {
        $useCustomSdk = $true
        $urlSdk = $Global:CUSTOM_SDK_REPO
        if ($Global:CUSTOM_SDK_BRANCH) {
            Write-LogInfo "using_custom_repo_branch" $Global:CUSTOM_SDK_REPO $Global:CUSTOM_SDK_BRANCH
        }
        else {
            Write-LogInfo "using_custom_repo" $Global:CUSTOM_SDK_REPO
        }
    }

    # Use standard repositories for any not specified
    $repoConfig = if ($Global:USE_CN) {
        @($REPO_PACKAGES_GITEE, $REPO_ENV_GITEE, $REPO_SDK_GITEE)
    }
    else {
        @($REPO_PACKAGES_GITHUB, $REPO_ENV_GITHUB, $REPO_SDK_GITHUB)
    }

    if (-not $useCustomPackages) { $urlPackages = $repoConfig[0] }
    if (-not $useCustomEnv) { $urlEnv = $repoConfig[1] }
    if (-not $useCustomSdk) { $urlSdk = $repoConfig[2] }

    # Clone repositories
    Clone-Repository -Url $urlPackages -Destination "$env:ENV_ROOT\packages\packages" -Depth 1 -Branch $Global:CUSTOM_PACKAGES_BRANCH
    Clone-Repository -Url $urlSdk -Destination "$env:ENV_ROOT\packages\sdk" -Depth 1 -Branch $Global:CUSTOM_SDK_BRANCH
    Clone-Repository -Url $urlEnv -Destination "$env:ENV_ROOT\tools\scripts" -Depth 1 -Branch $Global:CUSTOM_ENV_BRANCH

    # Generate Kconfig file
    Generate-KconfigFile -EnvRoot "$env:ENV_ROOT"

    if (Test-Path "$env:ENV_ROOT\tools\scripts\env.ps1") {
        Copy-Item -Path "$env:ENV_ROOT\tools\scripts\env.ps1" -Destination "$env:ENV_ROOT\env.ps1" -Force
        Write-LogSuccess "copied_env_script" "$env:ENV_ROOT\env.ps1"
    }

    Write-Host ""
}

function Prompt-Pyocd {
    # If --pyocd was specified, skip prompt and install directly
    if ($Global:INSTALL_PYOCD) {
        return
    }

    # Prompt user for pyocd installation (optional debugging tool)
    if ($Global:AUTO_MODE) {
        $Global:INSTALL_PYOCD = $false
    }
    else {
        Write-Host ""
        Write-Host "$(Get-Message 'pyocd_install_prompt')"
        $confirmMsg = "$(Get-Message 'pyocd_install_confirm')"
        Write-Host "$confirmMsg " -NoNewline -ForegroundColor Yellow
        $response = Read-Host
        if ($response -match "^[Nn]$") {
            $Global:INSTALL_PYOCD = $false
        }
        else {
            $Global:INSTALL_PYOCD = $true
        }
    }
}

# ============================================================================
# Main Function
# ============================================================================

function Main {
    # Initialize globals
    $Global:LANG_CURRENT = if ($zhMode) { "zh" } elseif ($enMode) { "en" } else { Get-SystemLanguage }
    $Global:USE_CN = $cnMode
    $Global:USE_CN_SET = $cnMode -or $officialMode
    $Global:INSTALL_PYOCD = $pyocdMode
    $Global:AUTO_MODE = $autoMode
    $Global:NEED_HELP = $helpMode
    $Global:USE_EMBED_PYTHON = $pythonMode
    $Global:CUSTOM_PACKAGES_REPO = $customPackagesRepo
    $Global:CUSTOM_PACKAGES_BRANCH = $customPackagesBranch
    $Global:CUSTOM_ENV_REPO = $customEnvRepo
    $Global:CUSTOM_ENV_BRANCH = $customEnvBranch
    $Global:CUSTOM_SDK_REPO = $customSdkRepo
    $Global:CUSTOM_SDK_BRANCH = $customSdkBranch

    # Set and validate ENV_ROOT
    if ($envRootValue) { $env:ENV_ROOT = $envRootValue }
    if ($env:ENV_ROOT -match "\s") {
        Write-Host "Error: ENV_ROOT cannot contain spaces" -ForegroundColor Red
        exit 1
    }
    if ($env:ENV_ROOT -match "[^\x00-\x7F]") {
        Write-Host "Error: ENV_ROOT cannot contain non-ASCII characters" -ForegroundColor Red
        exit 1
    }

    # Check admin privilege for auto mode
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($autoMode -and -not $isAdmin -and -not $skipLongPath) {
        Write-LogError "admin_required"
        Write-LogWarning "run_as_admin"
        exit 1
    }

    # Show help and exit if requested
    if ($Global:NEED_HELP) {
        Print-Help
        return
    }

    # Detect China if not explicitly set
    if (-not $Global:USE_CN_SET) {
        $Global:USE_CN = Detect-China
    }

    # Override with --official flag
    if ($officialMode) {
        $Global:USE_CN = $false
    }

    # Step 1: Print installation banner
    Show-Banner

    # Step 2: Check if ENV_ROOT already exists
    Check-ExistingEnv

    # Step 3: Ensure Python and Git are installed
    Ensure-Dependencies

    # Step 4: Clone repositories and generate configuration
    Setup-Repositories

    # Step 5: Create virtual environment
    Create-Venv

    # Step 6: Prompt user for pyocd installation
    Prompt-Pyocd

    # Step 7: Install Python packages and pyocd (if requested)
    Write-LogInfo "installing_packages"
    Install-PythonPackages -UseCNMirror $Global:USE_CN -ScriptsDir "$env:ENV_ROOT\tools\scripts" -InstallPyocd $Global:INSTALL_PYOCD
    Write-Host ""

    # Step 8: Restore preserved config if needed
    Restore-PreservedConfig

    # Step 9: Show next steps
    Show-NextSteps
}

# ============================================================================
# Run Main Function
# ============================================================================

Main
