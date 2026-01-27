#
# RT-Thread ENV Installation Script (Windows)
# Unified installation script for Windows
# Supports: English / 中文
#
# Usage:
#   .\install.ps1 [-y] [-c] [-o] [-d] [-p] [-r <path>] [-e|-z] [-P <repo>[#<branch>]] [-E <repo>[#<branch>]] [-S <repo>[#<branch>]] [-l] [-t <url>] [-h]
#
# Options:
#   -y, --yes, --auto    Auto-install without prompts
#   -c, --cn, --gitee    Use China mirror (Gitee, PyPI TUNA)
#   -o, --official       Force use official source
#   -d, --pyocd          Install pyocd for debugging
#   -r, --env-root <path> Set custom install directory
#   -e, --en, --english  Force English messages
#   -z, --zh, --chinese  Force Chinese messages
#   -p, --python         Force install portable Python (ignore system Python)
#   -P, --packages <repo>[#<branch>]  Specify custom packages repository and branch
#   -E, --env <repo>[#<branch>]  Specify custom env repository and branch
#   -S, --sdk <repo>[#<branch>]  Specify custom sdk repository and branch
#   -l, --skip-long-path Skip enabling Windows long path support
#   -t, --touch-env-url <url> Specify touch_env.py download URL
#   -h, --help           Show this help message
#

# Configuration
# Repository URLs: GitHub (official) and Gitee (China mirror)
$REPO_PACKAGES_GITHUB = "https://github.com/RT-Thread/packages.git"
$REPO_ENV_GITHUB = "https://github.com/RT-Thread/env.git"
$REPO_SDK_GITHUB = "https://github.com/RT-Thread/sdk.git"

$REPO_PACKAGES_GITEE = "https://gitee.com/RT-Thread-Mirror/packages.git"
$REPO_ENV_GITEE = "https://gitee.com/RT-Thread-Mirror/env.git"
$REPO_SDK_GITEE = "https://gitee.com/RT-Thread-Mirror/sdk.git"

# touch_env.py download URLs
$TOUCH_ENV_URL_GITHUB = "https://raw.githubusercontent.com/RT-Thread/env/master/touch_env.py"
$TOUCH_ENV_URL_GITEE = "https://gitee.com/RT-Thread-Mirror/env/raw/master/touch_env.py"

# Default branches (empty means use git default)
$BRANCH_PACKAGES_DEFAULT = ""
$BRANCH_ENV_DEFAULT = ""
$BRANCH_SDK_DEFAULT = ""

# PyPI mirror and detection URLs
$PYPI_MIRROR_CN = "https://pypi.tuna.tsinghua.edu.cn/simple"

# Git download URLs
$GIT_GITHUB_API_URL = "https://api.github.com/repos/git-for-windows/git/releases/latest"
$GIT_NPMMIRROR_URL = "https://registry.npmmirror.com/-/binary/git-for-windows/"

# IPInfo API URL for detecting IP location
$IPINFO_URL = "https://ipinfo.io/json"

$ENV_DEFAULT_DIR = ".rtenv"

# Parse-RepoArg function
# Parse repository argument, format: url[#branch]
function Parse-RepoArg {
    param(
        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]$RepoArg
    )
    
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

# Parse-Arguments function
# Parse command line arguments and return parsed values
function Parse-Arguments {
    param([string[]]$Arguments)

    $result = [PSCustomObject]@{
        AutoMode = $false
        HelpMode = $false
        CnMode = $false
        OfficialMode = $false
        PyocdMode = $false
        PythonMode = $false
        EnMode = $false
        ZhMode = $false
        SkipLongPath = $false
        EnvRootValue = ""
        CustomPackagesRepo = ""
        CustomPackagesBranch = ""
        CustomEnvRepo = ""
        CustomEnvBranch = ""
        CustomSdkRepo = ""
        CustomSdkBranch = ""
        TouchEnvUrlValue = ""
    }

    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $arg = $Arguments[$i]
        switch -CaseSensitive ($arg) {
            { $_ -in @("-y", "--yes", "--auto") } { $result.AutoMode = $true }
            { $_ -in @("-h", "--help") } { $result.HelpMode = $true }
            { $_ -in @("-c", "--cn", "--gitee") } { $result.CnMode = $true }
            { $_ -in @("-o", "--official") } { $result.OfficialMode = $true }
            { $_ -in @("-d", "--pyocd") } { $result.PyocdMode = $true }
            { $_ -in @("-p", "--python") } { $result.PythonMode = $true }
            { $_ -in @("-e", "--en", "--english") } { $result.EnMode = $true }
            { $_ -in @("-z", "--zh", "--chinese") } { $result.ZhMode = $true }
            { $_ -in @("-r", "--env-root") } { $result.EnvRootValue = $Arguments[++$i] }
            { $_ -in @("-P", "--packages") } {
                $repoResult = Parse-RepoArg -RepoArg $Arguments[++$i]
                $result.CustomPackagesRepo = $repoResult.Repo
                $result.CustomPackagesBranch = $repoResult.Branch
            }
            { $_ -in @("-E", "--env") } {
                $repoResult = Parse-RepoArg -RepoArg $Arguments[++$i]
                $result.CustomEnvRepo = $repoResult.Repo
                $result.CustomEnvBranch = $repoResult.Branch
            }
            { $_ -in @("-S", "--sdk") } {
                $repoResult = Parse-RepoArg -RepoArg $Arguments[++$i]
                $result.CustomSdkRepo = $repoResult.Repo
                $result.CustomSdkBranch = $repoResult.Branch
            }
            { $_ -in @("-l", "--skip-long-path") } { $result.SkipLongPath = $true }
            { $_ -in @("-t", "--touch-env-url") } { $result.TouchEnvUrlValue = $Arguments[++$i] }
        }
    }

    return $result
}

