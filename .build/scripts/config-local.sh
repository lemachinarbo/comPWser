#!/bin/bash

# config-local.sh - Creates/updates config-local.php for a selected environment from .env and ensures config.php includes it

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SITE_DIR="$SCRIPT_DIR/../../public/site"
CONFIG_MAIN="$SITE_DIR/config.php"
LOCAL_CONFIG="$SITE_DIR/config-local.php"
TMP_CONFIG="$CONFIG_MAIN.tmp"

# Source common logging/colors and env helpers
source "$SCRIPT_DIR/common.sh"

# Function to write a config line if value is present
write_config_line() {
    local var="$1"
    local value="$2"
    # Remove leading and trailing single quotes if present
    if [[ "$var" != "httpHosts" && "$var" != "debug" ]]; then
        value="${value#\'}"
        value="${value%\'}"
        echo "\$config->$var = '$value';" >> "$LOCAL_CONFIG"
    else
        echo "\$config->$var = $value;" >> "$LOCAL_CONFIG"
    fi
}

# Check .env file
if [ ! -f "$ENV_FILE" ]; then
    log_warn ".env file not found at $ENV_FILE"
    exit 1
fi
source "$ENV_FILE"

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
PREFIX="${ENV}_"

# Check site directory
if [ ! -d "$SITE_DIR" ]; then
    log_error "Directory public/site does not exist. Skipping config-local.php setup."
    exit 1
fi

# Generate a salt if not present for the selected environment
SALT_VAR="${PREFIX}USER_AUTH_SALT"
SALT_VALUE=$(eval echo \$$SALT_VAR)
if [ -z "$SALT_VALUE" ]; then
    NEW_SALT=$(openssl rand -base64 40)
    SALT_LINE="${SALT_VAR}=\"$NEW_SALT\""
    awk -v prefix="$PREFIX" -v newline="$SALT_LINE" '
      { lines[NR] = $0 }
      $0 ~ "^"prefix { last = NR }
      END {
        for (i = 1; i <= NR; i++) {
          print lines[i]
          if (i == last) print newline
        }
        if (!last) print newline
      }
    ' "$ENV_FILE" > "$ENV_FILE.tmp" && mv "$ENV_FILE.tmp" "$ENV_FILE"
    SALT_VALUE="$NEW_SALT"
    export ${SALT_VAR}="$NEW_SALT"
    log_ok "Generated and added unique USER_AUTH_SALT for $ENV to .env. This salt is unique per environment and must be kept safe."
fi

# Prompt for overwrite if config-local.php exists
if [ -f "$LOCAL_CONFIG" ]; then
    echo
    echo -e "config-local.php already exists. Overwrite? (y/n) [${YELLOW}y${NC}]: \c"
    read -r OVERWRITE
    OVERWRITE=${OVERWRITE:-y}
    if [[ ! $OVERWRITE =~ ^[Yy]$ ]]; then
        log_error "Aborted: config-local.php was not overwritten."
        exit 0
    fi
fi

# --- Create config-local.php for deployment/server (env-specific) ---
ENV_LOWER=$(echo "$ENV" | tr '[:upper:]' '[:lower:]')
DEPLOY_CONFIG="$SITE_DIR/config-local-$ENV_LOWER.php"
DB_PORT=$(get_env_default DB_PORT 3306)
DB_CHARSET=$(get_env_default DB_CHARSET utf8mb4)
DB_ENGINE=$(get_env_default DB_ENGINE InnoDB)
DB_DEBUG_RAW=$(get_env_default DEBUG false)
DB_DEBUG=$(echo "$DB_DEBUG_RAW" | tr '[:upper:]' '[:lower:]')
cat > "$DEPLOY_CONFIG" <<EOF
<?php
// This file is generated for deployment and should be uploaded/renamed on the server.
// Do not use as your local config-local.php!

