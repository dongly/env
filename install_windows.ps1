#
# RT-Thread ENV Installation Script (Windows)
# Supports: English / 中文
#
# Usage:
#   .\install_windows.ps1                        # Interactive installation (prompts for confirmation)
#   .\install_windows.ps1 -y                       # Auto-install (no prompts, default answers)
#   .\install_windows.ps1 --pyocd                  # Install pyocd
#   .\install_windows.ps1 --env-root <path>        # Set custom .env directory path
#   .\install_windows.ps1 --cn                     # Use Chinese mirror (npmmirror, Gitee)
#   .\install_windows.ps1 --cn --env-root <path>  # Use custom path + CN mirror
#   .\install_windows.ps1 --gitee                  # Use Gitee mirror
#   .\install_windows.ps1 --en                       # Force English messages
#   .\install_windows.ps1 --zh                       # Force Chinese messages
#

# Requires administrator privileges
#Requires -RunAsAdministrator

# ============================================================================
# Configuration
# ============================================================================

# Environment directory (can be overridden by --env-root or $env:ENV_ROOT)
$env:ENV_ROOT = if ($env:ENV_ROOT) { $env:ENV_ROOT } else { "$env:USERPROFILE\.env" }

# Virtual environment directory name
$Global:VENV_DIR = "rt-venv"

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
# Language Detection
# ============================================================================

$Global:LANG_CURRENT = "en"
$Global:USE_CN = $false
$Global:INSTALL_PYOCD = $false
$Global:AUTO_MODE = $false

function Detect-China {
    # Check if user is in China (by IP or system locale)
    $use_cn = $false

    # Check IP-based detection (works on all systems)
    try {
        $ip_info = Invoke-RestMethod -Uri $IPINFO_URL -Method Get -UseBasicParsing -TimeoutSec 5
        if ($ip_info.country -eq "CN") {
            $use_cn = $true
            $Global:LANG_CURRENT = "zh"
        }
    } catch {
        # Fallback to timezone
    }

    # Fallback: check system timezone
    if (-not $use_cn) {
        try {
            $timezone = [System.TimeZoneInfo]::Local.Id
            if ($timezone -like "*Shanghai*" -or $timezone -like "*China*" -or $timezone -like "*Beijing*") {
                $use_cn = $true
                $Global:LANG_CURRENT = "zh"
            }
        } catch {
            # Fallback to locale
        }
    }

    # Fallback: check system locale
    if (-not $use_cn) {
        $locale = [System.Globalization.CultureInfo]::CurrentUICulture.Name
        if ($locale -like "*zh*" -or $locale -like "*CN*") {
            $Global:LANG_CURRENT = "zh"
        }
    }

    return $use_cn
}

