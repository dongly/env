[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::InputEncoding = [System.Text.Encoding]::UTF8

# ENV_ROOT resolution (see env.sh): tools\scripts layout detection >
# this file's directory.
if ($PSScriptRoot -like '*\tools\scripts') {
    $env:ENV_ROOT = Split-Path (Split-Path $PSScriptRoot)
}
else {
    $env:ENV_ROOT = $PSScriptRoot
}

# Virtual environment: prefer venv\rt-env, fall back to legacy .venv.
$RT_VENV_DIR = "$env:ENV_ROOT\venv\rt-env"
if (-not (Test-Path "$RT_VENV_DIR\Scripts\Activate.ps1") -and
        (Test-Path "$env:ENV_ROOT\.venv\Scripts\Activate.ps1")) {
    $RT_VENV_DIR = "$env:ENV_ROOT\.venv"
}

if (Test-Path "$RT_VENV_DIR\Scripts\Activate.ps1") {
    . "$RT_VENV_DIR\Scripts\Activate.ps1"

    # Show welcome message using rt-env command
    if (Get-Command rt-env -ErrorAction SilentlyContinue) {
        rt-env --info
    }
}
else {
    Write-Host "Virtual environment not found (tried $RT_VENV_DIR\Scripts\Activate.ps1 and $env:ENV_ROOT\.venv\Scripts\Activate.ps1). Please run the installation 'RT-Thread ENV' first."
    exit 1
}

$env:pathext = ".PS1;$env:pathext"

# User customization lives in $ENV_ROOT\env.user.ps1, outside the managed
# env repository, so upgrades and reinstalls never overwrite it.
if (Test-Path "$env:ENV_ROOT\env.user.ps1") {
    . "$env:ENV_ROOT\env.user.ps1"
}
