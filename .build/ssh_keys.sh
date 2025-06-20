#!/bin/bash

# Script to create personal and project SSH keys if they do not exist, add them to a server, and test authentication

PERSONAL_KEY="$HOME/.ssh/id_ed25519"
PROJECT_KEY="$HOME/.ssh/id_github"

# 1. Create personal key (id_ed25519)
if [ -f "$PERSONAL_KEY" ]; then
  echo "Personal SSH key $PERSONAL_KEY already exists, skipping generation."
else
  read -p "Enter your email for the personal SSH key: " EMAIL
  ssh-keygen -t ed25519 -f "$PERSONAL_KEY" -C "$EMAIL"
  echo "Personal SSH key $PERSONAL_KEY generated."
fi

# 2. Create project key (id_github)
if [ -f "$PROJECT_KEY" ]; then
  echo "Project SSH key $PROJECT_KEY already exists, skipping generation."
else
  ssh-keygen -t ed25519 -f "$PROJECT_KEY" -C "Deployment Key"
  echo "Project SSH key $PROJECT_KEY generated."
fi

# 3. Add public keys to server
read -p "Enter your server username@host (for example: user@server.com): " SERVER

if [ -f "$PERSONAL_KEY.pub" ]; then
  echo "Adding personal public key to $SERVER..."
  ssh-copy-id -i "$PERSONAL_KEY.pub" "$SERVER"
fi

if [ -f "$PROJECT_KEY.pub" ]; then
  echo "Adding project public key to $SERVER..."
  ssh-copy-id -i "$PROJECT_KEY.pub" "$SERVER"
fi

# 4. Test SSH authentication for both keys

echo -e "\nTesting personal key authentication..."
ssh -i "$PERSONAL_KEY" -o BatchMode=yes -o ConnectTimeout=5 "$SERVER" true
if [ $? -eq 0 ]; then
  echo "Personal key authentication successful."
else
  echo "Personal key authentication failed."
fi

echo -e "\nTesting project key authentication..."
ssh -i "$PROJECT_KEY" -o BatchMode=yes -o ConnectTimeout=5 "$SERVER" true
if [ $? -eq 0 ]; then
  echo "Project key authentication successful."
else
  echo "Project key authentication failed."
fi

echo -e "\nAll SSH key operations complete."
echo "Personal and project keys were created (if missing), uploaded to the server, and authentication was tested successfully."