# Parse command line arguments
$parsedArgs = Parse-Arguments -Arguments $args

$env:ENV_ROOT = if ($env:ENV_ROOT) { $env:ENV_ROOT } else { "$env:USERPROFILE\$ENV_DEFAULT_DIR" }

$script:Config = [PSCustomObject]@{
    LangCurrent = ""
    UseCN = $false
    UseCNSet = $false
    InstallPyocd = $false
    AutoMode = $false
    NeedHelp = $false
    UseEmbedPython = $false
    CustomPackagesRepo = ""
    CustomPackagesBranch = ""
    CustomEnvRepo = ""
    CustomEnvBranch = ""
    CustomSdkRepo = ""
    CustomSdkBranch = ""
    SelectedPython = ""
    TempFiles = @()  # Track temporary files for cleanup
}

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

# Register-CleanupHandler function
# Register cleanup handler for temporary files
function Register-CleanupHandler {
    try {
        Unregister-Event -SourceIdentifier Script.Cleanup -ErrorAction SilentlyContinue
    }
    catch {}

    $cleanupAction = {
        foreach ($tempFile in $script:Config.TempFiles) {
            if (Test-Path $tempFile) {
                Remove-Item $tempFile -ErrorAction SilentlyContinue
            }
        }
    }

    Register-EngineEvent -SourceIdentifier PowerShell.Exiting -Action $cleanupAction | Out-Null
}

# Register-CleanupHandler
Register-CleanupHandler

# Add-TempFile function
# Track temporary file for cleanup
function Add-TempFile {
    param([string]$FilePath)

    if ($script:Config.TempFiles -notcontains $FilePath) {
        $script:Config.TempFiles += $FilePath
    }
}

# Get-SystemLanguage function
# Detect system language, returns 'zh' or 'en'
function Get-SystemLanguage {
    $locale = [System.Globalization.CultureInfo]::CurrentUICulture.Name
    if ($locale -like "*zh*" -or $locale -like "*CN*") {
        return "zh"
    }
    return "en"
}

# Initialize config with default values
$script:Config.LangCurrent = Get-SystemLanguage

# Print-Help function
# Display help information and exit
function Print-Help {
    if ($script:Config.LangCurrent -eq "zh") {
        Write-Host "RT-Thread ENV 安装程序"
        Write-Host ""
        Write-Host "用法: .\install.ps1 [选项]"
        Write-Host ""
        Write-Host "选项:"
        Write-Host "  -y, --yes, --auto    自动安装，无需提示"
        Write-Host "  -c, --cn, --gitee    使用中国镜像（Gitee，清华 PyPI）"
        Write-Host "  -o, --official       强制使用官方源"
        Write-Host "  -d, --pyocd          安装 pyocd（用于调试）"
        Write-Host "  -p, --python         强制安装便携式 Python（忽略系统 Python）"
        Write-Host "  -r, --env-root [path] 设置自定义安装目录"
        Write-Host "  -e, --en, --english  强制显示英文信息"
        Write-Host "  -z, --zh, --chinese  强制显示中文信息"
        Write-Host "  -P, --packages [repo] 指定 packages 仓库地址和分支"
        Write-Host "                        格式: url[#branch]"
        Write-Host "  -E, --env [repo]     指定 env 仓库地址和分支"
        Write-Host "                        格式: url[#branch]"
        Write-Host "  -S, --sdk [repo]     指定 sdk 仓库地址和分支"
        Write-Host "                        格式: url[#branch]"
        Write-Host "  -l, --skip-long-path 跳过启用 Windows 长路径支持"
        Write-Host "  -t, --touch-env-url [url] 指定 touch_env.py 下载 URL"
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
        Write-Host "  -d, --pyocd          Install pyocd for debugging"
        Write-Host "  -p, --python         Force install portable Python (ignore system Python)"
        Write-Host "  -r, --env-root [path] Set custom install directory"
        Write-Host "  -e, --en, --english  Force English messages"
        Write-Host "  -z, --zh, --chinese  Force Chinese messages"
        Write-Host "  -P, --packages [repo] Specify custom packages repository and branch"
        Write-Host "                        Format: url[#branch]"
        Write-Host "  -E, --env [repo]     Specify custom env repository and branch"
        Write-Host "                        Format: url[#branch]"
        Write-Host "  -S, --sdk [repo]     Specify custom sdk repository and branch"
        Write-Host "                        Format: url[#branch]"
        Write-Host "  -l, --skip-long-path Skip enabling Windows long path support"
        Write-Host "  -t, --touch-env-url [url] Specify touch_env.py download URL"
        Write-Host "  -h, --help           Show this help message"
        Write-Host ""
    }
    exit 0
}

# Detect-China function
# Detect if user is in China (by IP or timezone)
function Detect-China {
    param(
        [bool]$LangEn = $false,
        [bool]$LangZh = $false
    )

    $use_cn = $false

    try {
        $ip_info = Invoke-RestMethod -Uri $IPINFO_URL -Method Get -UseBasicParsing -TimeoutSec 5
        if ($ip_info.country -eq "CN") {
            $use_cn = $true
        }
    }
    catch {
    }

    if (-not $use_cn) {
        try {
            $timezone = [System.TimeZoneInfo]::Local.Id
            if ($timezone -like "*Shanghai*" -or $timezone -like "*China*" -or $timezone -like "*Beijing*") {
                $use_cn = $true
            }
        }
        catch {
        }
    }
    return $use_cn
}

