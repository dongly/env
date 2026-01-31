#!/bin/bash
# Can be overridden by $ENV_ROOT environment variable
: "${ENV_ROOT:=$HOME/.rtenv}"

# Virtual environment directory name
RT_VENV_DIR="$ENV_ROOT/venv/rt-env"

echo "Using RT-Thread environment at: $ENV_ROOT"
echo "Using RT-Thread virtual environment: $RT_VENV_DIR"

# Activate Python virtual environment
if [ -f "$RT_VENV_DIR/bin/activate" ]; then
    source "$RT_VENV_DIR/bin/activate"
    
    # Show welcome message using rt-env command
    if command -v rt-env &> /dev/null; then
        rt-env -v
    fi
else
    echo "Virtual environment not found. Please run the installation script first."
    exit 1
fi

# Set PATH
# export PATH="$ENV_ROOT/tools/scripts:$PATH"
export RTT_EXEC_PATH=/usr/bin
