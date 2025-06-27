#!/bin/bash

# deploy.sh
#
# Automates the setup of GitHub Actions repository variables and secrets for deployment using the GitHub CLI (gh).
#
# Requirements:
#   - gh (GitHub CLI) installed and authenticated (https://cli.github.com/)
#   - .env file with the following variables (or you will be prompted):
#       SSH_HOST      # Your server's hostname (e.g. example.com)
#       SSH_USER      # SSH username for your server
#       DEPLOY_PATH   # Path to your website on the server (e.g. /var/www/example.com)
#       PW_ROOT       # ProcessWire root path (e.g. public)
#       GITHUB_OWNER  # GitHub username or organization
#       GITHUB_REPO   # GitHub repository name
#       CI_TOKEN      # (Optional) GitHub Personal Access Token for CI (will be prompted if not set)
#
# Usage:
#   1. Ensure gh is installed and authenticated (run: gh auth login).
#   2. Fill out .env or run the script and follow prompts.
#   3. Run: ./deploy.sh
#
# This script will:
#   - Load variables from .env or prompt for them
#   - Use ~/.ssh/id_github as the default SSH key (or prompt for another)
#   - Generate KNOWN_HOSTS from SSH_HOST
#   - Upload variables and secrets to your GitHub repository using gh
#   - Prompt for CI_TOKEN if not set, and upload as a secret

# Colors and symbols
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color
CHECK="${GREEN}✓${NC}"
CROSS="${RED}✗${NC}"
WARN="${YELLOW}⚠${NC}"

# Dependency check for gh
if ! command -v gh >/dev/null 2>&1; then
  echo -e "${CROSS} GitHub CLI (gh) is not installed or not in your PATH. Please install it and rerun this script.\nIf gh is not installed, visit https://github.com/cli/cli#installation for installation instructions."
  exit 1
fi

# Check if gh is authenticated
if ! gh auth status >/dev/null 2>&1; then
  echo -e "${CROSS} GitHub CLI (gh) is not authenticated. Please run 'gh auth login' to authenticate, and ensure you have access to the repository."
  exit 1
fi

# Load variables from .env if present
ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
  echo -e "${YELLOW}Loading variables from $ENV_FILE...${NC}"
  source "$ENV_FILE"
else
  echo -e "${WARN} .env file not found at $ENV_FILE. Aborting.\nYou must create a .env file with the required variables for this script to work.\nSee .env.example for guidance."
  exit 1
fi