# Messages
# Centralized message dictionary for easy maintenance and localization
$script:Messages = @{
    en = @{
        banner_title = "RT-Thread ENV Installation"
        info = "INFO"
        success = "SUCCESS"
        warning = "WARNING"
        error = "ERROR"
        python_version_too_low = "Python version {0} is too old (requires >= 3.6). Installing portable Python..."
        missing_python = "Python not found. Please install Python first."
        using_system_python = "Using system Python: {0} - {1}"
        using_portable_python = "Will use portable Python {0}..."
        installing_portable_python = "Installing portable Python {0}..."
        downloading_portable_python = "Downloading portable Python, from: {0}"
        python_installed = "Python installed successfully."
        python_version_failed = "Failed to get Python version. Installing portable Python..."
        python_verification_failed = "Python verification failed. Installation may be corrupted."
        downloading_git = "Downloading Git..."
        installing_git = "Installing Git..."
        git_installed = "Git installed. Please restart terminal and run this script again."
        admin_required = "Error: The -y/--yes flag requires administrator privileges."
        run_as_admin = "Please run this script as administrator."
        fetching_git_from_npmmirror = "Fetching Git version from npmmirror..."
        fetching_git_from_github = "Fetching Git version from GitHub API..."
        git_version_found = "Git version found: {0}"
        npmmirror_fetch_failed = "Failed to fetch Git version from npmmirror, trying GitHub API..."
        download_failed = "Download failed: {0}"
        github_api_failed = "GitHub API request failed, using fallback version..."
        using_fixed_git_version = "Using fixed Git version: {0}"
        restart_required = "Please restart terminal and run this script again to continue."
        git_not_found = "Git is not installed. Please install Git first."
        git_found = "Git found: {0}"
        enabling_long_paths = "Enabling Windows long path support..."
        long_paths_enabled = "Windows long path support enabled"
        long_paths_enable_failed = "Failed to enable long path support (may require admin privileges)"
        need_admin_privilege = "Enabling long paths requires administrator privileges"
        elevating_to_enable_long_paths = "Attempting to enable long paths (UAC prompt may appear)"
        install_portable_python = "Install portable Python - Python {0}"
        multiple_python_found = "Multiple Python installations found:"
        select_python = "Found {0} Python installation(s). Default is option {1} (latest). Select [1-{0}], or {2} to install portable Python: "
        auto_selected = "Auto-selected Python: {0}"
        python_not_found = "Python not found. Please install Python first."
        env_root_invalid = "Error: ENV_ROOT cannot contain {0}"
        removing_portable_python = "Removing portable Python: {0}..."
        downloading_touch_env = "Downloading touch_env.py from: {0}"
        touch_env_failed = "touch_env.py execution failed with exit code: {0}"
        touch_env_download_failed = "Failed to download touch_env.py: {0}"
        python_pth_config_failed = "Warning: Failed to configure Python _pth file. site-packages may not be available."
    }
    zh = @{
        banner_title = "RT-Thread ENV 安装程序"
        info = "信息"
        success = "成功"
        warning = "警告"
        error = "错误"
        python_version_too_low = "Python 版本 {0} 过低（需要 >= 3.6）。将安装便携式 Python..."
        missing_python = "未安装 Python。请先安装 Python。"
        using_system_python = "使用系统 Python: {0} - {1}"
        using_portable_python = "将使用便携式 Python {0}..."
        installing_portable_python = "正在安装便携式 Python {0}..."
        downloading_portable_python = "正在下载便携式 Python，自: {0}"
        python_installed = "Python 已安装成功。"
        python_version_failed = "无法获取 Python 版本。正在安装便携式 Python..."
        python_verification_failed = "Python 验证失败。安装可能已损坏。"
        downloading_git = "正在下载 Git..."
        installing_git = "正在安装 Git..."
        git_installed = "Git 已安装。请重新启动终端并再次运行此脚本。"
        admin_required = "错误: -y/--yes 参数需要管理员权限。"
        run_as_admin = "请以管理员身份运行此脚本。"
        fetching_git_from_npmmirror = "正在从 npmmirror 获取 Git 版本..."
        fetching_git_from_github = "正在从 GitHub API 获取 Git 版本..."
        git_version_found = "找到 Git 版本: {0}"
        npmmirror_fetch_failed = "从 npmmirror 获取 Git 版本失败，尝试 GitHub API..."
        download_failed = "下载失败: {0}"
        github_api_failed = "GitHub API 请求失败，使用备选版本..."
        using_fixed_git_version = "使用固定 Git 版本: {0}"
        restart_required = "请重新启动终端并再次运行此脚本以继续。"
        git_not_found = "未安装 Git。请先安装 Git。"
        git_found = "找到 Git: {0}"
        enabling_long_paths = "正在启用 Windows 长路径支持..."
        long_paths_enabled = "Windows 长路径支持已启用"
        long_paths_enable_failed = "启用长路径支持失败（可能需要管理员权限）"
        need_admin_privilege = "启用长路径需要管理员权限"
        elevating_to_enable_long_paths = "正在尝试启用长路径（可能会弹出 UAC 提示）"
        install_portable_python = "安装便携式 Python - Python {0}"
        multiple_python_found = "找到多个 Python 安装："
        select_python = "找到 {0} 个 Python 安装。默认选项为 {1}（最新）。选择 [1-{0}]，或输入 {2} 安装便携式 Python: "
        auto_selected = "自动选择 Python: {0}"
        python_not_found = "未找到 Python。请先安装 Python。"
        env_root_invalid = "错误: ENV_ROOT 不能包含 {0}"
        removing_portable_python = "正在删除便携式 Python: {0}..."
        downloading_touch_env = "正在下载 touch_env.py，自: {0}"
        touch_env_failed = "touch_env.py 执行失败，退出码: {0}"
        touch_env_download_failed = "下载 touch_env.py 失败: {0}"
        python_pth_config_failed = "警告: 配置 Python _pth 文件失败。site-packages 可能不可用。"
    }
}

# Message functions
# Get-Message: Get localized message
# Write-LogInfo: Output info log (cyan)
# Write-LogSuccess: Output success log (green)
# Write-LogWarning: Output warning log (yellow)
# Write-LogError: Output error log (red)