function Detect-Language {
    param([string[]]$Args)

    $Global:LANG_CURRENT = "en"
    $Global:USE_CN = $false
    $Global:INSTALL_PYOCD = $false
    $Global:INSTALL_OPENOCD = $false
    $Global:AUTO_MODE = $false

    foreach ($arg in $Args) {
        if ($arg -eq "-y" -or $arg -eq "--yes" -or $arg -eq "--auto") {
            $Global:AUTO_MODE = $true
        } elseif ($arg -eq "--en" -or $arg -eq "--english") {
            $Global:LANG_CURRENT = "en"
        } elseif ($arg -eq "--zh" -or $arg -eq "--chinese" -or $arg -eq "--中文") {
            $Global:LANG_CURRENT = "zh"
        } elseif ($arg -eq "--cn" -or $arg -eq "--gitee") {
            $Global:USE_CN = $true
            $Global:LANG_CURRENT = "zh"
        } elseif ($arg -eq "--pyocd") {
            $Global:INSTALL_PYOCD = $true
        }
    }

    # IP detection (lower priority, only if not explicitly set)
    if (-not $Global:USE_CN) {
        $Global:USE_CN = Detect-China
    }

    # Log IP detection result
    if ($Global:USE_CN) {
        Write-LogInfo "using_cn_mirror"
    } else {
        Write-LogInfo "using_github"
    }
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
$MSG_EN_python_found = "Python found: %s"
$MSG_EN_python_not_found = "Python is not installed. Will install Python 3.12.10."
$MSG_EN_installing_python = "Installing Python 3.12.10..."
$MSG_EN_downloading_python = "Downloading Python..."
$MSG_EN_python_installed = "Python installed. Please restart terminal and run this script again."
$MSG_EN_checking_git = "Checking Git..."
$MSG_EN_git_found = "Git found: %s"
$MSG_EN_git_not_found = "Git is not installed. Will install Git v2.52.0.windows.1."
$MSG_EN_installing_pip = "Installing pip..."
$MSG_EN_pip_installed = "pip installed successfully"
$MSG_EN_installing_git = "Installing Git..."
$MSG_EN_git_installed = "Git installed. Please restart terminal and run this script again."
$MSG_EN_fetching_git_from_npmmirror = "Fetching Git version from npmmirror..."
$MSG_EN_fetching_git_from_github = "Fetching Git version from GitHub API..."
$MSG_EN_git_version_found = "Git version found: %s"
$MSG_EN_npmmirror_fetch_failed = "Failed to fetch Git version from npmmirror, trying GitHub API..."
$MSG_EN_github_api_failed = "GitHub API request failed, using fallback version..."
$MSG_EN_using_fixed_git_version = "Using fixed Git version: %s"
$MSG_EN_restart_required = "Please restart terminal and run this script again to continue."
$MSG_EN_git_not_found = "Git is not installed. Please install Git first."
$MSG_EN_please_install_git = "Please install Git first"
$MSG_EN_install_git_windows = "Windows: Download and install Git from $GIT_DOWNLOAD_URL"
$MSG_EN_cloning = "Cloning %s to %s"
$MSG_EN_cloned = "Cloned %s"
$MSG_EN_dir_exists = "Directory already exists: %s"
$MSG_EN_generating_kconfig = "Generating Kconfig: %s"
$MSG_EN_installing_windows = "Installing dependencies (Windows)..."
$MSG_EN_unsupported_os = "Unsupported OS: %s"
$MSG_EN_missing_gcc = "Missing GCC compiler, please install manually"
$MSG_EN_installing_packages = "Installing Python packages..."
$MSG_EN_env_root_exists = "Environment directory already exists: %s"
$MSG_EN_env_root_prompt = "Existing RT-Thread ENV detected. Do you want to delete and reinstall?"
$MSG_EN_env_root_confirm = "Are you sure you want to delete? [y/N] "
$MSG_EN_removing_env_root = "Removing existing environment..."
$MSG_EN_env_root_removed = "Existing environment removed"
$MSG_EN_installation_cancelled = "Installation cancelled"
$MSG_EN_venv_not_found = "Virtual environment not found, please recreate"
$MSG_EN_upgrading_pip = "Upgrading pip..."
$MSG_EN_package_install_failed = "Package installation failed, please check network connection or permissions"
$MSG_EN_installing_pyocd = "Installing pyocd..."
$MSG_EN_pyocd_installed = "pyocd installed successfully"
$MSG_EN_pyocd_install_failed = "pyocd installation failed, please check network connection or permissions"
$MSG_EN_pyocd_install_prompt = "Do you want to install pyocd (for debugging Cortex-M devices)?"
$MSG_EN_pyocd_install_confirm = "Install pyocd? [y/N] "
$MSG_EN_installation_skip_existing = "RT-Thread ENV already exists, skipping installation (use -y to force reinstall)"
$MSG_EN_missing_python = "Python 3 not found, please install first"
$MSG_EN_python_version_check = "Checking Python version..."
$MSG_EN_python_version = "Python version: %s"
$MSG_EN_python_version_failed = "Failed to get Python version information"
$MSG_EN_creating_venv = "Creating virtual environment..."
$MSG_EN_venv_created = "Virtual environment created"
$MSG_EN_venv_exists = "Virtual environment already exists"
$MSG_EN_activating_venv = "Activating virtual environment..."
$MSG_EN_using_cn_mirror = "Using China mirror"
$MSG_EN_using_github = "Using GitHub"
$MSG_EN_using_pypi_mirror = "Using PyPI mirror: %s"
$MSG_EN_installed_packages = "Python packages installed successfully"
$MSG_EN_copied_env_script = "Copied env.ps1: %s"
$MSG_EN_setup_complete = "RT-Thread ENV installation completed!"
$MSG_EN_next_steps = "Next steps:"
$MSG_EN_activate_env = "1. Activate environment:"
$MSG_EN_activate_cmd = "   > . %s\env.ps1"
$MSG_EN_add_to_profile = "2. Add to profile:"
$MSG_EN_add_profile_cmd = "   > echo '. %s\env.ps1' >> \$PROFILE"
$MSG_EN_reload_profile = "   > . \$PROFILE"
$MSG_EN_install_toolchain = "3. Install toolchains:"
$MSG_EN_install_toolchain_cmd = "   Run 'sdk' command to install required toolchains"
$MSG_EN_after_activation = "4. After activation, you can use:"
$MSG_EN_menuconfig = "     - menuconfig    : Configure RT-Thread"
$MSG_EN_pkgs = "     - pkgs          : Package manager"
$MSG_EN_scons = "     - scons         : Build RT-Thread"
$MSG_EN_sdk = "     - sdk           : Install toolchains"

# Chinese messages
$MSG_ZH_banner_title = "RT-Thread ENV 安装程序"
$MSG_ZH_info = "信息"
$MSG_ZH_success = "成功"
$MSG_ZH_warning = "警告"
$MSG_ZH_error = "错误"
$MSG_ZH_checking_python = "正在检查 Python..."
$MSG_ZH_python_found = "找到 Python: %s"
$MSG_ZH_python_not_found = "未安装 Python。将安装 Python 3.12.10。"
$MSG_ZH_installing_python = "正在安装 Python 3.12.10..."
$MSG_ZH_downloading_python = "正在下载 Python..."
$MSG_ZH_python_installed = "Python 已安装。请重新启动终端并再次运行此脚本。"
$MSG_ZH_checking_git = "正在检查 Git..."
$MSG_ZH_git_found = "找到 Git: %s"
$MSG_ZH_git_not_found = "未安装 Git。将安装 Git v2.52.0.windows.1。"
$MSG_ZH_installing_pip = "正在安装 pip..."
$MSG_ZH_pip_installed = "pip 安装成功"
$MSG_ZH_installing_git = "正在安装 Git..."
$MSG_ZH_git_installed = "Git 已安装。请重新启动终端并再次运行此脚本。"
$MSG_ZH_fetching_git_from_npmmirror = "正在从 npmmirror 获取 Git 版本..."
$MSG_ZH_fetching_git_from_github = "正在从 GitHub API 获取 Git 版本..."
$MSG_ZH_git_version_found = "找到 Git 版本: %s"
$MSG_ZH_npmmirror_fetch_failed = "从 npmmirror 获取 Git 版本失败，尝试 GitHub API..."
$MSG_ZH_github_api_failed = "GitHub API 请求失败，使用备选版本..."
$MSG_ZH_using_fixed_git_version = "使用固定 Git 版本: %s"
$MSG_ZH_restart_required = "请重新启动终端并再次运行此脚本以继续。"
$MSG_ZH_banner_title = "RT-Thread ENV 安装程序"
$MSG_ZH_git_not_found = "未安装 Git。请先安装 Git。"
$MSG_ZH_please_install_git = "请先安装 Git"
$MSG_ZH_install_git_windows = "Windows: 从 $GIT_DOWNLOAD_URL 下载并安装 Git"
$MSG_ZH_cloning = "正在克隆: %s 到 %s"
$MSG_ZH_cloned = "已克隆: %s"
$MSG_ZH_dir_exists = "目录已存在: %s"
$MSG_ZH_generating_kconfig = "生成 Kconfig: %s"
$MSG_ZH_installing_windows = "正在安装依赖 (Windows)..."
$MSG_ZH_unsupported_os = "不支持的操作系统: %s"
$MSG_ZH_missing_gcc = "缺少 GCC 编译器，请手动安装"
$MSG_ZH_installing_packages = "正在安装 Python 包..."
$MSG_ZH_env_root_exists = "环境目录已存在: %s"
$MSG_ZH_env_root_prompt = "检测到已存在的RT-Thread ENV。是否要删除并重新安装？"
$MSG_ZH_env_root_confirm = "确定要删除吗？[y/N] "
$MSG_ZH_removing_env_root = "正在删除现有环境..."
$MSG_ZH_env_root_removed = "现有环境已删除"
$MSG_ZH_installation_cancelled = "安装已取消"
$MSG_ZH_venv_not_found = "找不到虚拟环境，请重新创建"
$MSG_ZH_upgrading_pip = "正在升级 pip..."
$MSG_ZH_package_install_failed = "包安装失败，请检查网络连接或权限"
$MSG_ZH_installing_pyocd = "正在安装 pyocd..."
$MSG_ZH_pyocd_installed = "pyocd 安装成功"
$MSG_ZH_pyocd_install_failed = "pyocd 安装失败，请检查网络连接或权限"
$MSG_ZH_pyocd_install_prompt = "是否要安装 pyocd (用于调试 Cortex-M 设备)？"
$MSG_ZH_pyocd_install_confirm = "安装 pyocd？[y/N] "
$MSG_ZH_installation_skip_existing = "RT-Thread ENV 已存在，跳过安装（使用 -y 参数强制重新安装）"
$MSG_ZH_missing_python = "未找到 Python 3，请先安装"
$MSG_ZH_python_version_check = "正在检查 Python 版本..."
$MSG_ZH_python_version = "Python 版本: %s"
$MSG_ZH_python_version_failed = "无法获取 Python 版本信息"
$MSG_ZH_creating_venv = "正在创建虚拟环境..."
$MSG_ZH_venv_created = "虚拟环境创建完成"
$MSG_ZH_venv_exists = "虚拟环境已存在"
$MSG_ZH_activating_venv = "正在激活虚拟环境..."
$MSG_ZH_using_cn_mirror = "使用中国镜像源"
$MSG_ZH_using_github = "使用 GitHub 源"
$MSG_ZH_using_pypi_mirror = "使用 PyPI 镜像: %s"
$MSG_ZH_installed_packages = "Python 包安装完成"
$MSG_ZH_copied_env_script = "已复制 env.ps1: %s"
$MSG_ZH_setup_complete = "RT-Thread ENV 安装完成！"
$MSG_ZH_next_steps = "后续步骤:"
$MSG_ZH_activate_env = "1. 激活环境:"
$MSG_ZH_activate_cmd = "   > . %s\env.ps1"
$MSG_ZH_add_to_profile = "2. 添加到配置文件:"
$MSG_ZH_add_profile_cmd = "   > echo '. %s\env.ps1' >> \$PROFILE"
$MSG_ZH_reload_profile = "   > . \$PROFILE"
$MSG_ZH_install_toolchain = "3. 安装工具链:"
$MSG_ZH_install_toolchain_cmd = "   运行 sdk 命令安装所需的工具链"
$MSG_ZH_after_activation = "4. 激活后可用命令:"
$MSG_ZH_menuconfig = "     - menuconfig    : 配置 RT-Thread"
$MSG_ZH_pkgs = "     - pkgs          : 包管理器"
$MSG_ZH_scons = "     - scons         : 编译 RT-Thread"
$MSG_ZH_sdk = "     - sdk           : 安装工具链"

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

# Print colored messages
function Write-LogInfo {
    param([string]$Key, [object[]]$Args)
    $msg = Get-Message $Key
    $formatted = $msg -f $Args
    Write-Host "[$(Get-Message 'info')] $formatted" -ForegroundColor Cyan
}

function Write-LogSuccess {
    param([string]$Key, [object[]]$Args)
    $msg = Get-Message $Key
    $formatted = $msg -f $Args
    Write-Host "[$(Get-Message 'success')] $formatted" -ForegroundColor Green
}

function Write-LogWarning {
    param([string]$Key, [object[]]$Args)
    $msg = Get-Message $Key
    $formatted = $msg -f $Args
    Write-Host "[$(Get-Message 'warning')] $formatted" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Key, [object[]]$Args)
    $msg = Get-Message $Key
    $formatted = $msg -f $Args
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
    } catch {
        return $false
    }
}

