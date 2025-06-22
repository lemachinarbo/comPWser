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

echo -e "${YELLOW}🚀 Deploying to production server...${NC}"
echo -e "Using SSH key: $SSH_KEY_PATH"
echo -e "Deploying to: $REMOTE_USER_HOST:$REMOTE_PATH"

echo
# Comment out problematic .htaccess line before deployment
if [ -f ".htaccess" ]; then
    # Only comment out if it's not already commented
    if grep -q "^Options +FollowSymLinks" .htaccess; then
        echo -e "${YELLOW}📝 Commenting out 'Options +FollowSymLinks' in .htaccess...${NC}"
        sed -i 's/^Options +FollowSymLinks/# Options +FollowSymLinks/' .htaccess
    fi
    
    # Only uncomment if it's currently commented
    if grep -q "^# Options +SymLinksIfOwnerMatch" .htaccess; then
        echo -e "${YELLOW}📝 Uncommenting 'Options +SymLinksIfOwnerMatch' in .htaccess...${NC}"
        sed -i 's/^# Options +SymLinksIfOwnerMatch/Options +SymLinksIfOwnerMatch/' .htaccess
    fi
fi

echo
# Change to project root so rsync can find public and RockShell
cd "$(dirname "$0")/.."

rsync -avz -e "ssh -i $SSH_KEY_PATH" \
  --exclude='.git' \
  --exclude='.env' \
  --chmod=D775,F664 \
  "$PW_ROOT"/ RockShell "$REMOTE_USER_HOST:$REMOTE_PATH"

# Check if rsync succeeded
echo
if [ $? -eq 0 ]; then
    echo -e "${CHECK} Deployment complete!"
else
    echo -e "${CROSS} Deployment failed!"
    exit 1
fi
