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

# ============================================================================
# Global Constants
# ============================================================================

# Environment Configuration
$ENV_DEFAULT_DIR = "$env:USERPROFILE\.rtenv"

# touch_env.py download URLs
$TOUCH_ENV_URL_GITHUB = "https://raw.githubusercontent.com/RT-Thread/env/master/touch_env.py"
$TOUCH_ENV_URL_GITEE = "https://gitee.com/RT-Thread-Mirror/env/raw/master/touch_env.py"

# Python Configuration
$PYTHON_VERSION = "3.13.11"
$PYTHON_ARCHIVE = "python-${PYTHON_VERSION}-amd64.zip"
$PYTHON_URL_DEFAULT = "https://www.python.org/ftp/python/$PYTHON_VERSION/$PYTHON_ARCHIVE"
$PYTHON_URL_CN = "https://registry.npmmirror.com/-/binary/python/$PYTHON_VERSION/$PYTHON_ARCHIVE"

# Git Configuration
$GIT_FALLBACK_VERSION = "v2.52.0.windows.1"
$GIT_FALLBACK_URL = "https://github.com/git-for-windows/git/releases/download/$GIT_FALLBACK_VERSION/Git-${GIT_FALLBACK_VERSION}-64-bit.exe"
$GIT_GITHUB_API_URL = "https://api.github.com/repos/git-for-windows/git/releases/latest"
$GIT_NPMMIRROR_URL = "https://registry.npmmirror.com/-/binary/git-for-windows/"

# IP Detection Configuration
$IPINFO_URL = "https://ipinfo.io/json"

# ============================================================================
# Helper Functions
# ============================================================================

# New-Repo function
# Create a repository configuration object
function New-Repo {
    param(
        [string]$Repo = "",
        [string]$Branch = ""
    )
    return [PSCustomObject]@{
        Repo   = $Repo
        Branch = $Branch
    }
}

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
        return New-Repo -Repo $parts[0].Trim() -Branch $parts[1].Trim()
    }
    else {
        return New-Repo -Repo $RepoArg.Trim()
    }
}

# Parse-Arguments function
# Parse command line arguments and return parsed values
function Parse-Arguments {
    param([string[]]$Arguments)

    $result = [PSCustomObject]@{
        AutoMode         = $false
        HelpMode         = $false
        CnMode           = $false
        OfficialMode     = $false
        PyocdMode        = $false
        PythonMode       = $false
        EnMode           = $false
        ZhMode           = $false
        SkipLongPath     = $false
        EnvRootValue     = ""
        CustomPackages   = New-Repo
        CustomEnv        = New-Repo
        CustomSdk        = New-Repo
        TouchEnvUrlValue = ""
    }

    for ($i = 0; $i -lt $Arguments.Count; $i++) {
        $arg = $Arguments[$i]
        switch -CaseSensitive ($arg) {
            "-y" { $result.AutoMode = $true }
            "--yes" { $result.AutoMode = $true }
            "--auto" { $result.AutoMode = $true }
            "-h" { $result.HelpMode = $true }
            "--help" { $result.HelpMode = $true }
            "-c" { $result.CnMode = $true }
            "--cn" { $result.CnMode = $true }
            "--gitee" { $result.CnMode = $true }
            "-o" { $result.OfficialMode = $true }
            "--official" { $result.OfficialMode = $true }
            "-d" { $result.PyocdMode = $true }
            "--pyocd" { $result.PyocdMode = $true }
            "-p" { $result.PythonMode = $true }
            "--python" { $result.PythonMode = $true }
            "-E" {
                $result.CustomEnv = Parse-RepoArg -RepoArg $Arguments[++$i]
            }
            "--env" {
                $result.CustomEnv = Parse-RepoArg -RepoArg $Arguments[++$i]
            }
            "-e" { $result.EnMode = $true }
            "--en" { $result.EnMode = $true }
            "--english" { $result.EnMode = $true }
            "-z" { $result.ZhMode = $true }
            "--zh" { $result.ZhMode = $true }
            "--chinese" { $result.ZhMode = $true }
            "-r" { $result.EnvRootValue = $Arguments[++$i] }
            "--env-root" { $result.EnvRootValue = $Arguments[++$i] }
            "-P" {
                $result.CustomPackages = Parse-RepoArg -RepoArg $Arguments[++$i]
            }
            "--packages" {
                $result.CustomPackages = Parse-RepoArg -RepoArg $Arguments[++$i]
            }
            "-S" {
                $result.CustomSdk = Parse-RepoArg -RepoArg $Arguments[++$i]
            }
            "--sdk" {
                $result.CustomSdk = Parse-RepoArg -RepoArg $Arguments[++$i]
            }
            "-l" { $result.SkipLongPath = $true }
            "--skip-long-path" { $result.SkipLongPath = $true }
            "-t" { $result.TouchEnvUrlValue = $Arguments[++$i] }
            "--touch-env-url" { $result.TouchEnvUrlValue = $Arguments[++$i] }
        }
    }

    return $result
}