function Get-Message {
    param([string]$Key)

    $lang = $script:Config.LangCurrent
    if ($script:Messages.ContainsKey($lang) -and $script:Messages[$lang].ContainsKey($Key)) {
        return $script:Messages[$lang][$Key]
    }

    return "Unknown message: $Key"
}

function Write-LogInfo {
    param([string]$Key, [string]$Arg1, [string]$Arg2)
    $msg = Get-Message $Key
    $formatted = if ($null -ne $Arg1 -and $null -ne $Arg2) {
        $msg -f $Arg1, $Arg2
    } elseif ($null -ne $Arg1) {
        $msg -f $Arg1
    } else {
        $msg
    }
    Write-Host "[$(Get-Message 'info')] $formatted" -ForegroundColor Cyan
}

function Write-LogSuccess {
    param([string]$Key, [string]$Arg1, [string]$Arg2)
    $msg = Get-Message $Key
    $formatted = if ($null -ne $Arg1 -and $null -ne $Arg2) {
        $msg -f $Arg1, $Arg2
    } elseif ($null -ne $Arg1) {
        $msg -f $Arg1
    } else {
        $msg
    }
    Write-Host "[$(Get-Message 'success')] $formatted" -ForegroundColor Green
}

function Write-LogWarning {
    param([string]$Key, [string]$Arg1, [string]$Arg2)
    $msg = Get-Message $Key
    $formatted = if ($null -ne $Arg1 -and $null -ne $Arg2) {
        $msg -f $Arg1, $Arg2
    } elseif ($null -ne $Arg1) {
        $msg -f $Arg1
    } else {
        $msg
    }
    Write-Host "[$(Get-Message 'warning')] $formatted" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Key, [string]$Arg1, [string]$Arg2)
    $msg = Get-Message $Key
    $formatted = if ($null -ne $Arg1 -and $null -ne $Arg2) {
        $msg -f $Arg1, $Arg2
    } elseif ($null -ne $Arg1) {
        $msg -f $Arg1
    } else {
        $msg
    }
    Write-Host "[$(Get-Message 'error')] $formatted" -ForegroundColor Red
}

# Git Functions
# Test-Command: Test if command exists

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

# Git Installation Functions
# Get-LatestGitVersion: Get latest Git version
# Install-Git: Install Git (Windows)

function Get-LatestGitVersion {
    param([bool]$UseCNMirror)

    # Helper function to filter valid versions
    function Test-ValidGitVersion {
        param([string]$Name)
        return ($Name -notmatch "-rc\d+" -and
                $Name -notmatch "-prerelease$" -and
                $Name -notmatch "-mingit$")
    }

    # Helper function to build result object
    function New-GitVersionInfo {
        param(
            [string]$Version,
            [string]$Installer,
            [string]$Url,
            [string]$Source
        )
        return @{
            Version   = $Version
            Installer = $Installer
            Url       = $Url
            Source    = $Source
        }
    }

    # Try npmmirror first if using CN mirror
    if ($UseCNMirror) {
        try {
            Write-LogInfo "fetching_git_from_npmmirror"
            $versions = Invoke-RestMethod -Uri $GIT_NPMMIRROR_URL -Method Get -UseBasicParsing |
                        Where-Object { Test-ValidGitVersion -Name $_.name } |
                        Sort-Object -Property Name -Descending

            if ($versions.Count -gt 0) {
                $versionNumber = $versions[0].name -replace '/$', ''
                $versionUrl = "$GIT_NPMMIRROR_URL$versionNumber/"
                $versionFiles = Invoke-RestMethod -Uri $versionUrl -Method Get -UseBasicParsing
                $installerFile = $versionFiles | Where-Object { $_.name -match "^Git-\d+\.\d+\.\d+-64-bit\.exe$" }

                if ($installerFile) {
                    Write-LogSuccess "git_version_found" "$versionNumber (from npmmirror)"
                    return New-GitVersionInfo -Version $versionNumber -Installer $installerFile.name -Url $installerFile.url -Source "npmmirror"
                }
            }
        }
        catch {
            Write-LogWarning "npmmirror_fetch_failed"
        }
    }

    # Fallback to GitHub API
    try {
        Write-LogInfo "fetching_git_from_github"
        $response = Invoke-RestMethod -Uri $GIT_GITHUB_API_URL -Method Get -UseBasicParsing -ErrorAction Stop

        if ($response -is [string]) {
            throw "Received HTML instead of JSON"
        }

        $versionNumber = $response.tag_name -replace '^v', ''
        $installerAsset = $response.assets | Where-Object { $_.name -match "^Git-\d+\.\d+\.\d+-64-bit\.exe$" }

        if ($installerAsset) {
            Write-LogSuccess "git_version_found" "$versionNumber (from GitHub)"
            return New-GitVersionInfo -Version $versionNumber -Installer $installerAsset.name -Url $installerAsset.browser_download_url -Source "github"
        }
    }
    catch {
        Write-LogWarning "github_api_failed"
    }

    # Ultimate fallback: use fixed version
    Write-LogWarning "using_fixed_git_version" "$GIT_FALLBACK_VERSION"
    return New-GitVersionInfo -Version $GIT_FALLBACK_VERSION -Installer "Git-$GIT_FALLBACK_VERSION-64-bit.exe" -Url $GIT_FALLBACK_URL -Source "fallback"
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

    # Track temporary file for cleanup
    Add-TempFile -FilePath $installerPath

    try {
        # Download Git installer
        Invoke-WebRequest -Uri $gitUrl -OutFile $installerPath -UseBasicParsing -ErrorAction Stop

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

        Write-LogSuccess "git_installed"
    }
    finally {
        # Cleanup installer
        Remove-Item $installerPath -ErrorAction SilentlyContinue
    }
}
    
    # Python Installation Functions
    # Install-Python: Install portable Python
    # Download-PortablePython: Download portable Python
    # Extract-PortablePython: Extract portable Python
    # Enable-LongPathSupport: Enable Windows long path support
    # Configure-PythonPth: Configure Python _pth file

    $PYTHON_VERSION = "3.13.11"
    $PYTHON_ARCHIVE = "python-3.13.11-amd64.zip"
    $PYTHON_URL_DEFAULT = "https://www.python.org/ftp/python/$PYTHON_VERSION/$PYTHON_ARCHIVE"
    $PYTHON_URL_CN = "https://registry.npmmirror.com/-/binary/python/$PYTHON_VERSION/$PYTHON_ARCHIVE"
    
    $GIT_FALLBACK_VERSION = "v2.52.0.windows.1"
    $GIT_FALLBACK_URL = "https://github.com/git-for-windows/git/releases/download/v2.52.0.windows.1/Git-v2.52.0.windows.1-64-bit.exe"
    
    function Install-Python {
        param(
            [bool]$UseCNMirror,
            [bool]$SkipLongPath,
            [bool]$RemoveExisting = $true,
            [bool]$SkipVerification = $false
        )
    
        # Delete existing portable Python before installing new one (only if requested)
        if ($RemoveExisting) {
            $portablePythonPath = "$env:ENV_ROOT\python"
            if (Test-Path $portablePythonPath) {
                Write-LogInfo "removing_portable_python" $portablePythonPath
                Remove-Item -Path $portablePythonPath -Recurse -Force -ErrorAction SilentlyContinue
            }
        }
    
        Download-PortablePython -UseCNMirror $UseCNMirror
        Extract-PortablePython
        if (-not $SkipLongPath) {
            Enable-LongPathSupport
        }
        Configure-PythonPth
    
        # Save portable Python path to global variable
        $portablePython = Join-Path $env:ENV_ROOT "python\python.exe"

        # Verify Python installation by checking version with retry (can be skipped)
        if (-not $SkipVerification) {
            $maxRetries = 3
            $retryDelay = 1
            $pythonInstalled = $false

            for ($i = 0; $i -lt $maxRetries; $i++) {
                try {
                    $version = & $portablePython --version 2>&1
                    if ($version -match "Python") {
                        $pythonInstalled = $true
                        break
                    }
                }
                catch {
                    # Python may need time to initialize
                }
                Start-Sleep -Seconds $retryDelay
            }

            if (-not $pythonInstalled) {
                Write-LogError "python_verification_failed"
                exit 1
            }
        }

        Write-LogSuccess "python_installed"
        return $portablePython
    }

