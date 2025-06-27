#!/bin/bash

# Load configuration from .env file
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"

ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
    echo -e "${YELLOW}Loading config from $ENV_FILE${NC}"
    source "$ENV_FILE"
else
    echo -e "${WARN}  Warning: .env file not found at $ENV_FILE"
fi

echo
# Set defaults if not configured
SSH_KEY_PATH="$HOME/.ssh/${SSH_KEY:-id_rsa}"
REMOTE_USER=${SSH_USER:-"user@server"}
REMOTE_HOST=${SSH_HOST:-"server"}
REMOTE_PATH=${DEPLOY_PATH:-"/path/to/deployment"}
REMOTE_USER_HOST="$REMOTE_USER@$REMOTE_HOST"

echo -e "${YELLOW}Deploying to remote server...${NC}"
echo -e "Using SSH key: $SSH_KEY_PATH"
echo -e "Deploying to: $REMOTE_USER_HOST:$REMOTE_PATH"

echo
# Change to project root so rsync can find public and RockShell
cd "$(dirname "$0")/.."

echo
# Comment out both options by default, then enable the one specified by HTACCESS_OPTION if set
HTACCESS_FILE="$PW_ROOT/.htaccess"
if [ -f "$HTACCESS_FILE" ]; then
    echo -e "${YELLOW}Ensuring correct .htaccess Options settings in $HTACCESS_FILE...${NC}"
    # Comment out all Options +FollowSymLinks (case-insensitive, robust whitespace)
    sed -i -E 's/^[[:space:]]*[#]*[[:space:]]*Options[[:space:]]+\+FollowSymLinks/# Options +FollowSymLinks/I' "$HTACCESS_FILE"
    # Comment out all Options +SymLinksifOwnerMatch or Options +SymLinksIfOwnerMatch (case-insensitive, robust whitespace)
    sed -i -E 's/^[[:space:]]*[#]*[[:space:]]*Options[[:space:]]+\+SymLinks[Ii]fOwnerMatch/# Options +SymLinksIfOwnerMatch/I' "$HTACCESS_FILE"
    # Uncomment the one specified by HTACCESS_OPTION (case-insensitive, always use correct casing)
    if [[ "${HTACCESS_OPTION,,}" == "followsymlinks" ]]; then
        sed -i -E 's/^# Options[[:space:]]+\+FollowSymLinks/Options +FollowSymLinks/I' "$HTACCESS_FILE"
    elif [[ "${HTACCESS_OPTION,,}" == "symlinksifownermatch" ]]; then
        sed -i -E 's/^# Options[[:space:]]+\+SymLinks[Ii]fOwnerMatch.*/Options +SymLinksIfOwnerMatch/' "$HTACCESS_FILE"
    fi
fi

# Check if source folders exist before running rsync
if [ ! -d "$PW_ROOT" ]; then
    echo -e "${CROSS} Source directory PW_ROOT ('$PW_ROOT') does not exist. Aborting deployment."
    exit 1
fi
if [ ! -d "RockShell" ]; then
    echo -e "${CROSS} Source directory 'RockShell' does not exist. Aborting deployment."
    exit 1
fi

RSYNC_ERRORS=0

# Run rsync and capture stderr to a log file for troubleshooting
RSYNC_LOG="$SCRIPT_DIR/rsync_errors.log"
rsync -avz --omit-dir-times -e "ssh -i $SSH_KEY_PATH" \
  --exclude='.git' \
  --exclude='.env' \
  --chmod=D775,F644 \
  "$PW_ROOT/" RockShell "$REMOTE_USER_HOST:$REMOTE_PATH" 2>$RSYNC_LOG
RSYNC_EXIT_CODE=$?
echo
if [ $RSYNC_EXIT_CODE -eq 0 ]; then
    echo -e "${CHECK} Deployment complete!"
else
    echo -e "${CROSS} Deployment failed! Rsync exited with code $RSYNC_EXIT_CODE."
    if grep -q 'No such file or directory' "$RSYNC_LOG"; then
        echo -e "${RED}Error: One or more source or destination directories do not exist.\nCheck your PW_ROOT, RockShell folder, and DEPLOY_PATH settings.${NC}"
    elif grep -q 'Permission denied' "$RSYNC_LOG"; then
        echo -e "${RED}Error: Permission denied.\nCheck your SSH credentials, key permissions, and server access.${NC}"
    else
        echo -e "${RED}Please check your SSH credentials, permissions, server status, and source/destination directories, then fix any issues and run the script again.${NC}"
    fi
    echo -e "${RED}See $RSYNC_LOG for details on what went wrong.${NC}"
    exit 1
fi
