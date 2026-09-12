#!/usr/bin/env bash
# Tests for tools/install.sh (orchestrator script).
#
# Usage:  bash tools/tests/linux/test_install_sh.sh
# Needs:  bash; python3 (a wrapper is synthesized when only `python` works,
#         e.g. the Microsoft Store python3 stub on Windows); curl or wget.
#
# Covers tools/tests/README.md section 4.5 (install.sh side).

set -u

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
TOOLS_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
INSTALL_SH="$TOOLS_DIR/tools/install.sh"

PASS=0
FAIL=0
SKIP=0
WORK="$(mktemp -d 2>/dev/null || mktemp -d -t rt-env-tests)"

pass() { printf '  PASS: %s\n' "$1"; PASS=$((PASS + 1)); }
fail() { printf '  FAIL: %s\n' "$1"; FAIL=$((FAIL + 1)); }
skip() { printf '  SKIP: %s\n' "$1"; SKIP=$((SKIP + 1)); }
section() { printf '\n== %s ==\n' "$1"; }

cleanup() {
    rm -rf "$WORK"
}
trap cleanup EXIT INT TERM

# Resolve a usable python3 command line; synthesize a wrapper if needed.
detect_python3() {
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

# Convert a POSIX path into a file:// URL usable by the platform's curl.
file_url() {
    case "$(uname -s)" in
        MINGW* | MSYS* | CYGWIN*)
            local win
            win="$(cygpath -m "$1" 2>/dev/null || printf '%s' "$1")"
            printf 'file:///%s' "$win"
            ;;
        *)
            printf 'file://%s' "$1"
            ;;
    esac
}

# ---------------------------------------------------------------------------
section '1. syntax (7.1)'
# ---------------------------------------------------------------------------
if bash -n "$INSTALL_SH" 2>/dev/null; then
    pass 'bash -n'
else
    fail 'bash -n'
fi
if bash --posix -n "$INSTALL_SH" 2>/dev/null; then
    pass 'bash --posix -n'
else
    fail 'bash --posix -n'
fi

# ---------------------------------------------------------------------------
section '2. --help assertions (7.1)'
# ---------------------------------------------------------------------------
HELP="$(bash "$INSTALL_SH" --help 2>&1 || true)"

if printf '%s' "$HELP" | grep -q -- '--keep-sdk'; then
    pass 'help lists --keep-sdk'
else
    fail 'help lists --keep-sdk'
fi

if printf '%s' "$HELP" | grep -qE -- '--english|--chinese'; then
    fail 'help has no removed --english/--chinese'
else
    pass 'help has no removed --english/--chinese'
fi

if printf '%s' "$HELP" | grep -qE -- '--pyocd|--backup'; then
    fail 'help has no removed --pyocd/--backup'
else
    pass 'help has no removed --pyocd/--backup'
fi

# Any single-letter option other than -h is unexpected.
SHORTS="$(printf '%s' "$HELP" | grep -oE '(^|[[:space:]])-[a-zA-Z]' | tr -d '[:space:]' | grep -v -- '-h' || true)"
if [ -n "$SHORTS" ]; then
    fail "no single-letter short options (found: $SHORTS)"
else
    pass 'no single-letter short options'
fi

# --lang must actually switch the banner language (help body is English-only in install.sh).
if bash "$INSTALL_SH" --lang en --help 2>&1 | head -n 1 | grep -q 'Installation'; then
    pass '--lang en switches banner to English'
else
    fail '--lang en switches banner to English'
fi
if bash "$INSTALL_SH" --lang zh --help 2>&1 | head -n 1 | grep -q '安装程序'; then
    pass '--lang zh switches banner to Chinese'
else
    fail '--lang zh switches banner to Chinese'
fi

# ---------------------------------------------------------------------------
section '3. mktemp portability (7.4 regression)'
# ---------------------------------------------------------------------------
if grep -q 'mktemp --suffix' "$INSTALL_SH"; then
    fail 'no GNU-only mktemp --suffix (breaks macOS)'
else
    pass 'no GNU-only mktemp --suffix (macOS-portable)'
fi

