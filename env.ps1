# RT-Thread Environment Directory
# Can be overridden by $env:ENV_ROOT environment variable
$env:ENV_ROOT = if ($env:ENV_ROOT) { $env:ENV_ROOT } else { "$env:USERPROFILE\.env" }

# Virtual environment directory name
$Global:VENV_DIR = if ($env:VENV_DIR) { $env:VENV_DIR } else { "rt-venv" }

if (Test-Path "$env:ENV_ROOT\$Global:VENV_DIR\Scripts\Activate.ps1") {
    & "$env:ENV_ROOT\$Global:VENV_DIR\Scripts\Activate.ps1"
} else {
    Write-Host "Virtual environment not found. Please run the installation script first."
    exit 1
}

$env:pathext = ".PS1;$env:pathext"
