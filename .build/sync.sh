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

echo -e "${YELLOW} Deploying to production server...${NC}"
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

RSYNC_ERRORS=0

# Run rsync and capture stderr to a log file for troubleshooting
rsync -avz --omit-dir-times -e "ssh -i $SSH_KEY_PATH" \
  --exclude='.git' \
  --exclude='.env' \
  --chmod=D775,F644 \
  "$PW_ROOT/" RockShell "$REMOTE_USER_HOST:$REMOTE_PATH" 2>rsync_errors.log
RSYNC_EXIT_CODE=$?
echo
if [ $RSYNC_EXIT_CODE -eq 0 ]; then
    echo -e "${CHECK} Deployment complete!"
else
    echo -e "${CROSS} Deployment failed! Rsync exited with code $RSYNC_EXIT_CODE."
    echo -e "${RED}Please check your SSH credentials, permissions, and server status, then fix any issues and run the script again.${NC}"
    echo -e "${RED}See rsync_errors.log for details on what went wrong.${NC}"
    exit 1
fi
