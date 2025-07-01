#!/bin/bash

# workflows.sh - Generates GitHub Actions workflow YAMLs for each environment/branch pair

# Source common logging/colors and env helpers
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

WORKFLOWS_DIR="$SCRIPT_DIR/../.github/workflows"
mkdir -p "$WORKFLOWS_DIR"

# Load environments and repo info from .env
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    log_error ".env file not found at $ENV_FILE. Aborting."
    exit 1
fi

if [ -z "$ENVIRONMENTS" ]; then
    log_error "ENVIRONMENTS variable not set in .env."
    exit 1
fi
if [ -z "$GITHUB_OWNER" ] || [ -z "$GITHUB_REPO" ]; then
    log_error "GITHUB_OWNER or GITHUB_REPO not set in .env."
    exit 1
fi

# Robust check if the repository exists and is accessible before starting environment setup
REPO_CHECK_ERR=$(gh api repos/$GITHUB_OWNER/$GITHUB_REPO 2>&1)
if [ $? -ne 0 ]; then
    log_error "Repository $GITHUB_OWNER/$GITHUB_REPO not found or you do not have access. Details:\n$REPO_CHECK_ERR\nPlease check your .env file, repo visibility, and GitHub permissions."
    exit 1
fi
# Check if the repository has at least one branch
BRANCHES=($(gh api repos/$GITHUB_OWNER/$GITHUB_REPO/branches --jq '.[].name'))
if [ ${#BRANCHES[@]} -eq 0 ]; then
    log_fatal "Repository $GITHUB_OWNER/$GITHUB_REPO has no branches. Please create a main branch and push it to GitHub before running this script."
    exit 1
fi

# Use the environment passed as an argument
ENV="$1"
if [ -z "$ENV" ]; then
    log_fatal "No environment specified. Please run this script with the environment name as an argument."
    exit 1
fi

# Only allow selection from existing branches, but allow creating a new one if desired
BRANCHES=($(gh api repos/$GITHUB_OWNER/$GITHUB_REPO/branches --jq '.[].name'))
log_info "\nAvailable branches in $GITHUB_REPO (fetched from remote):"
for i in "${!BRANCHES[@]}"; do
    printf "    %d) %s\n" "$((i+1))" "${BRANCHES[$i]}"
    done
printf "    %d) Create new branch...\n" "$(( ${#BRANCHES[@]} + 1 ))"
log_ask "Select the branch to link to $ENV [1]: "
read branch_choice
branch_choice=${branch_choice:-1}
if [[ "$branch_choice" =~ ^[0-9]+$ ]] && (( branch_choice >= 1 && branch_choice <= $((${#BRANCHES[@]}+1)) )); then
    if (( branch_choice == ${#BRANCHES[@]} + 1 )); then
        log_ask "Enter the new branch name for $ENV: "
        read NEW_BRANCH
        NEW_BRANCH=${NEW_BRANCH// /-}
        log_ask "Base new branch on which existing branch? (default: main): "
        read BASE_BRANCH
        BASE_BRANCH=${BASE_BRANCH:-main}
        BASE_SHA=$(gh api repos/$GITHUB_OWNER/$GITHUB_REPO/branches/$BASE_BRANCH --jq .commit.sha)
        gh api -X POST repos/$GITHUB_OWNER/$GITHUB_REPO/git/refs -f ref="refs/heads/$NEW_BRANCH" -f sha="$BASE_SHA" >/dev/null 2>&1
        if git rev-parse --is-inside-work-tree >/dev/null 2>&1 && git remote get-url origin >/dev/null 2>&1; then
            git fetch origin "$NEW_BRANCH:$NEW_BRANCH" 2>/dev/null
        fi
        BRANCH="$NEW_BRANCH"
    else
        BRANCH="${BRANCHES[$((branch_choice-1))]}"
    fi
else
    log_error "Invalid selection. Exiting."
    exit 1
fi

# Generate workflow file from template (after branch selection)
TEMPLATE_FILE="$SCRIPT_DIR/../.build/workflow.template.yaml"
WORKFLOW_FILE="$WORKFLOWS_DIR/${ENV,,}.yaml"
if [ ! -f "$TEMPLATE_FILE" ]; then
    log_error "Workflow template $TEMPLATE_FILE not found."
    exit 1
fi
sed \
    -e "s|main|$BRANCH|g" \
    -e "s|deploy.yaml.path|$GITHUB_OWNER/$GITHUB_REPO/.github/workflows/deploy.yaml@$BRANCH|g" \
    -e "s|Deploy|Deploy $ENV|g" \
    "$TEMPLATE_FILE" > "$WORKFLOW_FILE"
log_ok "Workflow for $ENV created at $WORKFLOW_FILE (triggers on branch: $BRANCH)"

# Ensure deploy.yaml reusable workflow is in .github/workflows/ (do this after creating the env workflow)
DEPLOY_WORKFLOW="$SCRIPT_DIR/../.github/workflows/deploy.yaml"
DEPLOY_BUILD="$SCRIPT_DIR/../.build/deploy.yaml"
if [ ! -f "$DEPLOY_WORKFLOW" ]; then
    if [ -f "$DEPLOY_BUILD" ]; then
        mv "$DEPLOY_BUILD" "$DEPLOY_WORKFLOW"
        log_ok "Moved deploy.yaml reusable workflow to .github/workflows/deploy.yaml."
    else
        log_error "deploy.yaml not found in .build or .github/workflows. Please add it manually."
        exit 1
    fi
else
    log_warn "deploy.yaml workflow already present in .github/workflows."
fi