# Register-CleanupHandler function
# Register-CleanupHandler function
# Register cleanup handler for temporary files
# This ensures temporary files are cleaned up even if the script exits unexpectedly
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

# Register cleanup handler immediately when script loads
# This ensures cleanup happens regardless of where/when the script exits
# (before Main(), during parameter validation, or after installation)

# Add-TempFile function
# Track temporary file for cleanup
# Called whenever a temporary file is created to ensure it gets cleaned up on exit
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
        banner_title                     = "RT-Thread ENV Installation"
        info                             = "INFO"
        success                          = "SUCCESS"
        warning                          = "WARNING"
        error                            = "ERROR"
        python_version_too_low           = "Python version {0} is too old (requires >= 3.6). Installing portable Python..."
        missing_python                   = "Python not found. Please install Python first."
        using_system_python              = "Using system Python: {0} - {1}"
        using_portable_python            = "Will use portable Python {0}..."
        installing_portable_python       = "Installing portable Python {0}..."
        downloading_portable_python      = "Downloading portable Python, from: {0}"
        python_installed                 = "Python installed successfully."
        python_version_failed            = "Failed to get Python version. Installing portable Python..."
        python_verification_failed       = "Python verification failed. Installation may be corrupted."
        downloading_git                  = "Downloading Git..."
        installing_git                   = "Installing Git..."
        git_installed                    = "Git installed. Please restart terminal and run this script again."
        admin_required                   = "Error: The -y/--yes flag requires administrator privileges."
        run_as_admin                     = "Please run this script as administrator."
        fetching_git_from_npmmirror      = "Fetching Git version from npmmirror..."
        fetching_git_from_github         = "Fetching Git version from GitHub API..."
        git_version_found                = "Git version found: {0}"
        npmmirror_fetch_failed           = "Failed to fetch Git version from npmmirror, trying GitHub API..."
        download_failed                  = "Download failed: {0}"
        github_api_failed                = "GitHub API request failed, using fallback version..."
        using_fixed_git_version          = "Using fixed Git version: {0}"
        restart_required                 = "Please restart terminal and run this script again to continue."
        git_not_found                    = "Git is not installed. Please install Git first."
        git_found                        = "Git found: {0}"
        enabling_long_paths              = "Enabling Windows long path support..."
        long_paths_enabled               = "Windows long path support enabled"
        long_paths_enable_failed         = "Failed to enable long path support (may require admin privileges)"
        need_admin_privilege             = "Enabling long paths requires administrator privileges"
        elevating_to_enable_long_paths   = "Attempting to enable long paths (UAC prompt may appear)"
        install_portable_python          = "Install portable Python - Python {0}"
        multiple_python_found            = "Multiple Python installations found:"
        select_python                    = "Found {0} Python installation(s). Default is option {1} (latest). Select [1-{0}], or {2} to install portable Python: "
        auto_selected                    = "Auto-selected Python: {0}"
        python_not_found                 = "Python not found. Please install Python first."
        env_root_invalid                 = "Error: ENV_ROOT cannot contain {0}"
        removing_portable_python         = "Removing portable Python: {0}..."
        removing_old_portable_python     = "Removing old portable Python: {0}..."
        removing_invalid_portable_python = "Removing invalid portable Python: {0}..."
        python_not_found_or_invalid      = "Python not found or invalid. Installing portable Python..."
        downloading_touch_env            = "Downloading touch_env.py from: {0}"
        touch_env_downloaded             = "touch_env.py downloaded successfully."
        touch_env_failed                 = "touch_env.py execution failed with exit code: {0}"
        touch_env_download_failed        = "Failed to download touch_env.py: {0}"
        python_pth_config_failed         = "Warning: Failed to configure Python _pth file. site-packages may not be available."
        python_ready                     = "Python ready: {0} (version {1})"
        python_setup_failed              = "Python setup failed with error code: {0}"
        mirror_selection                 = "Using mirror: {0}"
        china_mirror                     = "China (Gitee, npmmirror)"
        official_mirror                  = "Official (GitHub, PyPI)"
        check_list                       = "Please check:"
        check_list_connection            = "  1. Your internet connection"
        check_list_url                   = "  2. The URL is correct: {0}"
        check_list_alt_url               = "  3. Try using -t parameter to specify a different URL"
    }
    zh = @{
        banner_title                     = "RT-Thread ENV 安装程序"
        info                             = "信息"
        success                          = "成功"
        warning                          = "警告"
        error                            = "错误"
        python_version_too_low           = "Python 版本 {0} 过低（需要 >= 3.6）。将安装便携式 Python..."
        missing_python                   = "未安装 Python。请先安装 Python。"
        using_system_python              = "使用系统 Python: {0} - {1}"
        using_portable_python            = "将使用便携式 Python {0}..."
        installing_portable_python       = "正在安装便携式 Python {0}..."
        downloading_portable_python      = "正在下载便携式 Python，自: {0}"
        python_installed                 = "Python 已安装成功。"
        python_version_failed            = "无法获取 Python 版本。正在安装便携式 Python..."
        python_verification_failed       = "Python 验证失败。安装可能已损坏。"
        downloading_git                  = "正在下载 Git..."
        installing_git                   = "正在安装 Git..."
        git_installed                    = "Git 已安装。请重新启动终端并再次运行此脚本。"
        admin_required                   = "错误: -y/--yes 参数需要管理员权限。"
        run_as_admin                     = "请以管理员身份运行此脚本。"
        fetching_git_from_npmmirror      = "正在从 npmmirror 获取 Git 版本..."
        fetching_git_from_github         = "正在从 GitHub API 获取 Git 版本..."
        git_version_found                = "找到 Git 版本: {0}"
        npmmirror_fetch_failed           = "从 npmmirror 获取 Git 版本失败，尝试 GitHub API..."
        download_failed                  = "下载失败: {0}"
        github_api_failed                = "GitHub API 请求失败，使用备选版本..."
        using_fixed_git_version          = "使用固定 Git 版本: {0}"
        restart_required                 = "请重新启动终端并再次运行此脚本以继续。"
        git_not_found                    = "未安装 Git。请先安装 Git。"
        git_found                        = "找到 Git: {0}"
        enabling_long_paths              = "正在启用 Windows 长路径支持..."
        long_paths_enabled               = "Windows 长路径支持已启用"
        long_paths_enable_failed         = "启用长路径支持失败（可能需要管理员权限）"
        need_admin_privilege             = "启用长路径需要管理员权限"
        elevating_to_enable_long_paths   = "正在尝试启用长路径（可能会弹出 UAC 提示）"
        install_portable_python          = "安装便携式 Python - Python {0}"
        multiple_python_found            = "找到多个 Python 安装："
        select_python                    = "找到 {0} 个 Python 安装。默认选项为 {1}（最新）。选择 [1-{0}]，或输入 {2} 安装便携式 Python: "
        auto_selected                    = "自动选择 Python: {0}"
        python_not_found                 = "未找到 Python。请先安装 Python。"
        env_root_invalid                 = "错误: ENV_ROOT 不能包含 {0}"
        removing_portable_python         = "正在删除便携式 Python: {0}..."
        removing_old_portable_python     = "正在删除旧的便携式 Python: {0}..."
        removing_invalid_portable_python = "正在删除无效的便携式 Python: {0}..."
        python_not_found_or_invalid      = "未找到 Python 或 Python 无效。正在安装便携式 Python..."
        downloading_touch_env            = "正在下载 touch_env.py，自: {0}"
        touch_env_downloaded             = "touch_env.py 下载完成。"
        touch_env_failed                 = "touch_env.py 执行失败，退出码: {0}"
        touch_env_download_failed        = "下载 touch_env.py 失败: {0}"
        python_pth_config_failed         = "警告: 配置 Python _pth 文件失败。site-packages 可能不可用。"
        python_ready                     = "Python 已就绪: {0} (版本 {1})"
        python_setup_failed              = "Python 设置失败，错误码: {0}"
        mirror_selection                 = "使用镜像: {0}"
        china_mirror                     = "中国（Gitee, npmmirror）"
        official_mirror                  = "官方（GitHub, PyPI）"
        check_list                       = "请检查:"
        check_list_connection            = "  1. 您的网络连接"
        check_list_url                   = "  2. URL 是否正确: {0}"
        check_list_alt_url               = "  3. 尝试使用 -t 参数指定不同的 URL"
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
    }
    elseif ($null -ne $Arg1) {
        $msg -f $Arg1
    }
    else {
        $msg
    }
    Write-Host "[$(Get-Message 'info')] $formatted" -ForegroundColor Cyan
}

