# RT-Thread Environment Directory
# Can be overridden by $env:ENV_ROOT environment variable
$env:ENV_ROOT = if ($env:ENV_ROOT) { $env:ENV_ROOT } else { "$env:USERPROFILE\.rtenv" }

# Virtual environment directory name
$env:RT_VENV_DIR = if ($env:RT_VENV_DIR) { $env:RT_VENV_DIR } else { "$env:ENV_ROOT\venv\rt-env" }

if (Test-Path "$env:RT_VENV_DIR\Scripts\Activate.ps1") {
    . "$env:RT_VENV_DIR\Scripts\Activate.ps1"
} else {
    Write-Host "Virtual environment($env:RT_VENV_DIR\Scripts\Activate.ps1) not found. Please run the installation script first."
    exit 1
}

$env:pathext = ".PS1;$env:pathext"
