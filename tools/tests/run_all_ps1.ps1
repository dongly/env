<#
.SYNOPSIS
    Run the Windows-side offline test suites for tools/ (install.ps1).
    POSIX-side suites (install.sh / touch_env.py) live in run_all.sh.

.EXAMPLE
    pwsh -NoProfile -File tools/tests/run_all_ps1.ps1
    $env:RT_ENV_TEST_FULL=1; pwsh -NoProfile -File tools/tests/run_all_ps1.ps1  # full real install (network)
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path

$failed = 0

function Invoke-Suite([string]$Name, [string]$Command) {
    Write-Host "`n########## $Name ##########"
    if (& { Invoke-Expression $Command }) {
        Write-Host "########## ${Name}: OK ##########"
    }
    else {
        Write-Host "########## ${Name}: FAILED ##########" -ForegroundColor Red
        $script:failed++
    }
}

Invoke-Suite 'install.ps1 (stub)' "pwsh -NoProfile -File `"$scriptDir\test_install_ps1.ps1`""
Invoke-Suite 'install.ps1 real install' "pwsh -NoProfile -File `"$scriptDir\test_install_ps1_install.ps1`""

Write-Host "`n===== SUMMARY ====="
if ($failed -eq 0) {
    Write-Host 'ALL PS1 SUITES PASSED'
}
else {
    Write-Host "$failed PS1 suite(s) FAILED" -ForegroundColor Red
    exit 1
}
exit 0
