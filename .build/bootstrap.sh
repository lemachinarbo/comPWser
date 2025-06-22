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

# Ensure all step scripts are executable
chmod +x "$SCRIPT_DIR/ssh_keys.sh" "$SCRIPT_DIR/github_setup.sh" "$SCRIPT_DIR/sync.sh" "$SCRIPT_DIR/setup-config.sh"

# Load .env
ENV_FILE="$SCRIPT_DIR/../.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo -e "${WARN}  Warning: .env file not found at $ENV_FILE"
fi

echo
# Step 1: SSH Key Setup
echo -ne "${GREEN}Step 1:${NC} Run SSH key setup? (y/n) [${YELLOW}y${NC}]: "
read yn1
yn1=${yn1:-y}
if [[ $yn1 =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/ssh_keys.sh" && echo -e "${CHECK} SSH key setup complete." || { echo -e "${CROSS} SSH key setup failed!"; exit 1; }
else
    echo -e "${WARN}  Skipping SSH key setup."
fi

echo
# Step 2: GitHub Actions Setup
echo -ne "${GREEN}Step 2:${NC} Run GitHub Actions setup? (y/n) [${YELLOW}y${NC}]: "
read yn2
yn2=${yn2:-y}
if [[ $yn2 =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/github_setup.sh" && echo -e "${CHECK} GitHub Actions setup complete." || { echo -e "${CROSS} GitHub setup failed!"; exit 1; }
else
    echo -e "${WARN}  Skipping GitHub Actions setup."
fi

echo
# Step 3: Create/update config-local.php from .env
echo -ne "${GREEN}Step 3:${NC} Create/update config-local.php from .env? (y/n) [${YELLOW}y${NC}]: "
read yn3
yn3=${yn3:-y}
if [[ $yn3 =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/setup-config.sh"
else
    echo -e "${WARN}  Skipping config-local.php setup."
fi

echo
# Step 4: Sync files (deploy)
echo -ne "${GREEN}Step 4:${NC} Sync files and deploy? (y/n) [${YELLOW}y${NC}]: "
read yn4
yn4=${yn4:-y}
if [[ $yn4 =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/sync.sh" && echo -e "${CHECK} File sync complete." || { echo -e "${CROSS} File sync failed!"; exit 1; }
else
    echo -e "${WARN}  Skipping file sync."
fi

echo
# Step 5: Database import
echo -ne "${GREEN}Step 5:${NC} Import database using RockShell db:restore? (y/n) [${YELLOW}n${NC}]: "
read yn5
yn5=${yn5:-n}
if [[ $yn5 =~ ^[Yy]$ ]]; then
    ssh -i "$HOME/.ssh/${SSH_KEY:-id_rsa}" "$SSH_USER@$SSH_HOST" "cd $DEPLOY_PATH && php RockShell/rock db:restore" && echo -e "${CHECK} Database import complete." || echo -e "${CROSS} Database import failed!"
else
    echo -e "${WARN}  Skipping database import."
fi

echo
# Step 6: RockShell transform
echo -ne "${GREEN}Step 6:${NC} Apply RockShell transform (php RockShell/rock rm:transform)? (y/n) [${YELLOW}y${NC}]: "
read yn6
yn6=${yn6:-y}
if [[ $yn6 =~ ^[Yy]$ ]]; then
    ssh -i "$HOME/.ssh/${SSH_KEY:-id_rsa}" "$SSH_USER@$SSH_HOST" "cd $DEPLOY_PATH && php RockShell/rock rm:transform" && echo -e "${CHECK} RockShell transformation complete." || echo -e "${CROSS} RockShell transformation failed!"
else
    echo -e "${WARN}  Skipping RockShell transformation."
fi

echo -e "\n${GREEN}🎉 All selected steps completed!${NC}\n"
