#!/usr/bin/env bash
# Real-install end-to-end test for tools/touch_env.py (offline, isolated).
#
# Runs the full installer against a throwaway ENV_ROOT using local bare
# repositories for env/packages/sdk, so no network is needed and nothing
# touches the real ~/.rt-env. PIP_NO_DEPS=1 keeps the venv bootstrap local
# (the editable env package install still resolves its own metadata).
#
# Set RT_ENV_TEST_FULL=1 to run a TRULY real install instead: install all
# third-party dependencies and pyocd (network required), then actually run
# the installed rt-env (version, info, help) from the fresh venv.
#
# Usage: bash tools/tests/linux/test_touch_env_install.sh
#        RT_ENV_TEST_FULL=1 bash tools/tests/linux/test_touch_env_install.sh
# Needs: bash, git, python (with venv + pip); network only in FULL mode.

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
TOUCH_ENV="$TOOLS_DIR/tools/touch_env.py"
REPO_ROOT="$TOOLS_DIR"

PASS=0
FAIL=0
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t rt-env-install)"

pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
section() { printf '\n== %s ==\n' "$1"; }

cleanup() {
    rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

file_url() {
    case "$(uname -s)" in
        MINGW* | MSYS* | CYGWIN*)
            printf 'file:///%s' "$(cygpath -m "$1" 2>/dev/null || printf '%s' "$1")"
            ;;
        *)
            printf 'file://%s' "$1"
            ;;
    esac
}

# Resolve python; synthesize a wrapper when only `python` works (store stub).
detect_python() {
    if command -v python3 >/dev/null 2>&1 && python3 --version >/dev/null 2>&1; then
        printf 'python3'
        return 0
    fi
    local py
    py="$(command -v python 2>/dev/null || true)"
    if [ -n "$py" ] && "$py" --version >/dev/null 2>&1; then
        mkdir -p "$WORK/bin"
        printf '#!/bin/sh\nexec "%s" "$@"\n' "$py" > "$WORK/bin/python3"
        chmod +x "$WORK/bin/python3"
        printf '%s' "$WORK/bin/python3"
        return 0
    fi
    return 1
}

PY="$(detect_python || true)"
if [ -z "$PY" ]; then
    echo "SKIP: no usable python3/python" >&2
    exit 0
fi

# ---------------------------------------------------------------------------
section '1. seed local bare repositories'
# ---------------------------------------------------------------------------
ENV_BARE="$WORK/env.git"
PKGS_BARE="$WORK/packages.git"
SDK_BARE="$WORK/sdk.git"
for bare in "$ENV_BARE" "$PKGS_BARE" "$SDK_BARE"; do
    git init --bare -q "$bare"
done

# env: push the current WORKING TREE (tracked changes included) as master,
# so the suite tests what the developer is editing, not the last commit.
# `git stash create` yields a dangling commit without touching index/HEAD.
STASH_COMMIT="$(git -C "$REPO_ROOT" stash create 2>/dev/null || true)"
[ -n "$STASH_COMMIT" ] || STASH_COMMIT=HEAD
git -C "$REPO_ROOT" push -q "$ENV_BARE" "$STASH_COMMIT:refs/heads/master" 2>/dev/null || true
git --git-dir="$ENV_BARE" symbolic-ref HEAD refs/heads/master

# packages/sdk: empty repositories are fine; ensure their HEAD points at master
git --git-dir="$PKGS_BARE" symbolic-ref HEAD refs/heads/master
git --git-dir="$SDK_BARE" symbolic-ref HEAD refs/heads/master

section '2. run the real installer (auto, keep-sdk yes, local sources)'
# ---------------------------------------------------------------------------
ENV_ROOT="$WORK/env-root"
FULL="${RT_ENV_TEST_FULL:-0}"
if [ "$FULL" = "1" ]; then
    printf '  (FULL mode: installing all dependencies and pyocd - needs network)\n'
else
    # Keep the venv bootstrap local: skip third-party deps (env metadata still resolves)
    export PIP_NO_DEPS=1
fi
OUTPUT="$("$PY" "$TOUCH_ENV" \
    --env-root "$ENV_ROOT" \
    --auto-mode \
    --keep-sdk yes \
    --repo-env "$(file_url "$ENV_BARE")" \
    --repo-packages "$(file_url "$PKGS_BARE")" \
    --repo-sdk "$(file_url "$SDK_BARE")" \
    2>&1)"
RC=$?

if [ "$RC" -eq 0 ]; then
    pass "installer exits 0"
else
    fail "installer exits 0 (rc=$RC)"
    printf '%s\n' "$OUTPUT" | tail -20
fi

section '3. repository clones'
# ---------------------------------------------------------------------------
if [ -f "$ENV_ROOT/tools/scripts/env.py" ] &&
    [ -f "$ENV_ROOT/tools/scripts/pyproject.toml" ]; then
    pass 'env cloned into tools/scripts'
else
    fail 'env cloned into tools/scripts'
fi

if [ -d "$ENV_ROOT/packages/packages" ]; then
    pass 'packages cloned into packages/packages'
else
    fail 'packages cloned into packages/packages'
fi

if [ -d "$ENV_ROOT/packages/sdk" ]; then
    pass 'sdk cloned into packages/sdk'
else
    fail 'sdk cloned into packages/sdk'
fi

