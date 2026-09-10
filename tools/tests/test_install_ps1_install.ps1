<#
.SYNOPSIS
    Real-install end-to-end test for tools/install.ps1 (Windows, isolated).

.DESCRIPTION
    Runs the full orchestrator install against a throwaway ENV_ROOT:
      1. seeds local bare repos for env/packages/sdk
      2. serves the real touch_env.py over a local HTTP stub
      3. invokes install.ps1 with --touch-env/--env-root/--repo-* (no admin if
         the execution policy and long-path support already meet requirements)
      4. asserts clones, venv/rt-env, and the rt-env console script
    Nothing touches the real ~/.rt-env. PIP_NO_DEPS keeps the venv bootstrap
    local; set RT_ENV_TEST_FULL=1 to install real deps + pyocd and run rt-env.

    Needs elevation only when Init-WindowsEnv must change the execution policy
    or long-path support. On this machine both already satisfy the target, so
    it runs without admin. If your machine requires elevation, run:
        sudo pwsh -NoProfile -File tools/tests/test_install_ps1_install.ps1
    (Windows built-in sudo shows a UAC prompt.)

.EXAMPLE
    pwsh -NoProfile -File tools/tests/test_install_ps1_install.ps1
    $env:RT_ENV_TEST_FULL=1; pwsh -NoProfile -File tools/tests/test_install_ps1_install.ps1
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Continue'

$scriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$toolsDir = Split-Path -Parent $scriptDir
$repoRoot = Split-Path -Parent $toolsDir
$installPs1 = Join-Path $toolsDir 'install.ps1'
$touchEnv = Join-Path $toolsDir 'touch_env.py'

$script:Pass = 0
$script:Fail = 0
$script:Skip = 0
function Pass([string]$n) { Write-Host "  PASS: $n"; $script:Pass++ }
function Fail([string]$n) { Write-Host "  FAIL: $n" -ForegroundColor Red; $script:Fail++ }
function Skip([string]$n) { Write-Host "  SKIP: $n" -ForegroundColor Yellow; $script:Skip++ }
function Section([string]$n) { Write-Host "`n== $n ==" }

$full = $env:RT_ENV_TEST_FULL -eq '1'
$work = Join-Path $env:TEMP ("rt_env_ps1_" + [guid]::NewGuid().ToString('N'))
$job = $null
$port = 8899

function Cleanup {
    if ($job) {
        Stop-Job $job -ErrorAction SilentlyContinue
        Remove-Job $job -Force -ErrorAction SilentlyContinue
    }
    Remove-Item $work -Recurse -Force -ErrorAction SilentlyContinue
}
trap { Cleanup }

if (-not (Test-Path $installPs1) -or -not (Test-Path $touchEnv)) {
    Write-Host "SKIP: install.ps1 or touch_env.py missing" -ForegroundColor Yellow
    exit 0
}

New-Item -ItemType Directory -Force $work | Out-Null

# ---------------------------------------------------------------------------
Section '1. seed local bare repositories'
# ---------------------------------------------------------------------------
foreach ($n in 'env', 'packages', 'sdk') {
    git init --bare -q "$work\$n.git" 2>$null
}
git -C $repoRoot push -q "$work\env.git" HEAD:master 2>$null
foreach ($n in 'env', 'packages', 'sdk') {
    git --git-dir="$work\$n.git" symbolic-ref HEAD refs/heads/master
}
Write-Host '  (env pushed from the working tree; packages/sdk are empty repos)'

# ---------------------------------------------------------------------------
Section '2. serve touch_env.py over local HTTP'
# ---------------------------------------------------------------------------
$srv = Join-Path $work 'srv'
New-Item -ItemType Directory -Force $srv | Out-Null
Copy-Item $touchEnv (Join-Path $srv 'touch_env.py')
$job = Start-Job -ScriptBlock {
    param($d, $p)
    Set-Location $d
    python -m http.server $p
} -ArgumentList $srv, $port
Start-Sleep -Seconds 3