function Write-LogSuccess {
    param([string]$Key, [string]$Arg1, [string]$Arg2)
    $msg = Get-Message $Key
    $formatted = if ($null -ne $Arg1 -and $null -ne $Arg2) {
        $msg -f $Arg1, $Arg2
    }
    elseif ($null -ne $Arg1) {
        $msg -f $Arg1
    }
    else {
        $msg
    }
    Write-Host "[$(Get-Message 'success')] $formatted" -ForegroundColor Green
}

function Write-LogWarning {
    param([string]$Key, [string]$Arg1, [string]$Arg2)
    $msg = Get-Message $Key
    $formatted = if ($null -ne $Arg1 -and $null -ne $Arg2) {
        $msg -f $Arg1, $Arg2
    }
    elseif ($null -ne $Arg1) {
        $msg -f $Arg1
    }
    else {
        $msg
    }
    Write-Host "[$(Get-Message 'warning')] $formatted" -ForegroundColor Yellow
}

function Write-LogError {
    param([string]$Key, [string]$Arg1, [string]$Arg2)
    $msg = Get-Message $Key
    $formatted = if ($null -ne $Arg1 -and $null -ne $Arg2) {
        $msg -f $Arg1, $Arg2
    }
    elseif ($null -ne $Arg1) {
        $msg -f $Arg1
    }
    else {
        $msg
    }
    Write-Host "[$(Get-Message 'error')] $formatted" -ForegroundColor Red
}

