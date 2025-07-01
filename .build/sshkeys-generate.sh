#!/bin/bash

# sshkeys-generate.sh - Generates personal and project SSH keys if they do not exist

# Source common logging/colors and env helpers
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

PERSONAL_KEY="$HOME/.ssh/id_ed25519"
PROJECT_KEY="$HOME/.ssh/id_github"

# 1. Create personal key (id_ed25519)
echo
if [ -f "$PERSONAL_KEY" ]; then
  log_ok "Personal SSH key $PERSONAL_KEY already exists, skipping generation."
else
  read -p "Enter your email for the personal SSH key: " EMAIL
  ssh-keygen -t ed25519 -f "$PERSONAL_KEY" -C "$EMAIL"
  log_ok "Personal SSH key $PERSONAL_KEY generated."
fi

# 2. Create project key (id_github)
if [ -f "$PROJECT_KEY" ]; then
  log_ok "Project SSH key $PROJECT_KEY already exists, skipping generation."
else
  ssh-keygen -t ed25519 -f "$PROJECT_KEY" -C "Deployment Key"
  log_ok "Project SSH key $PROJECT_KEY generated."
fi

echo
log_success "SSH key generation complete."
