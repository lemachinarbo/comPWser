#!/bin/bash

# Script to create personal and project SSH keys if they do not exist, add them to a server, and test authentication

# Colors and symbols
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"

PERSONAL_KEY="$HOME/.ssh/id_ed25519"
PROJECT_KEY="$HOME/.ssh/id_github"

# Load .env if present
ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
  source "$ENV_FILE"
else
  echo -e "${WARN}  Warning: .env file not found at $ENV_FILE"
fi

echo
# 1. Create personal key (id_ed25519)
if [ -f "$PERSONAL_KEY" ]; then
  echo -e "${CHECK} Personal SSH key $PERSONAL_KEY already exists, skipping generation."
else
  read -p "Enter your email for the personal SSH key: " EMAIL
  ssh-keygen -t ed25519 -f "$PERSONAL_KEY" -C "$EMAIL"
  echo -e "${CHECK} Personal SSH key $PERSONAL_KEY generated."
fi

echo
# 2. Create project key (id_github)
if [ -f "$PROJECT_KEY" ]; then
  echo -e "${CHECK} Project SSH key $PROJECT_KEY already exists, skipping generation."
else
  ssh-keygen -t ed25519 -f "$PROJECT_KEY" -C "Deployment Key"
  echo -e "${CHECK} Project SSH key $PROJECT_KEY generated."
fi

echo
# 3. Add public keys to server
if [ -z "$SSH_USER" ]; then
  read -p "Enter your SSH_USER (e.g. user): " SSH_USER
fi
if [ -z "$SSH_HOST" ]; then
  read -p "Enter your SSH_HOST (e.g. server.com): " SSH_HOST
fi
SERVER="$SSH_USER@$SSH_HOST"

if [ -f "$PERSONAL_KEY.pub" ]; then
  echo -e "${YELLOW}Adding personal public key to $SERVER...${NC}"
  ssh-copy-id -i "$PERSONAL_KEY.pub" "$SERVER"
fi

if [ -f "$PROJECT_KEY.pub" ]; then
  echo -e "${YELLOW}Adding project public key to $SERVER...${NC}"
  ssh-copy-id -i "$PROJECT_KEY.pub" "$SERVER"
fi

echo
# 4. Test SSH authentication for both keys

echo -e "${YELLOW}Testing personal key authentication...${NC}"
ssh -i "$PERSONAL_KEY" -o BatchMode=yes -o ConnectTimeout=5 "$SERVER" true
if [ $? -eq 0 ]; then
  echo -e "${CHECK} Personal key authentication successful."
else
  echo -e "${CROSS} Personal key authentication failed."
fi

echo -e "${YELLOW}Testing project key authentication...${NC}"
ssh -i "$PROJECT_KEY" -o BatchMode=yes -o ConnectTimeout=5 "$SERVER" true
if [ $? -eq 0 ]; then
  echo -e "${CHECK} Project key authentication successful."
else
  echo -e "${CROSS} Project key authentication failed."
fi

echo -e "\n${GREEN}All SSH key operations complete.${NC}"
echo -e "Personal and project keys were created (if missing), uploaded to the server, and authentication was tested successfully."