function Clone-Repository {
    param([string]$Url, [string]$Destination, [int]$Depth = 1)

    if (-not (Test-Path -Path $Destination)) {
        Write-LogInfo "cloning" $Url $Destination
        & git clone --depth $Depth $Url $Destination 2>&1
        Write-LogSuccess "cloned" $Destination
    } else {
        Write-LogSuccess "dir_exists" $Destination
    }
}

function Generate-KconfigFile {
    param([string]$EnvRoot)

    $kconfigPath = Join-Path $EnvRoot "packages\Kconfig"

    $content = 'source "$PKGS_DIR/packages/Kconfig"' + "`n"
    Set-Content -Path $kconfigPath -Value $content

    Write-LogSuccess "generating_kconfig" $kconfigPath
}

# ============================================================================
# Python Installation
# ============================================================================

$PYTHON_VERSION = "3.12.10"
$PYTHON_ARCHIVE = "python-$PYTHON_VERSION-embed-amd64.zip"
# Python download URLs
$PYTHON_URL_DEFAULT = "https://www.python.org/ftp/python/$PYTHON_VERSION/$PYTHON_ARCHIVE"
$PYTHON_URL_CN = "https://registry.npmmirror.com/-/binary/python/$PYTHON_VERSION/$PYTHON_ARCHIVE"