# SSH_KEY logic: support .env SSH_KEY as filename or path
if [ -n "$SSH_KEY" ]; then
  if [[ "$SSH_KEY" == */* ]]; then
    SSH_KEY_PATH="$SSH_KEY"
  else
    SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY"
  fi
else
  SSH_KEY_PATH="$HOME/.ssh/id_github"
fi

if [ ! -f "$SSH_KEY_PATH" ]; then
  read -p "SSH private key not found at $SSH_KEY_PATH. Enter path to your SSH private key: " SSH_KEY_PATH
fi
if [ ! -f "$SSH_KEY_PATH" ]; then
  echo -e "${CROSS} SSH key not found at $SSH_KEY_PATH. Aborting."
  exit 1
fi
SSH_KEY_CONTENT=$(cat "$SSH_KEY_PATH")

# 2. KNOWN_HOSTS (generate from SSH_HOST)
if [ -z "$SSH_HOST" ]; then
  read -p "Required value SSH_HOST (your SSH host) missing from .env. Aborting. Enter your SSH_HOST (e.g. example.com): " SSH_HOST
fi
if [ -z "$SSH_HOST" ]; then
  echo -e "${CROSS} Required value SSH_HOST (your SSH host) missing from .env. Aborting."
  exit 1
fi
KNOWN_HOSTS=$(ssh-keyscan "$SSH_HOST" 2>/dev/null)
if [ -z "$KNOWN_HOSTS" ]; then
  echo -e "${CROSS} Could not generate KNOWN_HOSTS for $SSH_HOST. Aborting."
  exit 1
fi

# 3. SSH_USER
if [ -z "$SSH_USER" ]; then
  read -p "Required value SSH_USER (your SSH user) missing from .env. Aborting. Enter your SSH_USER: " SSH_USER
fi
if [ -z "$SSH_USER" ]; then
  echo -e "${CROSS} Required value SSH_USER (your SSH user) missing from .env. Aborting."
  exit 1
fi

# 4. DEPLOY_PATH
if [ -z "$DEPLOY_PATH" ]; then
  read -p "Required value DEPLOY_PATH (your deploy path) missing from .env. Aborting. Enter your DEPLOY_PATH: " DEPLOY_PATH
fi
if [ -z "$DEPLOY_PATH" ]; then
  echo -e "${CROSS} Required value DEPLOY_PATH (your deploy path) missing from .env. Aborting."
  exit 1
fi

# 5. GITHUB_OWNER
if [ -z "$GITHUB_OWNER" ]; then
  read -p "Required value GITHUB_OWNER (your GitHub repository owner) missing from .env. Aborting. Enter your GitHub repository owner (username or org): " GITHUB_OWNER
fi
if [ -z "$GITHUB_OWNER" ]; then
  echo -e "${CROSS} Required value GITHUB_OWNER (your GitHub repository owner) missing from .env. Aborting."
  exit 1
fi

# 6. GITHUB_REPO
if [ -z "$GITHUB_REPO" ]; then
  read -p "Required value GITHUB_REPO (your GitHub repository name) missing from .env. Aborting. Enter your GitHub repository name: " GITHUB_REPO
fi
if [ -z "$GITHUB_REPO" ]; then
  echo -e "${CROSS} Required value GITHUB_REPO (your GitHub repository name) missing from .env. Aborting."
  exit 1
fi

# 7. PW_ROOT
if [ -z "$PW_ROOT" ]; then
  read -p "Required value PW_ROOT (your PW_ROOT) missing from .env. Aborting. Enter your PW_ROOT (ProcessWire root path, e.g. public): " PW_ROOT
fi
if [ -z "$PW_ROOT" ]; then
  echo -e "${CROSS} Required value PW_ROOT (your PW_ROOT) missing from .env. Aborting."
  exit 1
fi

REPO_FULL="$GITHUB_OWNER/$GITHUB_REPO"

echo
echo -e "${GREEN}Summary of values to be uploaded to GitHub:${NC}"
echo -e "- SSH_KEY: $SSH_KEY_PATH"
echo -e "- KNOWN_HOSTS: (generated for $SSH_HOST)"
echo -e "- SSH_HOST: $SSH_HOST"
echo -e "- SSH_USER: $SSH_USER"
echo -e "- DEPLOY_PATH: $DEPLOY_PATH"
echo -e "- PW_ROOT: $PW_ROOT"
echo -e "- GITHUB_OWNER: $GITHUB_OWNER"
echo -e "- GITHUB_REPO: $GITHUB_REPO"

ERRORS=0

echo -e "\n${YELLOW}Uploading repository variables to GitHub...${NC}"
gh variable set SSH_HOST --body "$SSH_HOST" --repo "$REPO_FULL" && echo -e "${CHECK} Updated variable SSH_HOST for $REPO_FULL" || { echo -e "${CROSS} Failed to set SSH_HOST"; ERRORS=$((ERRORS+1)); }
gh variable set SSH_USER --body "$SSH_USER" --repo "$REPO_FULL" && echo -e "${CHECK} Updated variable SSH_USER for $REPO_FULL" || { echo -e "${CROSS} Failed to set SSH_USER"; ERRORS=$((ERRORS+1)); }
gh variable set DEPLOY_PATH --body "$DEPLOY_PATH" --repo "$REPO_FULL" && echo -e "${CHECK} Updated variable DEPLOY_PATH for $REPO_FULL" || { echo -e "${CROSS} Failed to set DEPLOY_PATH"; ERRORS=$((ERRORS+1)); }
gh variable set PW_ROOT --body "$PW_ROOT" --repo "$REPO_FULL" && echo -e "${CHECK} Updated variable PW_ROOT for $REPO_FULL" || { echo -e "${CROSS} Failed to set PW_ROOT"; ERRORS=$((ERRORS+1)); }

if [ $ERRORS -eq 0 ]; then
  echo -e "${CHECK} Repository variables upload complete.${NC}"
else
  echo -e "${CROSS} Repository variables upload completed with $ERRORS error(s).${NC}"
fi

echo -e "\n${YELLOW}Uploading repository secrets to GitHub...${NC}"
gh secret set SSH_KEY --body "$SSH_KEY_CONTENT" --repo "$REPO_FULL" && echo -e "${CHECK} Set Actions secret SSH_KEY for $REPO_FULL" || { echo -e "${CROSS} Failed to set SSH_KEY"; ERRORS=$((ERRORS+1)); }
gh secret set KNOWN_HOSTS --body "$KNOWN_HOSTS" --repo "$REPO_FULL" && echo -e "${CHECK} Set Actions secret KNOWN_HOSTS for $REPO_FULL" || { echo -e "${CROSS} Failed to set KNOWN_HOSTS"; ERRORS=$((ERRORS+1)); }
if [ -z "$CI_TOKEN" ]; then
  read -s -p "Enter your CI_TOKEN (GitHub Personal Access Token for CI): " CI_TOKEN
  echo
fi
gh secret set CI_TOKEN --body "$CI_TOKEN" --repo "$REPO_FULL" && echo -e "${CHECK} Set Actions secret CI_TOKEN for $REPO_FULL" || { echo -e "${CROSS} Failed to set CI_TOKEN"; ERRORS=$((ERRORS+1)); }

if [ $ERRORS -eq 0 ]; then
  echo -e "${CHECK} Repository secrets upload complete.${NC}"
else
  echo -e "${CROSS} Repository secrets upload completed with $ERRORS error(s).${NC}"
fi

if [ $ERRORS -eq 0 ]; then
  echo -e "\n${GREEN}All GitHub Actions variables and secrets have been processed successfully.${NC}\n"
else
  echo -e "\n${RED}There were $ERRORS error(s) during the process. Please review the messages above, fix any issues, and run the script again.${NC}\n"
  exit 1
fi
