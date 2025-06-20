#!/bin/bash

# Load configuration from .env file
ENV_FILE="$(dirname "$0")/../.env"
if [ -f "$ENV_FILE" ]; then
    echo "Loading config from $ENV_FILE"
    source "$ENV_FILE"
else
    echo "Warning: .env file not found at $ENV_FILE"
fi

# Set defaults if not configured
REMOTE_USER=${REMOTE_USER:-"user@server"}
REMOTE_PATH=${REMOTE_PATH:-"/path/to/deployment"}
SSH_KEY=${SSH_KEY:-"~/.ssh/id_rsa"}

echo "🚀 Deploying to production server..."
echo "Using SSH key: $SSH_KEY"
echo "Deploying to: $REMOTE_USER:$REMOTE_PATH"

# Comment out problematic .htaccess line before deployment
if [ -f ".htaccess" ]; then
    # Only comment out if it's not already commented
    if grep -q "^Options +FollowSymLinks" .htaccess; then
        echo "📝 Commenting out 'Options +FollowSymLinks' in .htaccess..."
        sed -i 's/^Options +FollowSymLinks/# Options +FollowSymLinks/' .htaccess
    fi
    
    # Only uncomment if it's currently commented
    if grep -q "^# Options +SymLinksIfOwnerMatch" .htaccess; then
        echo "📝 Uncommenting 'Options +SymLinksIfOwnerMatch' in .htaccess..."
        sed -i 's/^# Options +SymLinksIfOwnerMatch/Options +SymLinksIfOwnerMatch/' .htaccess
    fi
fi

rsync -avz -e "ssh -i $SSH_KEY" \
  --exclude='.git' \
  --exclude='.env' \
  --chmod=D775,F664 \
  ./ "$REMOTE_USER:$REMOTE_PATH"

# Check if rsync succeeded
if [ $? -eq 0 ]; then
    echo "✅ Deployment complete!"
else
    echo "❌ Deployment failed!"
    exit 1
fi
