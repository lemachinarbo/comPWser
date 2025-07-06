#!/bin/bash

# setup.sh - Orchestrates all setup and deployment steps with user confirmation and environment selection

set -e

# Source common logging/colors and env helpers
source "$(cd "$(dirname "$0")" && pwd)/scripts/common.sh"

log_header "Welcome to the ComPWser Environment Setup tool"
log_info "This script will guide you through setting up your environment for automated deployments."
log_hr

# Requirements check
log_header "Checking for requirements:"
REQUIREMENTS_OK=true

# .env file check
if [ -f "$ENV_FILE" ]; then
    log_ok ".env file found at $ENV_FILE."
    source "$ENV_FILE"
else
    log_error ".env file not found at $ENV_FILE. Aborting."
    exit 1
fi

# Now check for required variables
if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ]; then
    log_error "GITHUB_OWNER or GITHUB_REPO not set in .env. Please set these variables and try again."
    exit 1
fi

# Check personal SSH key
if [ -f "$HOME/.ssh/id_ed25519" ]; then
    log_ok "Personal SSH key (id_ed25519) found."
    HAS_PERSONAL_KEY=true
else
    log_error "Personal SSH key (id_ed25519) not found."
    HAS_PERSONAL_KEY=false
    REQUIREMENTS_OK=false
fi

# Check project SSH key
if [ -f "$HOME/.ssh/id_github" ]; then
    log_ok "Project SSH key (id_github) found."
    HAS_PROJECT_KEY=true
else
    log_error "Project SSH key (id_github) not found."
    HAS_PROJECT_KEY=false
    REQUIREMENTS_OK=false
fi

# Check GitHub CLI
if command -v gh >/dev/null 2>&1; then
    log_ok "GitHub CLI (gh) is installed."
    HAS_GH=true
else
    log_error "GitHub CLI (gh) is not installed."
    HAS_GH=false
    REQUIREMENTS_OK=false
fi

