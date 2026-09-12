#!/usr/bin/env bash
# Run the POSIX-side offline test suites (install.sh + touch_env.py).
# Windows-side suites live in windows/run_all.ps1.
# Usage: bash tools/tests/linux/run_all.sh
#        RT_ENV_TEST_FULL=1 bash tools/tests/linux/run_all.sh   # full real install (network)

set -u

cd "$(dirname "$0")/../../.." || exit 1

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

run 'install.sh (stub)'         'bash tools/tests/linux/test_install_sh.sh'
run 'touch_env.py args'         'python tools/tests/common/test_touch_env_args.py'
run 'touch_env.py behavior'     'python tools/tests/common/test_touch_env_behavior.py'
run 'touch_env.py real install' 'bash tools/tests/linux/test_touch_env_install.sh'

printf '\n===== SUMMARY =====\n'
if [ "$FAILED" -eq 0 ]; then
    echo 'ALL POSIX SUITES PASSED'
else
    echo "$FAILED POSIX suite(s) FAILED"
    exit 1
fi