function Download-PortablePython {
    param([bool]$UseCNMirror)

    # Determine download URL based on mirror setting
    $pythonUrl = if ($UseCNMirror) { $PYTHON_URL_CN } else { $PYTHON_URL_DEFAULT }

    Write-LogInfo "downloading_portable_python" $pythonUrl
    $archivePath = Join-Path $env:TEMP $PYTHON_ARCHIVE

    # Track temporary file for cleanup
    Add-TempFile -FilePath $archivePath

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

            # Track temporary file for cleanup
            Add-TempFile -FilePath $tempScript

            @"
# Enable long paths in registry
try {
    Set-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem" -Name "LongPathsEnabled" -Value 1 -Type DWord -Force
    exit 0
}
catch {
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
        Write-LogWarning "python_pth_config_failed"
    }
}

# Python Environment Setup Functions
# Find-SystemPython: Find system Python
# Find-LatestPythonVersion: Find latest Python version
# Show-PythonOptions: Show Python options
# Handle-PythonSelection: Handle Python selection
# Select-PythonInstallation: Select Python installation
# Get-PythonVersionString: Get Python version string
# Test-PythonVersion: Test if Python version meets requirements

function Find-SystemPython {
    # Build search paths
    $searchPaths = @(
        "$env:LOCALAPPDATA\Programs\Python\python.exe"
        "$env:LOCALAPPDATA\Programs\Python\Python*\python.exe"
        "$env:ProgramFiles\Python\python.exe"
        "${env:ProgramFiles(x86)}\Python\python.exe"
        "$env:ProgramFiles\Python\Python*\python.exe"
        "${env:ProgramFiles(x86)}\Python\Python*\python.exe"
        "$env:USERPROFILE\Anaconda3\python.exe"
        "$env:USERPROFILE\Miniconda3\python.exe"
        "$env:USERPROFILE\conda\python.exe"
    )

    # Add drive-specific paths
    foreach ($drive in (Get-PSDrive -PSProvider FileSystem | Select-Object -ExpandProperty Root)) {
        $searchPaths += "$drive\Python*\python.exe"
        $searchPaths += "$drive\Anaconda3\python.exe"
        $searchPaths += "$drive\Miniconda3\python.exe"
    }

    # Test if a path is a valid Python executable
    function Test-PythonPath {
        param([string]$Path)

        try {
            # Check if it's a command name (not a full path)
            if ($Path -notmatch '[\\/]') {
                # For command names, use Get-Command to resolve
                $cmdInfo = Get-Command -Name $Path -ErrorAction SilentlyContinue
                if ($cmdInfo) {
                    $actualPath = $cmdInfo.Source
                    # Skip Windows Store Python launcher
                    if ($actualPath -like '*WindowsApps\python.exe') {
                        return $false
                    }
                    # Test the actual path
                    $version = & $actualPath --version 2>&1
                    return $version -match "Python"
                }
                return $false
            }
            else {
                # For full paths, test directly
                $version = & $Path --version 2>&1
                return $version -match "Python"
            }
        }
        catch {
            return $false
        }
    }

    $foundPaths = @()

    # Search all paths
    foreach ($pythonPath in $searchPaths) {
        if ($pythonPath -like '*\*') {
            # Handle wildcard paths
            try {
                $resolvedPaths = Resolve-Path -Path $pythonPath -ErrorAction SilentlyContinue
                if ($resolvedPaths) {
                    foreach ($resolvedPath in $resolvedPaths) {
                        if (Test-PythonPath -Path $resolvedPath.Path) {
                            $foundPaths += $resolvedPath.Path
                        }
                    }
                }
            }
            catch {
                continue
            }
        }
        elseif (Test-Path $pythonPath -and (Test-PythonPath -Path $pythonPath)) {
            $foundPaths += $pythonPath
        }
    }

    # Check system PATH commands (py launcher)
    foreach ($cmd in @("py")) {
        if (Test-PythonPath -Path $cmd) {
            $foundPaths += $cmd
        }
    }

    # Remove duplicates
    return @($foundPaths | Select-Object -Unique)
}