# Write-LogRaw function
# Write raw message with configurable color and i18n support
function Write-LogRaw {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Key,
        
        [Parameter(Mandatory = $false)]
        [ConsoleColor]$Color = "White",
        
        [Parameter(Mandatory = $false)]
        [string]$Arg1 = "",
        
        [Parameter(Mandatory = $false)]
        [string]$Arg2 = ""
    )
    
    # Get message from dictionary (supports i18n)
    $msg = if ($script:Messages.ContainsKey($script:Config.LangCurrent) -and $script:Messages[$script:Config.LangCurrent].ContainsKey($Key)) {
        $script:Messages[$script:Config.LangCurrent][$Key]
    }
    else {
        $Key  # Fallback to the key itself if not found in dictionary
    }
    
    # Format message with arguments if provided
    $formatted = if ($null -ne $Arg1 -and $null -ne $Arg2 -and $Arg1 -ne "" -and $Arg2 -ne "") {
        $msg -f $Arg1, $Arg2
    }
    elseif ($null -ne $Arg1 -and $Arg1 -ne "") {
        $msg -f $Arg1
    }
    else {
        $msg
    }
    
    Write-Host $formatted -ForegroundColor $Color
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

class PythonConfig {
    [bool]$InstallPortablePython
    [string]$PythonPath
    [string]$Version
    [int]$Result
}
function New-PythonConfig {
    return [PythonConfig] @{
        InstallPortablePython = $false
        PythonPath            = ""
        Version               = ""
        Result                = 0
    }
}

