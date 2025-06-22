#!/bin/bash

# setup-config.sh - Creates/updates config-local.php from .env and ensures config.php includes it

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ENV_FILE="$SCRIPT_DIR/../.env"
if [ -f "$ENV_FILE" ]; then
    source "$ENV_FILE"
else
    echo "[WARN] .env file not found at $ENV_FILE"
    exit 1
fi

# Generate a salt if not present
if [ -z "$SERVER_AUTH_SALT" ]; then
    SERVER_AUTH_SALT=$(openssl rand -base64 40)
fi

if [ -d "$SCRIPT_DIR/../public/site" ]; then
cat > "$SCRIPT_DIR/../public/site/config-local.php" <<EOF
<?php
\$config->dbHost = '${SERVER_DB_HOST}';
\$config->dbName = '${SERVER_DB_NAME}';
\$config->dbUser = '${SERVER_DB_USER}';
\$config->dbPass = '${SERVER_DB_PASS}';

\$config->userAuthSalt = '${SERVER_AUTH_SALT}';

\$config->httpHosts = array('${SERVER_HOST}');
EOF
    echo "[OK] config-local.php created/updated in public/site/"
    # Add require for config-local.php to config.php if missing
    CONFIG_MAIN="$SCRIPT_DIR/../public/site/config.php"
    REQUIRE_LINE='require __DIR__ . "/config-local.php";'
    if [ -f "$CONFIG_MAIN" ] && ! grep -q "$REQUIRE_LINE" "$CONFIG_MAIN"; then
        echo -e "\n// Split Config Pattern" >> "$CONFIG_MAIN"
        echo "$REQUIRE_LINE" >> "$CONFIG_MAIN"
        echo "[OK] Added require for config-local.php to config.php"
    fi
else
    echo "[ERROR] Directory public/site does not exist. Skipping config-local.php setup."
    exit 1
fi
