#!/bin/bash

# deploy.sh - Automates the setup of GitHub Actions repository variables and secrets for deployment using the GitHub CLI (gh), with multi-environment support

# Source common logging/colors and env helpers
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

# Dependency check for gh
if ! command -v gh >/dev/null 2>&1; then
  log_error "GitHub CLI (gh) is not installed or not in your PATH. Please install it and rerun this script.\nIf gh is not installed, visit https://github.com/cli/cli#installation for installation instructions."
  exit 1
fi

# Check if gh is authenticated
if ! gh auth status >/dev/null 2>&1; then
  log_error "GitHub CLI (gh) is not authenticated. Please run 'gh auth login' to authenticate, and ensure you have access to the repository."
  exit 1
fi

# Detect available environments from .env (e.g., PROD_, STAGING_, etc.)
ENVS=$(grep -oE '^[A-Z]+_' "$ENV_FILE" | cut -d_ -f1 | sort | uniq)

# Prompt for environment if not provided as argument
if [ -n "$1" ]; then
    ENV="$1"
else
    log_ask "Select environment number: "
    select ENV in "${ENVS[@]}"; do
        if [ -n "$ENV" ]; then
            break
        else
            log_error "Invalid selection. Please enter a valid number."
        fi
    done
fi
PREFIX="${ENV}_"

# SSH_KEY logic: support .env SSH_KEY as filename or path
SSH_KEY="$(get_env SSH_KEY)"
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
  log_error "SSH key not found at $SSH_KEY_PATH. Aborting."
  exit 1
fi
SSH_KEY_CONTENT=$(cat "$SSH_KEY_PATH")

# Use global variables only (no environment-prefixed PW_ROOT support yet)
SSH_HOST="$(get_env SSH_HOST)"
SSH_USER="$(get_env SSH_USER)"
DEPLOY_PATH="$(get_env PATH)"
PW_ROOT="$PW_ROOT"

# Check required variables and give informative error if missing
for var in SSH_HOST SSH_USER DEPLOY_PATH GITHUB_OWNER GITHUB_REPO; do
  value="$(eval echo \$$var)"
  
  env_var="${PREFIX}${var}"
  if [ -z "$value" ]; then
    log_error "$var is not set (expected env variable: $env_var) in your .env file. Please check your .env file."
    exit 1
  fi
done

# 2. KNOWN_HOSTS (generate from SSH_HOST)
if [ -z "$SSH_HOST" ]; then
  read -p "Required value SSH_HOST (your SSH host) missing from .env. Aborting. Enter your SSH_HOST (e.g. example.com): " SSH_HOST
fi
if [ -z "$SSH_HOST" ]; then
  log_error "Required value SSH_HOST (your SSH host) missing from .env. Aborting."
  exit 1
fi
KNOWN_HOSTS=$(ssh-keyscan "$SSH_HOST" 2>/dev/null)
if [ -z "$KNOWN_HOSTS" ]; then
  log_error "Could not generate KNOWN_HOSTS for $SSH_HOST. Aborting."
  exit 1
fi

REPO_FULL="$GITHUB_OWNER/$GITHUB_REPO"

log_info "\nSummary of values to be uploaded to GitHub:"
log_info "- SSH_KEY: $SSH_KEY_PATH"
log_info "- KNOWN_HOSTS: (generated for $SSH_HOST)"
log_info "- SSH_HOST: $SSH_HOST"
log_info "- SSH_USER: $SSH_USER"
log_info "- DEPLOY_PATH: $DEPLOY_PATH"
log_info "- PW_ROOT: $PW_ROOT"
log_info "- GITHUB_OWNER: $GITHUB_OWNER"
log_info "- GITHUB_REPO: $GITHUB_REPO"

ERRORS=0

log_info "\nUploading repository secrets to GitHub..."
# Upload repository secrets to GitHub

# Upload CI_TOKEN as a global repository secret (shared by all environments)
if [ -z "$CI_TOKEN" ]; then
  read -s -p "Enter your CI_TOKEN (GitHub Personal Access Token for CI): " CI_TOKEN
  echo
fi
gh secret set CI_TOKEN --body "$CI_TOKEN" --repo "$REPO_FULL" || { log_error "Failed to set CI_TOKEN"; ERRORS=$((ERRORS+1)); }

# Create the GitHub environment if it doesn't exist

echo
GITHUB_ENV_API="/repos/$GITHUB_OWNER/$GITHUB_REPO/environments/$ENV"
log_info "Ensuring GitHub environment '$ENV' exists..."
gh api --method PUT -H "Accept: application/vnd.github+json" "$GITHUB_ENV_API" >/dev/null 2>&1 && log_ok "Environment '$ENV' ensured on GitHub." || log_error "Failed to create or access environment '$ENV' on GitHub."

# Upload environment-scoped variables to GitHub

log_info "\nUploading environment variables to GitHub environment '$ENV'..."
gh variable set SSH_HOST --env "$ENV" --body "$SSH_HOST" --repo "$REPO_FULL" || { log_error "Failed to set SSH_HOST"; ERRORS=$((ERRORS+1)); }
gh variable set SSH_USER --env "$ENV" --body "$SSH_USER" --repo "$REPO_FULL" || { log_error "Failed to set SSH_USER"; ERRORS=$((ERRORS+1)); }
gh variable set DEPLOY_PATH --env "$ENV" --body "$DEPLOY_PATH" --repo "$REPO_FULL" || { log_error "Failed to set DEPLOY_PATH"; ERRORS=$((ERRORS+1)); }
gh variable set PW_ROOT --env "$ENV" --body "$PW_ROOT" --repo "$REPO_FULL" || { log_error "Failed to set PW_ROOT"; ERRORS=$((ERRORS+1)); }

log_info "\nUploading environment secrets to GitHub environment '$ENV'..."
gh secret set SSH_KEY --env "$ENV" --body "$SSH_KEY_CONTENT" --repo "$REPO_FULL" || { log_error "Failed to set SSH_KEY"; ERRORS=$((ERRORS+1)); }
gh secret set KNOWN_HOSTS --env "$ENV" --body "$KNOWN_HOSTS" --repo "$REPO_FULL" || { log_error "Failed to set KNOWN_HOSTS"; ERRORS=$((ERRORS+1)); }

if [ $ERRORS -eq 0 ]; then
  log_ok "Environment variables and secrets upload complete."
else
  log_error "Environment variables and secrets upload completed with $ERRORS error(s)."
fi

# Removed workflow file moving/updating logic. Now handled by workflows.sh

if [ $ERRORS -ne 0 ]; then
  log_error "There were $ERRORS error(s) during the process. Please review the messages above, fix any issues, and run the script again."
  exit 1
fi