function New-PortingPythonConfig {
    return [PythonConfig] @{
        InstallPortablePython = $true
        PythonPath            = Join-Path $env:ENV_ROOT "python\python.exe"
        Version               = $PYTHON_VERSION
        Result                = 0
    }
}

function Check-Python {
    param(
        [Parameter(Mandatory = $true)]
        [PythonConfig]$PythonConfig
    )

    $result = New-PortingPythonConfig
    # Check if Python.exe exists
    if (-not (Test-Path $PythonConfig.PythonPath)) {
        Write-LogError "python_not_found" $PythonConfig.PythonPath
        $result.Result = 1
        return $result
    }

    # Get Python version
    $version = Get-PythonVersionString -PythonPath $PythonConfig.PythonPath
    if (-not $version) {
        Write-LogWarning "python_version_failed" $PythonConfig.PythonPath
        $result.Result = 2
        return $result
    }
    $PythonConfig.Version = $version

    # Check if version meets minimum requirement (>= 3.6)
    if (-not (Test-PythonVersion -VersionString $version)) {
        Write-LogError "python_version_too_old" $version
        $result.Result = 3
        return $result
    }

    # All checks passed
    return $PythonConfig
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

function Install-PortablePython {
    param(
        [bool]$UseCNMirror,
        [bool]$SkipLongPath
    )

    $result = New-PythonConfig

    try {
        Download-PortablePython -UseCNMirror $UseCNMirror
        Extract-PortablePython
        if (-not $SkipLongPath) {
            Enable-LongPathSupport
        }
        Configure-PythonPth
        # Save portable Python path to global variable
        $portablePython = Join-Path $env:ENV_ROOT "python\python.exe"
        Write-LogSuccess "python_installed"

        # Get Python version
        $version = Get-PythonVersionString -PythonPath $portablePython
        if ($version) {
            $result.PythonPath = $portablePython
            $result.Version = $version
            $result.InstallPortablePython = $true
            $result.Result = 0
        }
        else {
            $result.Result = 1
        }
    }
    catch {
        $result.Result = 1
    }

    return $result
}

# Python Environment Setup Functions
# Find-SystemPython: Find system Python
# Find-LatestPythonVersion: Find latest Python version
# Show-PythonOptions: Show Python options
# Handle-PythonSelection: Handle Python selection
# Select-Python: Select Python installation
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
        Index  = $latestIndex
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
        [int]$LatestIndex
    )

    $result = New-PythonConfig
    $result.InstallPortablePython = $false

    $msg = Get-Message "select_python"
    $formatted = $msg -f $PythonPaths.Count, ($LatestIndex + 1), ($PythonPaths.Count + 1)
    Write-Host $formatted -NoNewline -ForegroundColor Yellow
    $choice = Read-Host

    if ([string]::IsNullOrEmpty($choice)) {
        # Use default (latest)
        $result.PythonPath = $PythonPaths[$LatestIndex]
    }
    else {
        try {
            $choiceInt = [int]$choice
        }
        catch {
            # Invalid input (non-numeric), use default
            Write-LogWarning "python_not_found" ""
            $result.PythonPath = $PythonPaths[$LatestIndex]
            return $result
        }

        if ($choiceInt -ge 1 -and $choiceInt -le $PythonPaths.Count) {
            $result.PythonPath = $PythonPaths[$choiceInt - 1]
        }
        elseif ($choiceInt -eq ($PythonPaths.Count + 1)) {
            $result = New-PortingPythonConfig # Install portable Python
        }
        else {
            # Invalid choice, use default
            $result.PythonPath = $PythonPaths[$LatestIndex]
        }
    }
    return $result
}

