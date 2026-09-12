# ENV_ROOT resolution:
#   1. $RT_ENV_ROOT - set by the thin root activator ($ENV_ROOT/env.sh)
#      that delegates to this script, so this copy never guesses where
#      the installation root is.
#   2. Layout detection - when sourced directly from tools/scripts the
#      installation root is two levels up.
#   3. Otherwise this file's own directory (legacy full copy at $ENV_ROOT).
if [ -n "$RT_ENV_ROOT" ]; then
    ENV_ROOT="$RT_ENV_ROOT"
else
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    case "$SCRIPT_DIR" in
        */tools/scripts) ENV_ROOT="${SCRIPT_DIR%/tools/scripts}" ;;
        *) ENV_ROOT="$SCRIPT_DIR" ;;
    esac
fi
export "ENV_ROOT=$ENV_ROOT"

# Virtual environment: prefer the current layout (venv/rt-env),
# fall back to the legacy location (.venv) of older installations.
RT_VENV_DIR="$ENV_ROOT/venv/rt-env"
if [ ! -f "$RT_VENV_DIR/bin/activate" ] && [ -f "$ENV_ROOT/.venv/bin/activate" ]; then
    RT_VENV_DIR="$ENV_ROOT/.venv"
fi

# Activate Python virtual environment
if [ -f "$RT_VENV_DIR/bin/activate" ]; then
    source "$RT_VENV_DIR/bin/activate"

    # Show welcome message using rt-env command
    if command -v rt-env >/dev/null 2>&1; then
        rt-env --info
    fi
else
    echo "Virtual environment not found (tried $ENV_ROOT/venv/rt-env and $ENV_ROOT/.venv)."
    echo "Please run the installation script first."
    return 1
fi

# Set PATH
# export PATH="$ENV_ROOT/tools/scripts:$PATH"
export RTT_EXEC_PATH=/usr/bin

# User customization lives in $ENV_ROOT/env.user.sh, outside the managed
# env repository, so upgrades and reinstalls never overwrite it.
if [ -f "$ENV_ROOT/env.user.sh" ]; then
    . "$ENV_ROOT/env.user.sh"
fi