function Find-LatestPythonVersion {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$PythonPaths
    )

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

    return @{
        Python = $latestPython
        Index = $latestIndex
    }
}

function Show-PythonOptions {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$PythonPaths
    )

    Write-Host ""
    $msgKey = "multiple_python_found"
    Write-LogInfo $msgKey
    
    for ($i = 0; $i -lt $PythonPaths.Count; $i++) {
        $ver = & $PythonPaths[$i] --version 2>&1 | Select-String "Python"
        Write-Host "  $($i + 1)). $($PythonPaths[$i]) - $($ver.Line)"
    }
    $portablePythonMsg = Get-Message 'install_portable_python'
    $portablePythonMsg = $portablePythonMsg -replace '\{0\}', $script:PYTHON_VERSION
    Write-Host "  $($PythonPaths.Count + 1)). $portablePythonMsg" -ForegroundColor Cyan
    Write-Host ""
}

function Handle-PythonSelection {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$PythonPaths,
        [Parameter(Mandatory = $true)]
        [int]$LatestIndex,
        [bool]$SkipVerification = $false
    )

    $msgKey = "select_python"
    $msg = Get-Message $msgKey
    $formatted = $msg -f $PythonPaths.Count, ($LatestIndex + 1), ($PythonPaths.Count + 1)
    Write-Host $formatted -NoNewline -ForegroundColor Yellow
    $choice = Read-Host

    if ([string]::IsNullOrEmpty($choice)) {
        # Use default (latest)
        return [string]$PythonPaths[$LatestIndex]
    }
    else {
        try {
            $choiceInt = [int]$choice
        }
        catch {
            # Invalid input (non-numeric), use default
            Write-LogWarning "python_not_found" ""
            return [string]$PythonPaths[$LatestIndex]
        }

        if ($choiceInt -ge 1 -and $choiceInt -le $PythonPaths.Count) {
            return [string]$PythonPaths[$choiceInt - 1]
        }
        elseif ($choiceInt -eq ($PythonPaths.Count + 1)) {
            # Install portable Python
            Write-Host ""
            Write-LogInfo "installing_portable_python" $PYTHON_VERSION

            # Install portable Python (don't remove existing since Main function already did it, skip verification)
            Install-Python -UseCNMirror $script:Config.UseCN -RemoveExisting $false -SkipVerification $SkipVerification

            # Return the portable Python path
            $portablePython = Join-Path $env:ENV_ROOT "python\python.exe"
            return [string]$portablePython
        }
        else {
            # Invalid choice, use default
            return [string]$PythonPaths[$LatestIndex]
        }
    }
}

function Select-PythonInstallation {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$PythonPaths,
        [bool]$SkipVerification = $false
    )

    # If -P flag is set, skip Python selection (will use portable Python later)
    if ($script:Config.UseEmbedPython) {
        return $null
    }

    # Check if portable Python is already installed (user just installed it)
    $portablePythonPath = Join-Path $env:ENV_ROOT "python\python.exe"
    if (Test-Path $portablePythonPath) {
        # Portable Python already exists, skip system Python selection
        return $null
    }

    if ($PythonPaths.Count -eq 0) {
        return $null
    }

    # Find the latest version to use as default
    $latestInfo = Find-LatestPythonVersion -PythonPaths $PythonPaths
    $latestPython = $latestInfo.Python
    $latestIndex = $latestInfo.Index

    # In auto mode, automatically select the latest version
    if ($script:Config.AutoMode) {
        $msgKey = "auto_selected"
        $msg = Get-Message $msgKey
        $formatted = $msg -f $latestPython
        Write-Host $formatted -ForegroundColor Yellow
        return [string]$latestPython
    }
    else {
        # Interactive mode, let user choose
        Show-PythonOptions -PythonPaths $PythonPaths
        $selectedPython = Handle-PythonSelection -PythonPaths $PythonPaths -LatestIndex $latestIndex -SkipVerification $SkipVerification
        return $selectedPython
    }
}
function Get-PythonVersionString {
    param([Parameter(Mandatory = $true)][string]$PythonPath)

    $maxRetries = 3
    $retryDelay = 1

    for ($i = 0; $i -lt $maxRetries; $i++) {
        try {
            $versionOutput = & $PythonPath --version 2>&1
            $version = $versionOutput | Select-String "Python"
            if ($version) {
                return $version.Line -replace 'Python ', ''
            }
        }
        catch {
            # Python may need time to initialize
        }
        if ($i -lt $maxRetries - 1) {
            Start-Sleep -Seconds $retryDelay
        }
    }
    return $null
}

