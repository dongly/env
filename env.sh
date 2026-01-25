# RT-Thread Environment Directory
# Can be overridden by $ENV_ROOT environment variable
: "${ENV_ROOT:=$HOME/.env}"

# Virtual environment directory name
: "${VENV_DIR:=rt-venv}"

# Activate Python virtual environment
if [ -f "$ENV_ROOT/$VENV_DIR/bin/activate" ]; then
    source "$ENV_ROOT/$VENV_DIR/bin/activate"
else
    echo "Virtual environment not found. Please run the installation script first."
    exit 1
fi

# Set PATH
export PATH="$ENV_ROOT/tools/scripts:$PATH"
export RTT_EXEC_PATH=/usr/bin
