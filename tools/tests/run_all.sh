#!/usr/bin/env bash
# Run all offline test suites for tools/.
# Usage: bash tools/tests/run_all.sh
#        RT_ENV_TEST_FULL=1 bash tools/tests/run_all.sh   # full real installs (network)

set -u

cd "$(dirname "$0")/../.." || exit 1

FAILED=0

run() {
    printf '\n########## %s ##########\n' "$1"
    if bash -c "$2"; then
        printf '########## %s: OK ##########\n' "$1"
    else
        printf '########## %s: FAILED ##########\n' "$1"
        FAILED=$((FAILED + 1))
    fi
}

run 'install.sh (stub)'        'bash tools/tests/test_install_sh.sh'
run 'touch_env.py args'        'python tools/tests/test_touch_env_args.py'
run 'touch_env.py behavior'    'python tools/tests/test_touch_env_behavior.py'
run 'touch_env.py real install' 'bash tools/tests/test_touch_env_install.sh'
run 'install.ps1 (stub)'       'pwsh -NoProfile -File tools/tests/test_install_ps1.ps1'
run 'install.ps1 real install' 'pwsh -NoProfile -File tools/tests/test_install_ps1_install.ps1'

printf '\n===== SUMMARY =====\n'
if [ "$FAILED" -eq 0 ]; then
    echo 'ALL SUITES PASSED'
else
    echo "$FAILED suite(s) FAILED"
    exit 1
fi