\$config->dbHost = '$(get_env DB_HOST)';
\$config->dbName = '$(get_env DB_NAME)';
\$config->dbUser = '$(get_env DB_USER)';
\$config->dbPass = '$(get_env DB_PASS)';
\$config->dbPort = '$DB_PORT';
\$config->dbCharset = '$DB_CHARSET';
\$config->dbEngine = '$DB_ENGINE';
\$config->userAuthSalt = '$(get_env USER_AUTH_SALT)';
\$config->httpHosts = array('$(get_env HOST)');
\$config->debug = $DB_DEBUG;
EOF
log_ok "config-local-$ENV_LOWER.php created in public/site/ for $ENV"

# --- Local config-local.php creation for ddev/local environment ---
VARS=(dbHost dbName dbUser dbPass dbPort dbCharset dbEngine userAuthSalt httpHosts debug)
declare -A VALUES
for VAR in "${VARS[@]}"; do
    VALUE=$(awk -v v="$VAR" '
      $0 ~ "\\$config->"v"[[:space:]]*=" {
        sub(/^[^=]*=[[:space:]]*/, "", $0);
        sub(/;.*$/, "", $0);
        print $0;
        exit
      }
    ' "$CONFIG_MAIN")
    if [ -z "$VALUE" ] && [ -f "$CONFIG_MAIN.bak" ]; then
        VALUE=$(awk -v v="$VAR" '
          $0 ~ "\\$config->"v"[[:space:]]*=" {
            sub(/^[^=]*=[[:space:]]*/, "", $0);
            sub(/;.*$/, "", $0);
            print $0;
            exit
          }
        ' "$CONFIG_MAIN.bak")
    fi
    if [ -z "$VALUE" ]; then
        log_warn "Skipped: $VAR not found in config.php or config.php.bak"
    else
        VALUES[$VAR]="$VALUE"
    fi

done
cat > "$LOCAL_CONFIG" <<EOF
<?php
// Local config for development environment. Don't commit this file.
EOF
for VAR in "${VARS[@]}"; do
    if [ -n "${VALUES[$VAR]}" ]; then
        write_config_line "$VAR" "${VALUES[$VAR]}"
    fi

done
log_ok "config-local.php was created for local development."


# Remove moved config lines from config.php (all at once, minimal pattern)
if [ ! -f "$CONFIG_MAIN.bak" ]; then
  sed -i.bak \
    -e '/dbHost/d' \
    -e '/dbName/d' \
    -e '/dbUser/d' \
    -e '/dbPass/d' \
    -e '/dbPort/d' \
    -e '/dbCharset/d' \
    -e '/dbEngine/d' \
    -e '/userAuthSalt/d' \
    -e '/httpHosts/d' \
    -e '/debug/d' \
    "$CONFIG_MAIN"
  log_ok "config.php.bak was saved as a backup of your original config.php."
else
  sed -i \
    -e '/dbHost/d' \
    -e '/dbName/d' \
    -e '/dbUser/d' \
    -e '/dbPass/d' \
    -e '/dbPort/d' \
    -e '/dbCharset/d' \
    -e '/dbEngine/d' \
    -e '/userAuthSalt/d' \
    -e '/httpHosts/d' \
    -e '/debug/d' \
    "$CONFIG_MAIN"
  log_info "config.php.bak already exists, not overwritten."
fi

# Add require for config-local.php to config.php if missing (do this after backup)
REQUIRE_LINE='require __DIR__ . "/config-local.php";'
if [ -f "$CONFIG_MAIN" ] && ! grep -q "$REQUIRE_LINE" "$CONFIG_MAIN"; then
    echo -e "\n// Split Config Pattern" >> "$CONFIG_MAIN"
    echo "$REQUIRE_LINE" >> "$CONFIG_MAIN"
    log_ok "Added require for config-local.php to config.php"
fi

# Remove all comments from config.php (block and line comments)
awk '
  BEGIN { inblock=0 }
  /^\s*\/\*/ { inblock=1; next }
  inblock && /\*\// { inblock=0; next }
  inblock { next }
  /^\s*\/\// { next }
  /^\s*#/ { next }
  { print }
' "$CONFIG_MAIN" > "$TMP_CONFIG" && mv "$TMP_CONFIG" "$CONFIG_MAIN"
