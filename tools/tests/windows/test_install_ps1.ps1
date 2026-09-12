<#
.SYNOPSIS
    Tests for tools/install.ps1 (orchestrator script, PowerShell side).

.DESCRIPTION
    Covers tools/tests/README.md section 5.1 / 5.3 / 5.4 (PowerShell side):
      - parser syntax check
      - --help assertions (long options only, removed options absent)
      - temp-file cleanup wiring (unique name + try/finally)
    The argument pass-through test (7.3) needs a local HTTP stub and admin
    rights; it is reported as SKIP when not configured.

.EXAMPLE
    pwsh -NoProfile -File tools/tests/test_install_ps1.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$repoRoot = Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $scriptDir))
$installPs1 = Join-Path $repoRoot 'tools\install.ps1'

$script:Pass = 0
$script:Fail = 0
$script:Skip = 0

function Pass([string]$Name) { Write-Host "  PASS: $Name"; $script:Pass++ }
function Fail([string]$Name) { Write-Host "  FAIL: $Name" -ForegroundColor Red; $script:Fail++ }
function Skip([string]$Name) { Write-Host "  SKIP: $Name" -ForegroundColor Yellow; $script:Skip++ }
function Section([string]$Name) { Write-Host "`n== $Name ==" }

Write-Host "Testing: $installPs1"

# ---------------------------------------------------------------------------
Section '1. parser syntax (7.1)'
# ---------------------------------------------------------------------------
try {
    $errors = $null
    [System.Management.Automation.PSParser]::Tokenize(
        (Get-Content $installPs1 -Raw), [ref]$errors) | Out-Null
    if ($errors.Count -eq 0) { Pass 'PSParser reports no errors' }
    else { Fail "PSParser errors: $($errors.Count)" }
}
catch {
    Fail "parser check threw: $_"
}

# ---------------------------------------------------------------------------
Section '2. --help assertions (7.1)'
# ---------------------------------------------------------------------------
$help = & $installPs1 -h *>&1 | Out-String

if ($help -match '--keep-sdk') { Pass 'help lists --keep-sdk' }
else { Fail 'help lists --keep-sdk' }

if ($help -match '--english|--chinese') { Fail 'help has no removed --english/--chinese' }
else { Pass 'help has no removed --english/--chinese' }

if ($help -match '--pyocd|--backup') { Fail 'help has no removed --pyocd/--backup' }
else { Pass 'help has no removed --pyocd/--backup' }

$shortMatches = @([regex]::Matches($help, '(?m)(^|\s)-([a-zA-Z])\b') |
    Where-Object { $_.Groups[2].Value -ne 'h' })
if ($shortMatches.Count -gt 0) {
    Fail "no single-letter short options (found: $($shortMatches.Value -join ', '))"
}
else { Pass 'no single-letter short options' }

# G6: --lang must actually switch the banner language
$helpEn = & $installPs1 --lang en -h *>&1 | Out-String
$helpZh = & $installPs1 --lang zh -h *>&1 | Out-String
if ($helpEn -match 'Installation' -and $helpEn -notmatch '安装程序') { Pass '--lang en switches banner to English' }
else { Fail '--lang en switches banner to English' }
if ($helpZh -match '安装程序') { Pass '--lang zh switches banner to Chinese' }
else { Fail '--lang zh switches banner to Chinese' }

# ---------------------------------------------------------------------------
Section '3. temp-file cleanup wiring (7.4)'
# ---------------------------------------------------------------------------
$content = Get-Content $installPs1 -Raw

if ($content -match 'touch_env_" \+ \[guid\]::NewGuid\(\)') {
    Pass 'temp file uses a unique GUID name'
}
else { Fail 'temp file uses a unique GUID name' }

if ($content -match '(?s)function Invoke-TouchEnv.*?finally \{.*?Remove-Item') {
    Pass 'Invoke-TouchEnv removes the temp file in finally'
}
else { Fail 'Invoke-TouchEnv removes the temp file in finally' }

if ($content -match 'Register-EngineEvent -SourceIdentifier PowerShell\.Exiting') {
    Pass 'exit-event cleanup handler is registered'
}
else { Fail 'exit-event cleanup handler is registered' }

# ---------------------------------------------------------------------------
Section '4. argument pass-through (7.3)'
# ---------------------------------------------------------------------------
$stubUrl = $env:RT_ENV_PS1_STUB_URL
if ([string]::IsNullOrWhiteSpace($stubUrl)) {
    Skip 'pass-through (set RT_ENV_PS1_STUB_URL=http://127.0.0.1:PORT/stub_touch_env.py to enable; needs admin)'
}
else {
    $output = & $installPs1 --touch-env $stubUrl --yes 2>&1 | Out-String
    if ($output -match 'ARGS: .*--auto-mode') { Pass 'long options forwarded (--auto-mode seen)' }
    else { Fail "pass-through (no ARGS line; output: $output)" }
}

# ---------------------------------------------------------------------------
Write-Host "`n== summary =="
Write-Host "PASS=$script:Pass FAIL=$script:Fail SKIP=$script:Skip"
if ($script:Fail -gt 0) { exit 1 }
exit 0