function Test-PythonVersion {
    param([Parameter(Mandatory = $true)][string]$VersionString)

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
# UI Functions
# Show-Banner: Display installation banner

function Show-Banner {
    Write-Host ""
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host "   $(Get-Message 'banner_title')   " -ForegroundColor Cyan
    Write-Host "============================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Installation Process Functions
# Ensure-Dependencies: Ensure Python and Git are installed
# Setup-Repositories: Setup repositories
# Prompt-Pyocd: Prompt for pyocd installation

function Ensure-Python {
    # Find system Python installations
    $pythonPaths = Find-SystemPython

    # Select Python installation (or install portable)
    $selectedPython = Select-PythonInstallation -PythonPaths $pythonPaths

    if ($selectedPython) {
        # User selected a Python (system or just installed portable)
        $script:Config.SelectedPython = $selectedPython

        # Check if it's portable Python (just installed)
        $portablePythonPath = Join-Path $env:ENV_ROOT "python\python.exe"
        if ($selectedPython -eq $portablePythonPath) {
            Write-LogInfo "using_portable_python" $script:PYTHON_VERSION
            return
        }

        # It's a system Python, verify version
        $pythonVersion = Get-PythonVersionString -PythonPath $selectedPython
        if ($pythonVersion -and (Test-PythonVersion -VersionString $pythonVersion)) {
            Write-LogInfo "using_system_python" $pythonVersion $selectedPython
            return
        }

        # System Python version is too low
        Write-LogInfo "python_version_too_low" $pythonVersion
    }
    else {
        # No Python found or user didn't select anything
        Write-LogInfo "python_not_found"
    }

    # Install portable Python
    Write-LogInfo "installing_portable_python" $script:PYTHON_VERSION
    $script:Config.SelectedPython = Install-Python -UseCNMirror $script:Config.UseCN -SkipLongPath $parsedArgs.SkipLongPath -SkipVerification $true -RemoveExisting $false
    Write-LogInfo "using_portable_python" $script:PYTHON_VERSION
}

function Ensure-Git {
    # Check and install Git if missing
    if (-not (Test-Command "git")) {
        Write-LogInfo "git_not_found"
        # When -y is used, install Git silently; otherwise show interactive installer
        Install-Git -UseCNMirror $script:Config.UseCN -Interactive (-not $script:Config.AutoMode)
        Write-Host ""
        Write-LogWarning "restart_required"
        Read-Host -Prompt "Press Enter to exit..."
        exit 0
    }

    $gitVersion = git --version 2>&1
    $gitVersion = $gitVersion.Trim()
    Write-LogSuccess "git_found" $gitVersion
}

function Ensure-Dependencies {
    Ensure-Python
    Ensure-Git
}

# Remove-PortablePython function
# Remove portable Python if exists (only called when not forcing portable Python installation)
function Remove-PortablePython {
    $portablePythonPath = "$env:ENV_ROOT\python"
    if (Test-Path $portablePythonPath) {
        Write-LogInfo "removing_portable_python" $portablePythonPath
        Remove-Item -Path $portablePythonPath -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# Invoke-TouchEnv function
# Download and execute touch_env.py to handle Step 5-10
function Invoke-TouchEnv {
    param(
        [string]$ScriptContent
    )

    try {
        # Save touch_env.py to temp file first
        $touchEnvTempFile = Join-Path $env:TEMP "touch_env.py"
        Add-TempFile -FilePath $touchEnvTempFile
        Set-Content -Path $touchEnvTempFile -Value $scriptContent -Encoding UTF8

        # Build arguments list
        # Note: Boolean parameters (--use-cn, --auto-mode, --install-pyocd) use action='store_true' in Python
        # Only pass the flag if value is $true, otherwise omit it
        $pythonArgs = @($touchEnvTempFile)
        $pythonArgs += "--env-root", $env:ENV_ROOT
        if ($script:Config.UseCN) { $pythonArgs += "--use-cn" }
        $pythonArgs += "--language", $script:Config.LangCurrent
        if ($script:Config.AutoMode) { $pythonArgs += "--auto-mode" }
        if ($script:Config.InstallPyocd) { $pythonArgs += "--install-pyocd" }

        # Pass custom repositories as individual parameters
        if ($script:Config.CustomEnvRepo) {
            $pythonArgs += "--repo-env", $script:Config.CustomEnvRepo
            if ($script:Config.CustomEnvBranch) {
                $pythonArgs += "--branch-env", $script:Config.CustomEnvBranch
            }
        }

        if ($script:Config.CustomPackagesRepo) {
            $pythonArgs += "--repo-packages", $script:Config.CustomPackagesRepo
            if ($script:Config.CustomPackagesBranch) {
                $pythonArgs += "--branch-packages", $script:Config.CustomPackagesBranch
            }
        }

        if ($script:Config.CustomSdkRepo) {
            $pythonArgs += "--repo-sdk", $script:Config.CustomSdkRepo
            if ($script:Config.CustomSdkBranch) {
                $pythonArgs += "--branch-sdk", $script:Config.CustomSdkBranch
            }
        }

        # Run touch_env.py
        $process = Start-Process -FilePath $script:Config.SelectedPython -ArgumentList $pythonArgs -Wait -NoNewWindow -PassThru -RedirectStandardOutput "$env:TEMP\touch_env_output.txt" -RedirectStandardError "$env:TEMP\touch_env_error.txt"
        $touchEnvExitCode = $process.ExitCode

        if ($touchEnvExitCode -ne 0) {
            Write-LogError "touch_env_failed" $touchEnvExitCode
            # Show error output if available
            if (Test-Path "$env:TEMP\touch_env_error.txt") {
                $errorOutput = Get-Content "$env:TEMP\touch_env_error.txt" -Raw
                if ($errorOutput) {
                    Write-Host $errorOutput -ForegroundColor Red
                }
            }
            exit $touchEnvExitCode
        }
    }
    catch {
        Write-LogError "touch_env_download_failed" $_.Exception.Message
        exit 1
    }
}

# Initialize-Installation function
# Initialize installation environment and validate settings
function Initialize-Installation {
    param(
        [PSCustomObject]$ParsedArgs
    )

    # Set config from parsed arguments
    $script:Config.LangCurrent = if ($parsedArgs.ZhMode) { "zh" } elseif ($parsedArgs.EnMode) { "en" } else { Get-SystemLanguage }
    $script:Config.UseCN = $parsedArgs.CnMode
    $script:Config.UseCNSet = $parsedArgs.CnMode -or $parsedArgs.OfficialMode
    $script:Config.InstallPyocd = $parsedArgs.PyocdMode
    $script:Config.AutoMode = $parsedArgs.AutoMode
    $script:Config.NeedHelp = $parsedArgs.HelpMode
    $script:Config.UseEmbedPython = $parsedArgs.PythonMode
    $script:Config.CustomPackagesRepo = $parsedArgs.CustomPackagesRepo
    $script:Config.CustomPackagesBranch = $parsedArgs.CustomPackagesBranch
    $script:Config.CustomEnvRepo = $parsedArgs.CustomEnvRepo
    $script:Config.CustomEnvBranch = $parsedArgs.CustomEnvBranch
    $script:Config.CustomSdkRepo = $parsedArgs.CustomSdkRepo
    $script:Config.CustomSdkBranch = $parsedArgs.CustomSdkBranch

    # Set ENV_ROOT and validate
    if ($parsedArgs.EnvRootValue) { $env:ENV_ROOT = $parsedArgs.EnvRootValue }
    if ($env:ENV_ROOT -match "\s") {
        Write-LogError "env_root_invalid" "spaces"
        exit 1
    }
    if ($env:ENV_ROOT -match "[^\x00-\x7F]") {
        Write-LogError "env_root_invalid" "non-ASCII characters"
        exit 1
    }

    # Check administrator privileges for auto mode
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    if ($parsedArgs.AutoMode -and -not $isAdmin -and -not $parsedArgs.SkipLongPath) {
        Write-LogError "admin_required"
        Write-LogWarning "run_as_admin"
        exit 1
    }

    # Handle help request
    if ($script:Config.NeedHelp) {
        Print-Help
        return
    }

    # Detect China mirror if not explicitly set
    if (-not $script:Config.UseCNSet) {
        $script:Config.UseCN = Detect-China
    }

    # Override with --official flag
    if ($parsedArgs.OfficialMode) {
        $script:Config.UseCN = $false
    }
}

# Main Function
# Main function: Coordinate all installation steps

function Main {
    # Initialize installation environment
    Initialize-Installation -ParsedArgs $parsedArgs

    # Step 1: Print installation banner
    Show-Banner

    # Step 2: Ensure Python and Git are installed
    Ensure-Dependencies

    # Step 3: Remove old portable Python if exists (only when not forcing portable Python installation with -p)
    if (-not $script:Config.UseEmbedPython) {
        $portablePythonPath = Join-Path $env:ENV_ROOT "python\python.exe"
        # Only remove if user selected a system Python (not the portable one we just installed)
        if ($script:Config.SelectedPython -and $script:Config.SelectedPython -ne $portablePythonPath) {
            Remove-PortablePython
        }
    }

    # Set touch_env.py download URL
    $TOUCH_ENV_URL = $TOUCH_ENV_URL_GITHUB
    if ($script:Config.UseCN) {
        $TOUCH_ENV_URL = $TOUCH_ENV_URL_GITEE
    }
    if ($parsedArgs.TouchEnvUrlValue) {
        $TOUCH_ENV_URL = $parsedArgs.TouchEnvUrlValue
    }
    elseif ($script:Config.CustomEnvRepo) {
        # Use custom env repo for touch_env.py download
        $TOUCH_ENV_URL = $script:Config.CustomEnvRepo + "/raw/" + ($script:Config.CustomEnvBranch -replace "refs/heads/", "") + "/touch_env.py"
    }

    # Download touch_env.py from network
    Write-Host ""
    Write-LogInfo "downloading_touch_env" $TOUCH_ENV_URL
    $scriptContent = $null

    try {
        # Try with SSL verification first
        $response = Invoke-WebRequest -Uri $TOUCH_ENV_URL -UseBasicParsing -ErrorAction Stop
        $scriptContent = $response.Content
    }
    catch {
        # If SSL error, try without SSL verification
        if ($_.Exception.Message -match "SSL" -or $_.Exception.Message -match "certificate") {
            Write-LogWarning "SSL verification failed, retrying without verification..."
            try {
                $response = Invoke-WebRequest -Uri $TOUCH_ENV_URL -UseBasicParsing -SkipCertificateCheck -ErrorAction Stop
                $scriptContent = $response.Content
            }
            catch {
                Write-LogError "touch_env_download_failed" $_.Exception.Message
                Write-Host ""
                Write-Host "Please check:" -ForegroundColor Yellow
                Write-Host "  1. Your internet connection" -ForegroundColor Yellow
                Write-Host "  2. The URL is correct: $TOUCH_ENV_URL" -ForegroundColor Yellow
                Write-Host "  3. Try using -t parameter to specify a different URL" -ForegroundColor Yellow
                exit 1
            }
        }
        else {
            Write-LogError "touch_env_download_failed" $_.Exception.Message
            Write-Host ""
            Write-Host "Please check:" -ForegroundColor Yellow
            Write-Host "  1. Your internet connection" -ForegroundColor Yellow
            Write-Host "  2. The URL is correct: $TOUCH_ENV_URL" -ForegroundColor Yellow
            Write-Host "  3. Try using -t parameter to specify a different URL" -ForegroundColor Yellow
            exit 1
        }
    }

    # Step 4: Call touch_env.py to handle Step 5-10
    Invoke-TouchEnv -ScriptContent $scriptContent
}

Main