section '4. venv and editable install'
# ---------------------------------------------------------------------------
VENV_DIR="$ENV_ROOT/venv/rt-env"
if [ -d "$VENV_DIR" ]; then
    pass 'venv created at venv/rt-env'
else
    fail 'venv created at venv/rt-env'
fi

case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*)
        RT_ENV_EXE="$VENV_DIR/Scripts/rt-env.exe"
        VENV_PY="$VENV_DIR/Scripts/python.exe"
        ;;
    *)
        RT_ENV_EXE="$VENV_DIR/bin/rt-env"
        VENV_PY="$VENV_DIR/bin/python"
        ;;
esac

if [ -f "$RT_ENV_EXE" ]; then
    pass 'rt-env console script present'
else
    fail 'rt-env console script present'
fi

if [ -f "$VENV_PY" ]; then
    VER="$("$VENV_PY" -c 'from importlib.metadata import version; print(version("rt-env"))' 2>/dev/null || true)"
    if [ -n "$VER" ]; then
        pass "editable install metadata resolves (rt-env $VER)"
    else
        fail 'editable install metadata resolves'
    fi
else
    fail 'venv python present'
fi

# ---------------------------------------------------------------------------
section '4b. installed tool actually runs (FULL mode only)'
# ---------------------------------------------------------------------------
if [ "$FULL" != "1" ]; then
    printf '  (skipped: set RT_ENV_TEST_FULL=1 for real deps + runtime checks)\n'
else
    # pyocd is installed unconditionally by install_packages()
    if [ -f "$VENV_DIR/Scripts/pyocd.exe" ] || [ -f "$VENV_DIR/bin/pyocd" ]; then
        pass 'pyocd installed'
    else
        fail 'pyocd installed'
    fi

    if [ -f "$RT_ENV_EXE" ]; then
        RV="$("$RT_ENV_EXE" -v 2>&1 || true)"
        if printf '%s' "$RV" | grep -q 'RT-Thread Env Tool'; then
            pass "rt-env -v runs ($(printf '%s' "$RV" | head -n 1))"
        else
            fail "rt-env -v runs (got: ${RV:-<empty>})"
        fi

        RI="$("$RT_ENV_EXE" --info 2>&1 || true)"
        if printf '%s' "$RI" | grep -q 'Welcome to RT-Thread Env Tool'; then
            pass 'rt-env --info runs'
        else
            fail "rt-env --info runs (got: $(printf '%s' "$RI" | head -n 1))"
        fi

        RH="$("$RT_ENV_EXE" --help 2>&1 || true)"
        if printf '%s' "$RH" | grep -q 'usage: rt-env' &&
            printf '%s' "$RH" | grep -q 'webui'; then
            pass 'rt-env --help runs (usage + webui subcommand)'
        else
            fail 'rt-env --help runs'
        fi
    else
        fail 'rt-env console script present for runtime checks'
    fi
fi

# ---------------------------------------------------------------------------
section '4c. root activator and user customization'
# ---------------------------------------------------------------------------
if bash -n "$ENV_ROOT/env.sh" && bash -n "$ENV_ROOT/tools/scripts/env.sh"; then
    pass 'activator syntax (bash -n)'
else
    fail 'activator syntax (bash -n)'
fi

if ! grep -q 'RT_ENV_ROOT=' "$ENV_ROOT/env.sh" &&
    grep -q 'tools/scripts/env.sh' "$ENV_ROOT/env.sh"; then
    pass 'root activator is a thin delegator'
else
    fail 'root activator is a thin delegator'
fi

if [ -f "$ENV_ROOT/env.user.sh" ]; then
    pass 'user customization file seeded'
else
    fail 'user customization file seeded'
fi

DELEGATED="$(bash -c ". '$ENV_ROOT/env.sh' >/dev/null 2>&1; printf '%s' \"\$RT_VENV_DIR\"")"
if [ "$DELEGATED" = "$VENV_DIR" ]; then
    pass 'delegation activates venv/rt-env'
else
    fail "delegation activates venv/rt-env (got: ${DELEGATED:-<empty>})"
fi

FALLBACK_ROOT="$WORK/fallback-root"
mkdir -p "$FALLBACK_ROOT/.venv/bin" "$FALLBACK_ROOT/tools/scripts"
cp "$ENV_ROOT/tools/scripts/env.sh" "$FALLBACK_ROOT/tools/scripts/env.sh"
printf '# fake legacy venv\nexport RTT_FAKE_VENV=legacy\n' > "$FALLBACK_ROOT/.venv/bin/activate"
FALLBACKED="$(env -u RT_ENV_ROOT -u ENV_ROOT bash -c ". '$FALLBACK_ROOT/tools/scripts/env.sh' >/dev/null 2>&1; printf '%s|%s' \"\$RT_VENV_DIR\" \"\$RTT_FAKE_VENV\"")"
if [ "$FALLBACKED" = "$FALLBACK_ROOT/.venv|legacy" ]; then
    pass 'legacy .venv fallback activates'
else
    fail "legacy .venv fallback activates (got: ${FALLBACKED:-<empty>})"
fi

section '5. cleanup bookkeeping'
# ---------------------------------------------------------------------------
if [ -z "$OUTPUT" ] || printf '%s' "$OUTPUT" | grep -qi 'completed'; then
    pass 'installer reports completion'
else
    fail 'installer reports completion'
fi

# ---------------------------------------------------------------------------
printf '\n== summary ==\n'
printf 'PASS=%s FAIL=%s\n' "$PASS" "$FAIL"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