# Git download URLs
$GIT_NPMMIRROR_URL = "https://registry.npmmirror.com/-/binary/git-for-windows/"
$GIT_GITHUB_API_URL = "https://api.github.com/repos/git-for-windows/git/releases/latest"
$GIT_FALLBACK_URL = "https://github.com/git-for-windows/git/releases/download/v2.52.0.windows.1/Git-v2.52.0.windows.1-64-bit.exe"

function Install-Python {
    param([bool]$UseCNMirror)

    Write-LogInfo "downloading_python"
    $archivePath = Join-Path $env:TEMP $PYTHON_ARCHIVE

    # Determine download URL based on mirror setting
    $pythonUrl = if ($UseCNMirror) { $PYTHON_URL_CN } else { $PYTHON_URL_DEFAULT }

    # Download Python embed archive
    Invoke-WebRequest -Uri $pythonUrl -OutFile $archivePath -UseBasicParsing

    Write-LogInfo "installing_python"

    # Extract Python to ENV_ROOT directory
    $pythonTargetDir = "$env:ENV_ROOT\python"
    if (Test-Path $pythonTargetDir) {
        Remove-Item -Path $pythonTargetDir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $pythonTargetDir -Force | Out-Null

    # Extract the zip file
    Expand-Archive -Path $archivePath -DestinationPath $pythonTargetDir -Force

    # Cleanup archive
    Remove-Item $archivePath -ErrorAction SilentlyContinue

    # Modify python3xx._pth to enable site-packages and ensurepip
    $pthFile = Get-ChildItem -Path $pythonTargetDir -Filter "*._pth"
    if ($pthFile) {
        $pthContent = Get-Content -Path $pthFile.FullName -Raw
        # Uncomment import site to enable site-packages
        $pthContent = $pthContent -replace "#import site", "import site"
        Set-Content -Path $pthFile.FullName -Value $pthContent -NoNewline
    }

    # Install pip using ensurepip
    $pythonExe = Join-Path $pythonTargetDir "python.exe"
    if (Test-Path $pythonExe) {
        Write-LogInfo "installing_pip"
        & $pythonExe -m ensurepip --upgrade --default-pip 2>&1 | Out-Null
        Write-LogSuccess "pip_installed"
    }

    Write-LogSuccess "python_installed"
}

# ============================================================================
# Git Installation
# ============================================================================

$GIT_FALLBACK_VERSION = "v2.52.0.windows.1"
$GIT_FALLBACK_URL = "https://github.com/git-for-windows/git/releases/download/v2.52.0.windows.1/Git-v2.52.0.windows.1-64-bit.exe"

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
                $_.name -notmatch "-rc$" -and
                $_.name -notmatch "-prerelease$" -and
                $_.name -notmatch "-mingit$"
            }

            if ($filteredVersions.Count -gt 0) {
                # Sort versions by name (descending)
                $sortedVersions = $filteredVersions | Sort-Object -Property Name -Descending

                $latest = $sortedVersions[0]
                $versionNumber = $latest.name -replace '/$', ''

                # Construct installer filename
                $installerName = "Git-$versionNumber-64-bit.exe"
                $downloadUrl = $latest.url + $installerName

                Write-LogSuccess "git_version_found" "$versionNumber (from npmmirror)"
                return @{
                    Version = $versionNumber
                    Installer = $installerName
                    Url = $downloadUrl
                    Source = "npmmirror"
                }
            }
        } catch {
            Write-LogWarning "npmmirror_fetch_failed"
        }
    }

    # Fallback to GitHub API (for non-CN users or if npmmirror fails)
    try {
        Write-LogInfo "fetching_git_from_github"
        $response = Invoke-RestMethod -Uri $GIT_GITHUB_API_URL -Method Get -UseBasicParsing

        $tagName = $response.tag_name
        $versionNumber = $tagName -replace '^v', ''

        # Find the 64-bit installer
        $installerAsset = $response.assets | Where-Object {
            $_.name -match "Git-$tagName-64-bit\.exe$"
        }

        if ($installerAsset) {
            Write-LogSuccess "git_version_found" "$versionNumber (from GitHub)"
            return @{
                Version = $versionNumber
                Installer = $installerAsset.name
                Url = $installerAsset.browser_download_url
                Source = "github"
            }
        }
    } catch {
        Write-LogWarning "github_api_failed"
    }

    # Ultimate fallback: use fixed version
    Write-LogWarning "using_fixed_git_version" "$GIT_FALLBACK_VERSION"
    return @{
        Version = $GIT_FALLBACK_VERSION
        Installer = "Git-$GIT_FALLBACK_VERSION-64-bit.exe"
        Url = $GIT_FALLBACK_URL
        Source = "fallback"
    }
}