# ---------------------------------------------------------------------------
section '4. argument pass-through (7.2)'
# ---------------------------------------------------------------------------
PY3="$(detect_python3 || true)"
if [ -z "$PY3" ]; then
    skip 'argument pass-through (no usable python3/python)'
else
    STUB="$WORK/stub_touch_env.py"
    cat > "$STUB" <<'EOF'
import sys
print("ARGS: " + " ".join(sys.argv[1:]))
EOF

    GOT="$(
        PATH="$(dirname "$PY3"):$PATH" bash "$INSTALL_SH" \
            --touch-env "$(file_url "$STUB")" \
            --env-root "$WORK/rt-env-test" \
            --cn --yes --keep-sdk no \
            --packages 'https://example.com/p.git#dev' 2>&1 || true
    )"
    RELEVANT="$(printf '%s' "$GOT" | grep -a 'ARGS:' | head -n 1 || true)"

    if printf '%s' "$RELEVANT" | grep -q -- '--use-cn' &&
        printf '%s' "$RELEVANT" | grep -q -- '--language zh' &&
        printf '%s' "$RELEVANT" | grep -q -- '--auto-mode' &&
        printf '%s' "$RELEVANT" | grep -q -- '--keep-sdk no' &&
        printf '%s' "$RELEVANT" | grep -q -- '--repo-packages https://example.com/p.git#dev'; then
        pass 'long options forwarded verbatim (incl. URL fragment)'
    else
        fail "argument pass-through (got: ${RELEVANT:-<no ARGS line>})"
    fi

    # G3: --official / --env / --sdk / --lang forwarding (previously untested)
    RELEVANT2="$(
        PATH="$(dirname "$PY3"):$PATH" bash "$INSTALL_SH" \
            --touch-env "$(file_url "$STUB")" \
            --env-root "$WORK/rt-env-test" \
            --official --yes --lang en \
            --env 'https://github.com/x/env.git#b1' \
            --sdk 'https://github.com/y/sdk.git' 2>&1 || true
    )"
    RELEVANT2="$(printf '%s' "$RELEVANT2" | grep -a 'ARGS:' | head -n 1 || true)"
    if printf '%s' "$RELEVANT2" | grep -q -- '--language en' &&
        printf '%s' "$RELEVANT2" | grep -q -- '--repo-env https://github.com/x/env.git#b1' &&
        printf '%s' "$RELEVANT2" | grep -q -- '--repo-sdk https://github.com/y/sdk.git'; then
        pass '--official/--env/--sdk/--lang forwarded'
    else
        fail "--official/--env/--sdk/--lang forwarded (got: ${RELEVANT2:-<no ARGS line>})"
    fi
fi

# ---------------------------------------------------------------------------
section '5. temp-file cleanup (7.4)'
# ---------------------------------------------------------------------------
if [ -z "$PY3" ]; then
    skip 'temp-file cleanup (no usable python3/python)'
else
    STUB="$WORK/stub_touch_env.py"
    if [ ! -f "$STUB" ]; then
        cat > "$STUB" <<'EOF'
import sys
print("ARGS: " + " ".join(sys.argv[1:]))
EOF
    fi
    TMPROOT="${TMPDIR:-/tmp}"
    BEFORE="$(ls "$TMPROOT"/tmp.* 2>/dev/null | sort || true)"
    PATH="$(dirname "$PY3"):$PATH" bash "$INSTALL_SH" \
        --touch-env "$(file_url "$STUB")" --yes >/dev/null 2>&1 || true
    AFTER="$(ls "$TMPROOT"/tmp.* 2>/dev/null | sort || true)"
    LEFTOVER="$(comm -13 "$BEFORE" "$AFTER" 2>/dev/null || true)"
    if [ -z "$LEFTOVER" ]; then
        pass 'temp file removed on exit (no new tmp.* leftovers)'
    else
        fail "temp file removed on exit (leftover: $LEFTOVER)"
    fi
fi

# ---------------------------------------------------------------------------
printf '\n== summary ==\n'
printf 'PASS=%s FAIL=%s SKIP=%s\n' "$PASS" "$FAIL" "$SKIP"
[ "$FAIL" -eq 0 ] || exit 1
exit 0
