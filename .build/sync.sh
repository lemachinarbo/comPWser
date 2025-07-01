#!/bin/bash

# sync.sh - Sync files to the selected environment's server using rsync and environment-prefixed variables

# Source common logging/colors and env helpers
source "$(cd "$(dirname "$0")" && pwd)/common.sh"

ROCKSHELL_PATH="$SCRIPT_DIR/../RockShell"

echo
# Check .env file
if [ -f "$ENV_FILE" ]; then
    log_info "Loading config from $ENV_FILE"
    source "$ENV_FILE"
else
    log_warn ".env file not found at $ENV_FILE"
    exit 1
fi

# Detect available environments from .env (e.g., PROD_, STAGING_, etc.)
ENVS=$(grep -oE '^[A-Z]+_' "$ENV_FILE" | cut -d_ -f1 | sort | uniq)

# Use environment from argument if provided, else prompt
if [ -n "$1" ]; then
    ENV="$1"
else
    echo "Available environments:"
    select ENV in $ENVS; do
        [ -n "$ENV" ] && break
    done
fi
ENV_LOWER=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')
PREFIX="${ENV}_"

# Get SSH key name from .env, default to id_github if not set
SSH_KEY_NAME="$(get_env SSH_KEY)"
if [ -z "$SSH_KEY_NAME" ]; then
    SSH_KEY_NAME="id_github"
fi
SSH_KEY_PATH="$HOME/.ssh/$SSH_KEY_NAME"
REMOTE_USER="$(get_env SSH_USER)"
REMOTE_HOST="$(get_env SSH_HOST)"
REMOTE_PATH="$(get_env PATH)"
REMOTE_USER_HOST="$REMOTE_USER@$REMOTE_HOST"
PW_ROOT="$PW_ROOT"
log_info "PW_ROOT resolved to: $PW_ROOT"
HTACCESS_OPTION="$(get_env HTACCESS_OPTION)"

log_info "Deploying to remote server..."
log_info "Using SSH key: $SSH_KEY_PATH"
log_info "Deploying to: $REMOTE_USER_HOST:$REMOTE_PATH"

# Change to project root so rsync can find public and RockShell
cd "$SCRIPT_DIR/.."

# Comment out both options by default, then enable the one specified by HTACCESS_OPTION if set
HTACCESS_FILE="$PW_ROOT/.htaccess"
if [ -f "$HTACCESS_FILE" ]; then
    log_info "Ensuring correct .htaccess Options settings in $HTACCESS_FILE..."
    sed -i -E 's/^[[:space:]]*[#]*[[:space:]]*Options[[:space:]]+\+FollowSymLinks/# Options +FollowSymLinks/I' "$HTACCESS_FILE"
    sed -i -E 's/^[[:space:]]*[#]*[[:space:]]*Options[[:space:]]+\+SymLinks[Ii]fOwnerMatch/# Options +SymLinksIfOwnerMatch/I' "$HTACCESS_FILE"
    if [[ "${HTACCESS_OPTION,,}" == "followsymlinks" ]]; then
        sed -i -E 's/^# Options[[:space:]]+\+FollowSymLinks/Options +FollowSymLinks/I' "$HTACCESS_FILE"
        log_ok ".htaccess set to: Options +FollowSymLinks"
    elif [[ "${HTACCESS_OPTION,,}" == "symlinksifownermatch" ]]; then
        sed -i -E 's/^# Options[[:space:]]+\+SymLinks[Ii]fOwnerMatch.*/Options +SymLinksIfOwnerMatch/' "$HTACCESS_FILE"
        log_ok ".htaccess set to: Options +SymLinksIfOwnerMatch"
    else
        log_warn "Both Options directives in .htaccess are commented out (no override set)."
    fi
fi

# Check if source folders exist before running rsync
if [ ! -d "$PW_ROOT" ]; then
    log_error "Source directory PW_ROOT ('$PW_ROOT') does not exist. Aborting deployment."
    exit 1
fi
if [ ! -d "$ROCKSHELL_PATH" ]; then
    log_error "RockShell directory '$ROCKSHELL_PATH' does not exist. Aborting deployment."
    exit 1
fi

# Temporarily move all config files except config.php out of public/site/
TMP_CONFIG_DIR="$SCRIPT_DIR/tmp_config_backup"
mkdir -p "$TMP_CONFIG_DIR"
log_info "Backing up all config-local-*.php, config-local.php, and config.php.bak..."
for f in public/site/config-local-*.php public/site/config-local.php public/site/config.php.bak; do
  if [ -f "$f" ]; then
    mv "$f" "$TMP_CONFIG_DIR/" && log_ok "Moved $f to $TMP_CONFIG_DIR/"
  fi
done

# Copy the environment config as config-local.php for upload (only if it exists)
if [ -n "$ENV_LOWER" ] && [ -f "$TMP_CONFIG_DIR/config-local-$ENV_LOWER.php" ]; then
  log_ok "Copying $TMP_CONFIG_DIR/config-local-$ENV_LOWER.php to public/site/config-local.php for upload."
  cp "$TMP_CONFIG_DIR/config-local-$ENV_LOWER.php" "public/site/config-local.php"
else
  log_error "No environment config found for $ENV_LOWER. Skipping config-local.php upload."
fi

# Rsync, excluding wire/ folders and local-only config files, and the tmp backup dir
RSYNC_LOG="$SCRIPT_DIR/rsync_errors.log"
log_info "Starting rsync deployment..."
rsync -avz --omit-dir-times --delete -e "ssh -i $SSH_KEY_PATH" \
  --exclude='.git' \
  --exclude='.env' \
  --exclude='tmp_config_backup/' \
  --chmod=D775,F644 \
  "$PW_ROOT/" RockShell "$REMOTE_USER_HOST:$REMOTE_PATH" 2>$RSYNC_LOG

# Remove the temporary config-local.php and move config files back
rm -f public/site/config-local.php && log_ok "Removed temporary config-local.php after upload."
mv "$TMP_CONFIG_DIR"/* public/site/ 2>/dev/null && log_ok "Restored original config files from backup." || true
rmdir "$TMP_CONFIG_DIR"
RSYNC_EXIT_CODE=$?
echo
if [ $RSYNC_EXIT_CODE -eq 0 ]; then
    # Move config-local-<env>.php to config-local.php on the server
    ssh -i "$SSH_KEY_PATH" "$REMOTE_USER_HOST" "if [ -f '$REMOTE_CONFIG_LOCAL' ]; then mv -f '$REMOTE_CONFIG_LOCAL' '$REMOTE_CONFIG_FINAL'; fi"
else
    log_error "Deployment failed! Rsync exited with code $RSYNC_EXIT_CODE."
    if grep -q 'No such file or directory' "$RSYNC_LOG"; then
        log_error "Error: One or more source or destination directories do not exist. Check your PW_ROOT, RockShell folder, and DEPLOY_PATH settings."
    elif grep -q 'Permission denied' "$RSYNC_LOG"; then
        log_error "Error: Permission denied. Check your SSH credentials, key permissions, and server access."
    else
        log_error "Please check your SSH credentials, permissions, server status, and source/destination directories, then fix any issues and run the script again."
    fi
    log_error "See $RSYNC_LOG for details on what went wrong."
    exit 1
fi

echo "[DEBUG] Listing public/site/ before rsync:"
ls -l public/site/
echo "[DEBUG] Listing public/site/ after rsync and cleanup:"
ls -l public/site/
