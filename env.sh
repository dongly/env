# ENV_ROOT resolution:
#   1. Layout detection - when sourced directly from tools/scripts the
#      installation root is two levels up.
#   2. Otherwise this file's own directory (legacy full copy at $ENV_ROOT).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
case "$SCRIPT_DIR" in
    */tools/scripts) ENV_ROOT="${SCRIPT_DIR%/tools/scripts}" ;;
    *) echo "env.sh: not under tools/scripts (legacy layout at $SCRIPT_DIR); the installation is outdated or incomplete. Please reinstall the RT-Thread ENV." >&2; ENV_ROOT="$SCRIPT_DIR" ;;
esac
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