function Select-Python {
    param(
        [Parameter(Mandatory = $true)]
        [string[]]$PythonPaths,
        [bool]$SkipVerification = $false
    )

    $result = $Script:Config.PythonConfig 

    if ($PythonPaths.Count -eq 0) {
        return $result
    }

    # Find the latest version to use as default
    $latestInfo = Find-LatestPythonVersion -PythonPaths $PythonPaths
    $latestPython = $latestInfo.Python
    $latestIndex = $latestInfo.Index
    $result.InstallPortablePython = $false

    # In auto mode, automatically select the latest version
    if ($script:Config.AutoMode) {
        $msg = Get-Message "auto_selected"
        $formatted = $msg -f $latestPython
        Write-Host $formatted -ForegroundColor Yellow
        $result.PythonPath = $latestPython
        # Get version and validate
        $version = Get-PythonVersionString -PythonPath $latestPython
        if ($version -and (Test-PythonVersion -VersionString $version)) {
            $result.Version = $version
            $result.Result = 0
        }
        else {
            $result = New-PortingPythonConfig
        }
    }
    else {
        # Interactive mode, let user choose
        Show-PythonOptions -PythonPaths $PythonPaths
        $result = Handle-PythonSelection -PythonPaths $PythonPaths -LatestIndex $latestIndex
     }

    return $result
}
function Get-PythonVersionString {
    param([Parameter(Mandatory = $true)][string]$PythonPath)

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

# Test-PythonVersion function
# Test if Python version meets minimum requirement (>= 3.6)
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

function Ensure-Python {
    $result = $script:Config.PythonConfig
    # 步骤 1: 查找选择系统 Python
    if (-not $result.InstallPortablePython) {
        $result = Select-Python -PythonPaths (Find-SystemPython)
    }

    # 步骤 2: 验证系统 Python
    if (-not $result.InstallPortablePython -and $result.PythonPath) {
        $result = Check-Python -PythonConfig $result
    }
    if ($result.InstallPortablePython ) {
        if ($result.Result -eq 0) {
            Write-LogWarning "installing_portable_python"
        }
        else {
            Write-LogWarning "python_not_found_or_invalid"
        }
    }

    # 步骤 3: 删除旧的便携式 Python
    $portablePythonDir = Join-Path $env:ENV_ROOT "python"
    if (Test-Path $portablePythonDir) {
        Write-LogInfo "removing_portable_python" $portablePythonDir
        Remove-Item -Path $portablePythonDir -Recurse -Force -ErrorAction SilentlyContinue
    }

    # 步骤 4: 安装便携式 Python（如果需要）
    if ($result.InstallPortablePython) {
        $result = Install-PortablePython -UseCNMirror $script:Config.UseCN -SkipLongPath $parsedArgs.SkipLongPath
    }

    # 步骤 5: 检查结果
    if ($result.Result -ne 0) {
        Write-LogError "python_setup_failed" $result.Result
        exit $result.Result
    }
    $Script:Config.PythonConfig = $result
    Write-LogSuccess "python_ready" $result.PythonPath $result.Version
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

# Save-TouchEnvToFile function
# Save touch_env.py script content to temporary file
function Save-TouchEnvToFile {
    param(
        [string]$ScriptContent
    )

    $touchEnvTempFile = Join-Path $env:TEMP "touch_env.py"
    Add-TempFile -FilePath $touchEnvTempFile
    Set-Content -Path $touchEnvTempFile -Value $ScriptContent -Encoding UTF8
    return $touchEnvTempFile
}

# Build-TouchEnvArgs function
# Build argument list for touch_env.py
function Build-TouchEnvArgs {
    param(
        [string]$TouchEnvFilePath
    )

    # Build arguments list
    $pythonArgs = @($TouchEnvFilePath)
    $pythonArgs += "--env-root", $env:ENV_ROOT
    if ($script:Config.UseCN) { $pythonArgs += "--use-cn" }
    $pythonArgs += "--language", $script:Config.LangCurrent
    if ($script:Config.AutoMode) { $pythonArgs += "--auto-mode" }
    if ($script:Config.InstallPyocd) { $pythonArgs += "--install-pyocd" }

    # Pass custom repositories as individual parameters
    if ($script:Config.CustomEnv.Repo) {
        $pythonArgs += "--repo-env", $script:Config.CustomEnv.Repo
        if ($script:Config.CustomEnv.Branch) {
            $pythonArgs += "--branch-env", $script:Config.CustomEnv.Branch
        }
    }

    if ($script:Config.CustomPackages.Repo) {
        $pythonArgs += "--repo-packages", $script:Config.CustomPackages.Repo
        if ($script:Config.CustomPackages.Branch) {
            $pythonArgs += "--branch-packages", $script:Config.CustomPackages.Branch
        }
    }

    if ($script:Config.CustomSdk.Repo) {
        $pythonArgs += "--repo-sdk", $script:Config.CustomSdk.Repo
        if ($script:Config.CustomSdk.Branch) {
            $pythonArgs += "--branch-sdk", $script:Config.CustomSdk.Branch
        }
    }

    return $pythonArgs
}

# Show-TouchEnvError function
# Show touch_env.py error output if available
function Show-TouchEnvError {
    $errorFile = "$env:TEMP\touch_env_error.txt"
    if (Test-Path $errorFile) {
        $errorOutput = Get-Content $errorFile -Raw
        if ($errorOutput) {
            Write-Host $errorOutput -ForegroundColor Red
        }
    }
}

# Invoke-TouchEnv function
# Download and execute touch_env.py to handle Step 5-10
function Invoke-TouchEnv {
    param(
        [string]$ScriptContent
    )

    try {
        # Save touch_env.py to temp file
        $touchEnvFile = Save-TouchEnvToFile -ScriptContent $ScriptContent

        # Build arguments list
        $pythonArgs = Build-TouchEnvArgs -TouchEnvFilePath $touchEnvFile

        # 显示"$env:TEMP\touch_env_output.txt" 的内容
        Write-Host "运行参数:  $pythonArgs" -ForegroundColor Green

        # Run touch_env.py in the same window with full interactivity
        & $script:Config.PythonConfig.PythonPath $pythonArgs
        $touchEnvExitCode = $LASTEXITCODE

        if ($touchEnvExitCode -ne 0) {
            Write-LogError "touch_env_failed" $touchEnvExitCode
            Show-TouchEnvError
            exit $touchEnvExitCode
        }
    }
    catch {
        Write-LogError "touch_env_download_failed" $_.Exception.Message
        exit 1
    }
}

# Init-Config function
# Initialize installation environment and validate settings
function Init-Config {
    param(
        [PSCustomObject]$ParsedArgs
    )

    # Set strict mode and error handling
    Set-StrictMode -Version Latest
    $ErrorActionPreference = "Stop"

    # Register cleanup handler
    Register-CleanupHandler

    # Set ENV_ROOT
    $env:ENV_ROOT = if ($env:ENV_ROOT) { $env:ENV_ROOT } else { $ENV_DEFAULT_DIR }

    # Initialize global config
    $script:Config = [PSCustomObject]@{
        LangCurrent    = ""
        UseCN          = $false
        UseCNSet       = $false
        InstallPyocd   = $false
        AutoMode       = $false
        NeedHelp       = $false
        CustomPackages = New-Repo
        CustomEnv      = New-Repo
        CustomSdk      = New-Repo
        PythonConfig   = New-PythonConfig
        TempFiles      = @()
    }

    # Set config from parsed arguments
    $script:Config.LangCurrent = if ($ParsedArgs.ZhMode) { "zh" } elseif ($ParsedArgs.EnMode) { "en" } else { Get-SystemLanguage }
    $script:Config.UseCN = $ParsedArgs.CnMode
    $script:Config.UseCNSet = $ParsedArgs.CnMode -or $ParsedArgs.OfficialMode
    $script:Config.InstallPyocd = $ParsedArgs.PyocdMode
    $script:Config.AutoMode = $ParsedArgs.AutoMode
    $script:Config.NeedHelp = $ParsedArgs.HelpMode
    $script:Config.CustomPackages = $ParsedArgs.CustomPackages
    $script:Config.CustomEnv = $ParsedArgs.CustomEnv
    $script:Config.CustomSdk = $ParsedArgs.CustomSdk

    # Initialize PythonConfig
    if ($ParsedArgs.PythonMode) {
        $script:Config.PythonConfig = New-PortingPythonConfig
    }

    # Set ENV_ROOT and validate
    if ($ParsedArgs.EnvRootValue) { $env:ENV_ROOT = $ParsedArgs.EnvRootValue }
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
    if ($ParsedArgs.AutoMode -and -not $isAdmin -and -not $ParsedArgs.SkipLongPath) {
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
    $mirrorType = if ($script:Config.UseCN) { "china_mirror" } else { "official_mirror" }
    Write-LogInfo "mirror_selection" (Get-Message $mirrorType)

    # Override with --official flag
    if ($ParsedArgs.OfficialMode) {
        $script:Config.UseCN = $false
    }
}

# Show-DownloadError function
# Show download error message with checklist
function Show-DownloadError {
    param(
        [string]$Url
    )

    Write-Host ""
    Write-LogRaw "check_list" -Color Yellow
    Write-LogRaw "check_list_connection" -Color Yellow
    Write-LogRaw "check_list_url" -Color Yellow -Arg1 $Url
    Write-LogRaw "check_list_alt_url" -Color Yellow
}

# Download-TouchEnv function
# Download touch_env.py script from network with fallback handling
function Download-TouchEnv {
    param(
        [PSCustomObject]$ParsedArgs
    )

    # Set touch_env.py download URL (priority: -t > --env > UseCN/Gitee > GitHub)
    if ($ParsedArgs.TouchEnvUrlValue) {
        $TOUCH_ENV_URL = $ParsedArgs.TouchEnvUrlValue
    }
    elseif ($script:Config.CustomEnv.Repo) {
        # Use custom env repo for touch_env.py download
        # Convert GitHub repo URL to raw.githubusercontent.com URL
        $repo = $script:Config.CustomEnv.Repo
        $branch = $script:Config.CustomEnv.Branch

        if ($repo -match "^https?://github\.com/([^/]+)/([^/]+?)(\.git)?$") {
            # GitHub repository: https://github.com/owner/repo -> https://raw.githubusercontent.com/owner/repo/refs/heads/branch/file
            $owner = $Matches[1]
            $repoName = $Matches[2] -replace '\.git$', ''
            # Ensure branch has refs/heads/ prefix for GitHub raw URLs
            # if (-not $branch.StartsWith("refs/heads/")) {
            #     $branch = "refs/heads/$branch"
            # }
            $TOUCH_ENV_URL = "https://raw.githubusercontent.com/$owner/$repoName/$branch/touch_env.py"
        }
        else {
            # Non-GitHub repository: use /raw/ format
            $TOUCH_ENV_URL = "$repo/raw/$branch/touch_env.py"
        }
    }
    elseif ($script:Config.UseCN) {
        $TOUCH_ENV_URL = $TOUCH_ENV_URL_GITEE
    }
    else {
        $TOUCH_ENV_URL = $TOUCH_ENV_URL_GITHUB
    }

    # Download touch_env.py from network
    Write-Host ""
    Write-LogInfo "downloading_touch_env" $TOUCH_ENV_URL
    $scriptContent = $null

    try {
        # Try with SSL verification first
        $response = Invoke-WebRequest -Uri $TOUCH_ENV_URL -UseBasicParsing -ErrorAction Stop
        $scriptContent = $response.Content
        Write-LogInfo "touch_env_downloaded"
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
                Show-DownloadError -Url $TOUCH_ENV_URL
                exit 1
            }
        }
        else {
            Write-LogError "touch_env_download_failed" $_.Exception.Message
            Show-DownloadError -Url $TOUCH_ENV_URL
            exit 1
        }
    }

    return $scriptContent
}

# Main Function
# Main function: Coordinate all installation steps
function Main {
    # Parse command line arguments
    $parsedArgs = Parse-Arguments -Arguments $args

    # Initialize configuration
    Init-Config -ParsedArgs $parsedArgs

    # Step 1: Print installation banner
    Show-Banner

    # Step 2: Ensure Python and Git are installed
    Ensure-Python
    Ensure-Git

    # Step 3: Download touch_env.py
    $scriptContent = Download-TouchEnv -ParsedArgs $parsedArgs

    # Step 4: Call touch_env.py to handle Step 5-10
    Invoke-TouchEnv -ScriptContent $scriptContent
}

# Execute main function
Main @args
