#!/bin/bash

# bootstrap.sh - Orchestrates all setup and deployment steps with user confirmation

set -e

# Colors and symbols
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Load .env
ENV_FILE="$SCRIPT_DIR/../.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo -e "${WARN}  Warning: .env file not found at $ENV_FILE"
fi

# Ensure all step scripts are executable
chmod +x "$SCRIPT_DIR/deploy.sh" "$SCRIPT_DIR/config-local.sh" "$SCRIPT_DIR/sync.sh" "$SCRIPT_DIR/sshkeys.sh"

echo
# Step 1: GitHub Actions Setup
echo -ne "${GREEN}Step 1/5:${NC} Run GitHub Actions setup? (y/n) [${YELLOW}y${NC}]: "
read yn1
yn1=${yn1:-y}
if [[ $yn1 =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/deploy.sh" && echo -e "${CHECK} GitHub Actions setup complete." || { echo -e "${CROSS} GitHub setup failed!"; exit 1; }
else
    echo -e "${WARN}  Skipping GitHub Actions setup."
fi

echo
# Step 2: Create/update config-local.php from .env
echo -ne "${GREEN}Step 2/5:${NC} Create/update config-local.php from .env? (y/n) [${YELLOW}y${NC}]: "
read yn2
yn2=${yn2:-y}
if [[ $yn2 =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/config-local.sh" && echo -e "${CHECK} config-local.php setup complete." || { echo -e "${CROSS} config-local.php setup failed!"; exit 1; }
else
    echo -e "${WARN}  Skipping config-local.php setup."
fi

echo
# Step 3: Sync files (deploy)
echo -ne "${GREEN}Step 3/5:${NC} Sync files and deploy to server? (y/n) [${YELLOW}y${NC}]: "
read yn3
yn3=${yn3:-y}
if [[ $yn3 =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/sync.sh" && echo -e "${CHECK} File sync complete." || { echo -e "${CROSS} File sync failed!"; exit 1; }
else
    echo -e "${WARN}  Skipping file sync."
fi

echo
# Step 4: Database import
echo -ne "${GREEN}Step 4/5:${NC} Import ProcessWire database to the server? (y/n) [${YELLOW}y${NC}]: "
read yn4
yn4=${yn4:-y}
if [[ $yn4 =~ ^[Yy]$ ]]; then
    ssh -i "$HOME/.ssh/${SSH_KEY:-id_rsa}" "$SSH_USER@$SSH_HOST" "cd $DEPLOY_PATH && php RockShell/rock db:restore" && echo -e "${CHECK} Database import complete." || echo -e "${CROSS} Database import failed!"
else
    echo -e "${WARN}  Skipping database import."
fi

echo
# Step 5: Update server file structure for automated deployments and fix permissions
echo -ne "${GREEN}Step 5/5:${NC} Update server file structure for automated deployments? (y/n) [${YELLOW}y${NC}]: "
read yn5
yn5=${yn5:-y}
if [[ $yn5 =~ ^[Yy]$ ]]; then
    ssh -i "$HOME/.ssh/${SSH_KEY:-id_rsa}" "$SSH_USER@$SSH_HOST" "cd $DEPLOY_PATH && php RockShell/rock rm:transform && find . -type d -exec chmod 755 {} \; && find . -type f -exec chmod 644 {} \;"
    echo -e "${CHECK} Server file structure updated and permissions set: directories=755, files=644."
else
    echo -e "${WARN}  Skipping server file structure update and permissions fix."
fi

echo -e "\n${CHECK} All selected steps completed!"
echo -e "\n${YELLOW}Reminder:${NC} Please commit and push your changes to the repository to activate the deployment workflows.\n"