function Install-Git {
    param([bool]$UseCNMirror)

    # Get latest Git version dynamically
    $gitInfo = Get-LatestGitVersion -UseCNMirror $UseCNMirror

    Write-LogInfo "downloading_git"

    $installerPath = Join-Path $env:TEMP $gitInfo.Installer
    $gitUrl = $gitInfo.Url

    # Download Git installer
    Invoke-WebRequest -Uri $gitUrl -OutFile $installerPath -UseBasicParsing

    Write-LogInfo "installing_git"

    # Install Git silently
    Start-Process -FilePath $installerPath -ArgumentList @("/silent") -Wait

    # Cleanup
    Remove-Item $installerPath -ErrorAction SilentlyContinue

    Write-LogSuccess "git_installed"
}

# ============================================================================
# Python Environment Setup
# ============================================================================

function Find-Python {
    $pythonCmd = $null

    # First check for Python in ENV_ROOT (prioritized location)
    $envRootPython = Join-Path $env:ENV_ROOT "python"
    $envRootPythonExe = Join-Path $envRootPython "python.exe"
    if (Test-Path $envRootPythonExe) {
        try {
            $version = & $envRootPythonExe --version 2>&1 | Select-String "Python"
            if ($?) {
                $pythonCmd = $envRootPythonExe
                Write-LogSuccess "python_found" "$($version.Line)"
                return $pythonCmd
            }
        } catch {
            # Fall through to system search
        }
    }

    # Search for Python in system PATH
    foreach ($cmd in @("python", "python3", "py")) {
        try {
            $version = & $cmd --version 2>&1 | Select-String "Python"
            if ($?) {
                $pythonCmd = $cmd
                Write-LogSuccess "python_found" "$($version.Line)"
                return $pythonCmd
            }
        } catch {
            continue
        }
    }

    return $null
}

