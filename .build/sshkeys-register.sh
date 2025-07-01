#!/bin/bash

# sshkeys-register.sh - Uploads public SSH keys to the selected environment's server and tests authentication

# Source common logging/colors and env helpers
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

# Load .env variables
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    log_warn "Warning: .env file not found at $ENV_FILE"
    exit 1
fi

PERSONAL_KEY="$HOME/.ssh/id_ed25519"
PROJECT_KEY="$HOME/.ssh/id_github"

ENVS=$(grep -oE '^[A-Z]+_' "$ENV_FILE" | cut -d_ -f1 | sort | uniq)

if [ -z "$1" ]; then
    echo "Available environments:"
    select ENV in $ENVS; do
        [ -n "$ENV" ] && break
    done
else
    ENV="$1"
fi
PREFIX="${ENV}_"

SSH_USER="$(get_env SSH_USER)"
SSH_HOST="$(get_env SSH_HOST)"
SERVER="$SSH_USER@$SSH_HOST"

# Helper to check if a public key is already registered on the server
is_key_registered() {
    local pubkey_file="$1"
    local key_label="$2"
    if [ ! -f "$pubkey_file" ]; then
        log_warn "$key_label public key not found."
        return 1
    fi
    local pubkey_content
    pubkey_content=$(cat "$pubkey_file")
    if ssh "$SERVER" "grep -qF '$pubkey_content' ~/.ssh/authorized_keys 2>/dev/null"; then
        log_warn "$key_label ssh key already registered. Skipping registration."
        return 0
    else
        return 1
    fi
}

echo
# 1. Add public keys to server
if is_key_registered "$PERSONAL_KEY.pub" "Personal"; then
    :
else
    log_info "Registering personal public key on $SERVER..."
    if ssh-copy-id -i "$PERSONAL_KEY.pub" "$SERVER"; then
        log_ok "Personal ssh key registered on $SERVER."
    else
        log_error "Failed to register personal ssh key on $SERVER."
    fi
fi

if is_key_registered "$PROJECT_KEY.pub" "Project"; then
    :
else
    log_info "Registering project public key on $SERVER..."
    if ssh-copy-id -i "$PROJECT_KEY.pub" "$SERVER"; then
        log_ok "Project ssh key registered on $SERVER."
    else
        log_error "Failed to register project ssh key on $SERVER."
    fi
fi

echo
# 2. Test SSH authentication for both keys

log_info "Testing personal key authentication..."
ssh -i "$PERSONAL_KEY" -o BatchMode=yes -o ConnectTimeout=5 "$SERVER" true
if [ $? -eq 0 ]; then
  log_ok "Personal key authentication successful."
else
  log_error "Personal key authentication failed."
fi

log_info "Testing project key authentication..."
ssh -i "$PROJECT_KEY" -o BatchMode=yes -o ConnectTimeout=5 "$SERVER" true
if [ $? -eq 0 ]; then
  log_ok "Project key authentication successful."
else
  log_error "Project key authentication failed."
fi