# Check if the repository exists and is accessible (only if gh is installed)
if [ "$HAS_GH" = true ]; then
    GH_API_OUTPUT=$(mktemp)
    set +e
    gh api repos/$GITHUB_OWNER/$GITHUB_REPO >"$GH_API_OUTPUT" 2>&1
    REPO_CHECK_EXIT=$?
    set -e
    REPO_CHECK_ERR=$(cat "$GH_API_OUTPUT")
    rm "$GH_API_OUTPUT"
    if [ $REPO_CHECK_EXIT -ne 0 ]; then
        log_error "Repository $GITHUB_OWNER/$GITHUB_REPO not found or you do not have access. \n Details:$REPO_CHECK_ERR\nPlease check your .env file, repo visibility, and GitHub permissions."
        REQUIREMENTS_OK=false
    else
        log_ok "Repository $GITHUB_OWNER/$GITHUB_REPO found and accessible."
        # Check if the repository has at least one branch
        BRANCHES=($(gh api repos/$GITHUB_OWNER/$GITHUB_REPO/branches --jq '.[].name'))
        if [ ${#BRANCHES[@]} -eq 0 ]; then
            log_error "Repository $GITHUB_OWNER/$GITHUB_REPO has no branches. Please create a main branch and push it to GitHub before running this script."
            REQUIREMENTS_OK=false
        fi
    fi
fi

# Only continue if all requirements are met
if [ "$REQUIREMENTS_OK" = false ]; then
    log_fatal "Some requirements are missing or invalid. Please fix them and rerun the script."
    exit 1
fi

echo
# Offer to generate SSH keys if missing
if [ "$HAS_PERSONAL_KEY" = false ] || [ "$HAS_PROJECT_KEY" = false ]; then
    log_ask "Do you want us to generate the missing SSH keys for you? [y]: "
    read gen_keys
    gen_keys=${gen_keys:-y}
    if [[ $gen_keys =~ ^[Yy]$ ]]; then
        "$SCRIPT_DIR/sshkeys-generate.sh" || { log_error "SSH key generation failed!"; exit 1; }
    else
        log_warn "You must generate the required SSH keys before continuing. Exiting."
        exit 1
    fi
fi

# Offer to install gh if missing
if [ "$HAS_GH" = false ]; then
    log_info "GitHub CLI (gh) is required but not installed.\nPlease install it to proceed.\nSee: https://github.com/cli/cli?tab=readme-ov-file#installation"
    exit 1
fi

log_success "All requirements met. Let's start environment setup.\n"

# Use ENVIRONMENTS variable from .env to get valid environment list
if [ -z "$ENVIRONMENTS" ]; then
    log_error "No ENVIRONMENTS variable found in .env. Please define it (e.g., ENVIRONMENTS=\"PROD STAGING TESTING\")."
    exit 1
fi

read -ra ENVS <<< "$ENVIRONMENTS"

# Prompt for environment if not provided as argument
if [ -n "$1" ]; then
    ENV="$1"
else
    log_header "Which environment do you want to setup?"
    for i in "${!ENVS[@]}"; do
        printf "    %d) %s\n" "$((i+1))" "${ENVS[$i]}"
    done
    log_ask "Environment number [1]: "
    read env_choice
    env_choice=${env_choice:-1}
    if [[ "$env_choice" =~ ^[0-9]+$ ]] && (( env_choice >= 1 && env_choice <= ${#ENVS[@]} )); then
        ENV="${ENVS[$((env_choice-1))]}"
    else
        log_error "Invalid selection. Exiting."
        exit 1
    fi
fi

# Ensure all step scripts are executable
chmod +x "$SCRIPT_DIR/deploy.sh" "$SCRIPT_DIR/config-local.sh" "$SCRIPT_DIR/sync.sh" "$SCRIPT_DIR/sshkeys-generate.sh" "$SCRIPT_DIR/sshkeys-register.sh" "$SCRIPT_DIR/workflows.sh"

echo
# Step 0: Register SSH keys with the server
log_header "Registering SSH Keys"
log_info "Allows automated deployments with passwordless SSH access."
log_hr
log_ask "Add keys now? [Y/n]: "
read yn0
yn0=${yn0:-y}
if [[ $yn0 =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/sshkeys-register.sh" "$ENV"
    if [ $? -eq 0 ]; then
        log_success "SSH key registration and authentication test complete."
    else
        log_error "SSH key registration failed!"
        exit 1
    fi
else
    log_warn "Skipping SSH key registration."
fi

echo
# Step 1: GitHub Actions Setup
log_header "GitHub Actions Setup"
log_info "Automated deployment requires secrets and variables set in the GitHub $ENV environment"
log_hr
log_ask "Run GitHub Actions setup? [Y/n]: "
read yn1
yn1=${yn1:-y}
if [[ $yn1 =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/deploy.sh" "$ENV" &&   log_success "All GitHub Actions variables and secrets have been processed successfully." || { log_error "GitHub setup failed!"; exit 1; }
else
    log_warn "Skipping GitHub Actions setup."
fi

echo
# Step 1.5: GitHub Workflows Setup
log_header "GitHub Workflows Setup"
log_info "To trigger automated deployments, link a branch to the $ENV environment in GitHub."
log_hr
log_ask "Select branch now? [Y/n]: "
read yn1_5
yn1_5=${yn1_5:-y}
if [[ $yn1_5 =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/workflows.sh" "$ENV" && log_success "GitHub Actions workflow files generated successfully." || { log_error "Workflow file generation failed!"; exit 1; }
else
    log_warn "Skipping GitHub Actions workflow file generation."
fi

echo
# Step 2: Create/update config-local.php from .env
log_header "Config File Setup"
log_info "To separate local and production settings, your config.php will be split, creating a config-local.php for environment-specific overrides."
log_hr
log_ask "Create config-local.php? [Y/n]: "
read yn2
yn2=${yn2:-y}
if [[ $yn2 =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/config-local.sh" "$ENV" && log_success "config-local setup complete." || { log_error "config-local.php setup failed!"; exit 1; }
else
    log_warn "Skipping config-local.php setup."
fi

echo
# Step 3: Sync files (deploy)
log_header "File Sync"
log_info "To deploy your site, all project files need to be uploaded and synced to the $ENV server."
log_hr
log_ask "Sync files and deploy to server? [Y/n]: "
read yn3
yn3=${yn3:-y}
if [[ $yn3 =~ ^[Yy]$ ]]; then
    "$SCRIPT_DIR/sync.sh" "$ENV" && log_ok "File sync complete." || { log_error "File sync failed!"; exit 1; }
else
    log_warn "Skipping file sync."
fi

echo
# Step 4: Database import
log_header "Database Import"
log_info "Import local database to $ENV server to run the site."
log_hr
log_ask "Import now? [Y/n]: "
read yn4
yn4=${yn4:-y}
if [[ $yn4 =~ ^[Yy]$ ]]; then
    PREFIX="${ENV}_"
    SSH_USER="$(get_env SSH_USER)"
    SSH_HOST="$(get_env SSH_HOST)"
    DEPLOY_PATH="$(get_env PATH)"
    DB_NAME="$(get_env DB_NAME)"
    DB_USER="$(get_env DB_USER)"
    DB_PASS="$(get_env DB_PASS)"
    if [ -z "$SSH_USER" ] || [ -z "$SSH_HOST" ] || [ -z "$DEPLOY_PATH" ] || [ -z "$DB_NAME" ] || [ -z "$DB_USER" ] || [ -z "$DB_PASS" ]; then
        log_error "One or more required variables (SSH_USER, SSH_HOST, DEPLOY_PATH, DB_NAME, DB_USER, DB_PASS) are empty. Check your .env file for all required variables."
        exit 1
    fi
    ssh -i "$HOME/.ssh/id_github" "$SSH_USER@$SSH_HOST" "cd $DEPLOY_PATH && mysql -u$DB_USER -p'$DB_PASS' $DB_NAME < site/assets/backups/database/db.sql" && log_ok "Database import complete." || log_error "Database import failed!"
else
    log_warn "Skipping database import."
fi

echo
# Step 5: Update server folder structure for automated deployments and fix permissions
log_header "Environment Folder Structure"
log_info "A new folder structure is required on the $ENV server for multi-version deployments."
log_hr
log_ask "Update folder structure? [Y/n]: "
read yn5
yn5=${yn5:-y}
if [[ $yn5 =~ ^[Yy]$ ]]; then
    PREFIX="${ENV}_"
    SSH_USER="$(get_env SSH_USER)"
    SSH_HOST="$(get_env SSH_HOST)"
    DEPLOY_PATH="$(get_env PATH)"
    if [ -z "$SSH_USER" ] || [ -z "$SSH_HOST" ] || [ -z "$DEPLOY_PATH" ]; then
        log_error "One or more required variables (SSH_USER, SSH_HOST, DEPLOY_PATH) are empty. Check your .env file for ${ENV}_SSH_USER, ${ENV}_SSH_HOST, and ${ENV}_PATH."
        exit 1
    fi
    ssh -i "$HOME/.ssh/id_github" "$SSH_USER@$SSH_HOST" "cd $DEPLOY_PATH && php RockShell/rock rm:transform && find . -type d -exec chmod 755 {} \; && find . -type f -exec chmod 644 {} \;"
    log_ok "Server file structure updated and permissions set: directories=755, files=644."
else
    log_warn "Skipping server file structure update and permissions fix."
fi
echo
log_success "All selected steps completed!"
log_info "Reminder: Commit and push your changes to the repository to test the deployment workflows."