function Create-Venv {
    $pythonCmd = Find-Python

    if (-not $pythonCmd) {
        Write-LogError "missing_python"
        exit 1
    }

    # Create virtual environment if it doesn't exist
    $venvPath = "$env:ENV_ROOT\$Global:VENV_DIR"
    if (-not (Test-Path $venvPath)) {
        Write-LogInfo "creating_venv"
        & $pythonCmd -m venv $venvPath
        Write-LogSuccess "venv_created"
    } else {
        Write-LogSuccess "venv_exists"
    }
}

function Install-PythonPackages {
    param([bool]$UseCNMirror, [string]$ScriptsDir, [bool]$InstallPyocd)

    Write-LogInfo "activating_venv"
    $activateScript = "$env:ENV_ROOT\$Global:VENV_DIR\Scripts\Activate.ps1"

    if (Test-Path $activateScript) {
        & $activateScript
    } else {
        Write-LogError "venv_not_found"
        exit 1
    }

    # Upgrade pip first
    Write-LogInfo "upgrading_pip"
    pip install --upgrade pip

    # Build pip install command arguments
    $pipArgs = @()

    if ($UseCNMirror) {
        Write-LogInfo "using_cn_mirror"
        Write-LogInfo "using_pypi_mirror" $PYPI_MIRROR_CN
        $pipArgs += @("--index-url", $PYPI_MIRROR_CN)
    }

    $pipArgs += @("-e", $ScriptsDir)

    # Add pyocd if requested
    if ($InstallPyocd) {
        Write-LogInfo "installing_pyocd"
        $pipArgs += @("pyocd")
    }

    # Install all packages in one command
    if (pip install @pipArgs) {
        Write-LogSuccess "installed_packages"
        if ($InstallPyocd) {
            Write-LogSuccess "pyocd_installed"
        }
    } else {
        Write-LogError "package_install_failed"
        if ($InstallPyocd) {
            Write-LogError "pyocd_install_failed"
        }
        exit 1
    }
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
# Main Function
# ============================================================================

function Main {
    param([string[]]$Args)

    # Detect language and mirror
    Detect-Language $Args

    # Show banner
    Show-Banner

    # Check if ENV_ROOT already exists and prompt for reinstallation
    if ((Test-Path $env:ENV_ROOT) -and (Test-Path "$env:ENV_ROOT\env.ps1")) {
        Write-LogWarning "env_root_exists" $env:ENV_ROOT
        if ($Global:AUTO_MODE) {
            # Auto mode: skip existing environment
            Write-LogInfo "installation_skip_existing"
            exit 0
        } else {
            # Interactive mode: prompt user
            Write-Host ""
            Write-Host "$(Get-Message 'env_root_prompt')"
            $response = Read-Host "$(Get-Message 'env_root_confirm')"
            if ($response -match "^[Yy]$") {
                Write-LogInfo "removing_env_root"
                Remove-Item -Path $env:ENV_ROOT -Recurse -Force
                Write-LogSuccess "env_root_removed"
            } else {
                Write-LogInfo "installation_cancelled"
                exit 0
            }
        }
    }

    # Check Python
    Write-LogInfo "python_version_check"
    $python = Find-Python

    if (-not $python) {
        Write-LogInfo "python_not_found"
        Install-Python -UseCNMirror $Global:USE_CN
        # Refresh Python path after installation
        $python = Find-Python
    }

    # Check Git
    if (-not (Test-Command "git")) {
        Write-LogInfo "git_not_found"
        Install-Git -UseCNMirror $Global:USE_CN
        Write-Host ""
        Write-LogWarning "restart_required"
        Read-Host -Prompt "Press Enter to exit..."
        exit 0
    }

    $gitVersion = git --version 2>&1
    Write-LogSuccess "git_found" $gitVersion

    # Set repository configuration based on mirror selection
    if ($Global:USE_CN) {
        $repoConfig = @($REPO_PACKAGES_GITEE, $REPO_ENV_GITEE, $REPO_SDK_GITEE)
    } else {
        $repoConfig = @($REPO_PACKAGES_GITHUB, $REPO_ENV_GITHUB, $REPO_SDK_GITHUB)
    }

    # Clone repositories
    Clone-Repository -Url $repoConfig[0] -Destination "$env:ENV_ROOT\packages\packages" -Depth 1
    Clone-Repository -Url $repoConfig[2] -Destination "$env:ENV_ROOT\packages\sdk" -Depth 1

    # Generate Kconfig file
    Generate-KconfigFile -EnvRoot "$env:ENV_ROOT"

    # Clone env scripts
    Clone-Repository -Url $repoConfig[1] -Destination "$env:ENV_ROOT\tools\scripts" -Depth 1

    if (Test-Path "$env:ENV_ROOT\tools\scripts\env.ps1") {
        Copy-Item -Path "$env:ENV_ROOT\tools\scripts\env.ps1" -Destination "$env:ENV_ROOT\env.ps1" -Force
        Write-LogSuccess "copied_env_script" "$env:ENV_ROOT\env.ps1"
    }

    Write-Host ""

    # Create virtual environment
    Create-Venv

    # Prompt for pyocd installation if not already specified
    if (-not $Global:INSTALL_PYOCD) {
        if ($Global:AUTO_MODE) {
            # Auto mode: don't install pyocd by default
            $Global:INSTALL_PYOCD = $false
        } else {
            # Interactive mode: prompt user
            Write-Host ""
            Write-Host "$(Get-Message 'pyocd_install_prompt')"
            $response = Read-Host "$(Get-Message 'pyocd_install_confirm')"
            if ($response -match "^[Yy]$") {
                $Global:INSTALL_PYOCD = $true
            }
        }
    }

    # Install Python packages
    Write-LogInfo "installing_packages"
    Install-PythonPackages -UseCNMirror $Global:USE_CN -ScriptsDir "$env:ENV_ROOT\tools\scripts" -InstallPyocd $Global:INSTALL_PYOCD
    Write-Host ""

    # Show next steps
    Show-NextSteps
}

# Run main function
Main $Args