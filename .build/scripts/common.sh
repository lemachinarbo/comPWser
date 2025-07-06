# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging helpers
log_warn() { echo -e "${YELLOW}⚠${NC} $*"; }
log_error() { echo -e "${RED}✗${NC} $*"; }
log_ok() { echo -e "${GREEN}✓${NC} $*"; }
log_success() { echo -e "${GREEN}$*"; }
log_info() { echo -e "${NC}$*"; }
log_header() { echo -e "${YELLOW}$*${NC}"; }
log_hr() { echo "----------------------------------------"; }
log_ask() {
    # Usage: log_ask "Prompt text [default]: "
    local prompt="$*"
    local yellow="$(printf '\033[1;33m')"
    local nc="$(printf '\033[0m')"
    # Colorize anything inside [ ] in yellow using ANSI codes directly
    prompt=$(echo "$prompt" | sed -E "s/\[([^]]+)\]/${yellow}[\1]${nc}/g")
    printf "%b" "$prompt"
}
log_fatal() { echo -e "\n${RED}$*${NC}\n"; }

# Script and env file locations
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../../.env"

# Source .env file if it exists
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    log_error ".env file not found at $ENV_FILE"
    exit 1
fi

# Helper to get value from .env with prefix
get_env() {
    VAR="$1"
    eval echo "\${${PREFIX}${VAR}}"
}

# Helper to get env value with default
get_env_default() {
    VAR="$1"; DEFAULT="$2"
    VAL=$(get_env "$VAR")
    echo "${VAL:-$DEFAULT}"
}