$url = "http://127.0.0.1:$port/touch_env.py"
try {
    $probe = (Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 5).StatusCode
    if ($probe -eq 200) { Pass 'local HTTP stub serves touch_env.py' }
    else { Fail "local HTTP stub (status $probe)" }
}
catch {
    Fail "local HTTP stub ($_)"
    Cleanup
    Write-Host "`n== summary =="
    Write-Host "PASS=$script:Pass FAIL=$script:Fail SKIP=$script:Skip"
    exit 1
}

# ---------------------------------------------------------------------------
Section '3. run install.ps1 real install'
# ---------------------------------------------------------------------------
$envRoot = Join-Path $work 'root'
$u = $work -replace '\\', '/'
if (-not $full) { $env:PIP_NO_DEPS = '1' }
else { Remove-Item Env:PIP_NO_DEPS -ErrorAction SilentlyContinue }

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole(
    [Security.Principal.WindowsBuiltInRole]::Administrator)
Write-Host "  (admin=$isAdmin, full=$full)"

$out = & $installPs1 `
    --touch-env $url `
    --env-root $envRoot `
    --yes --keep-sdk yes `
    --env "file:///$u/env.git" `
    --packages "file:///$u/packages.git" `
    --sdk "file:///$u/sdk.git" 2>&1
$rc = $LASTEXITCODE

if ($rc -eq 0) { Pass 'install.ps1 exits 0' }
else {
    Fail "install.ps1 exits 0 (rc=$rc)"
    $out | Select-Object -Last 15 | ForEach-Object { Write-Host "    $_" }
}

# ---------------------------------------------------------------------------
Section '4. artifacts'
# ---------------------------------------------------------------------------
foreach ($pair in @(
        @{ n = 'env cloned into tools/scripts'; p = "$envRoot\tools\scripts\env.py" },
        @{ n = 'packages cloned'; p = "$envRoot\packages\packages" },
        @{ n = 'sdk cloned'; p = "$envRoot\packages\sdk" },
        @{ n = 'venv created at venv/rt-env'; p = "$envRoot\venv\rt-env" },
        @{ n = 'rt-env console script present'; p = "$envRoot\venv\rt-env\Scripts\rt-env.exe" }
    )) {
    if (Test-Path $pair.p) { Pass $pair.n } else { Fail $pair.n }
}

$venvPy = "$envRoot\venv\rt-env\Scripts\python.exe"
if (Test-Path $venvPy) {
    $ver = & $venvPy -c "from importlib.metadata import version; print(version('rt-env'))" 2>$null
    if ($ver) { Pass "editable metadata resolves (rt-env $ver)" }
    else { Fail 'editable metadata resolves' }
}

# ---------------------------------------------------------------------------
Section '5. runtime checks (FULL mode only)'
# ---------------------------------------------------------------------------
if (-not $full) {
    Skip 'real deps + pyocd + rt-env runtime (set RT_ENV_TEST_FULL=1)'
}
else {
    $rtEnv = "$envRoot\venv\rt-env\Scripts\rt-env.exe"
    if (Test-Path "$envRoot\venv\rt-env\Scripts\pyocd.exe") { Pass 'pyocd installed' }
    else { Fail 'pyocd installed' }

    if (Test-Path $rtEnv) {
        $v = & $rtEnv -v 2>&1
        if ("$v" -match 'RT-Thread Env Tool') { Pass "rt-env -v runs ($v)" } else { Fail 'rt-env -v runs' }
        $i = & $rtEnv --info 2>&1
        if ("$i" -match 'Welcome to RT-Thread Env Tool') { Pass 'rt-env --info runs' } else { Fail 'rt-env --info runs' }
        $h = & $rtEnv --help 2>&1
        if ("$h" -match 'usage: rt-env' -and "$h" -match 'webui') { Pass 'rt-env --help runs' } else { Fail 'rt-env --help runs' }
    }
}

# ---------------------------------------------------------------------------
Cleanup
Write-Host "`n== summary =="
Write-Host "PASS=$script:Pass FAIL=$script:Fail SKIP=$script:Skip"
if ($script:Fail -gt 0) { exit 1 }
exit 0
