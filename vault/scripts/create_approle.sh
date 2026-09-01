#!/bin/bash

# Create AppRole for application with dev and server environments
# Usage: ./create_approle.sh [APP_NAME]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
export VAULT_TOKEN="${VAULT_TOKEN:-}"

if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}Error: VAULT_TOKEN environment variable not set${NC}"
    echo -e "${YELLOW}Please set: export VAULT_TOKEN=hvs.xxx...${NC}"
    exit 1
fi

APP_NAME="${1:-myapp}"

if [ -z "$APP_NAME" ]; then
    echo -e "${RED}Error: Please provide application name${NC}"
    exit 1
fi

# Create credentials directory
CREDENTIALS_DIR="/srv/homelab/credentials"
mkdir -p "$CREDENTIALS_DIR"

echo -e "${YELLOW}Creating AppRole for application: $APP_NAME${NC}"
echo ""

# Test connection
echo -e "${YELLOW}Testing connection to Vault...${NC}"
if ! vault status &>/dev/null; then
    echo -e "${RED}Failed to connect to Vault${NC}"
    exit 1
fi
echo -e "${GREEN}Connected to Vault successfully${NC}"
echo ""

# Enable AppRole if not already enabled
echo -e "${YELLOW}Checking AppRole authentication...${NC}"
if ! vault auth list | grep -q "approle/"; then
    vault auth enable approle
    echo -e "${GREEN}AppRole authentication enabled${NC}"
else
    echo -e "${BLUE}AppRole is already enabled${NC}"
fi
echo ""

# Create policy for the application
echo -e "${YELLOW}Creating policy for $APP_NAME...${NC}"

vault policy write "$APP_NAME" - <<EOF
# Access to application secrets in both environments
path "secret/data/$APP_NAME/dev/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

path "secret/data/$APP_NAME/server/*" {
  capabilities = ["create", "read", "update", "delete", "list"]
}

# Read access to common infrastructure secrets (optional)
path "secret/data/infrastructure/*" {
  capabilities = ["read", "list"]
}

# Token renewal
path "auth/token/renew-self" {
  capabilities = ["update"]
}
EOF

echo -e "${GREEN}Policy '$APP_NAME' created${NC}"
echo ""

# Create the AppRole
echo -e "${YELLOW}Creating AppRole for $APP_NAME...${NC}"

vault write "auth/approle/role/$APP_NAME" \
    secret_id_ttl=24h \
    token_ttl=1h \
    token_max_ttl=4h \
    policies="$APP_NAME"

echo -e "${GREEN}Role '$APP_NAME' created${NC}"
echo ""

# Get role_id and secret_id
echo -e "${YELLOW}Getting credentials for $APP_NAME...${NC}"

ROLE_ID=$(vault read -field=role_id "auth/approle/role/$APP_NAME/role-id")
SECRET_ID=$(vault write -f -field=secret_id "auth/approle/role/$APP_NAME/secret-id")

echo -e "${GREEN}Role ID: $ROLE_ID${NC}"
echo -e "${GREEN}Secret ID: $SECRET_ID${NC}"
echo ""

# Save credentials to protected files
echo -e "${YELLOW}Saving credentials to $CREDENTIALS_DIR...${NC}"

# Save credentials in a format easy to source
cat > "$CREDENTIALS_DIR/${APP_NAME}.env" <<EOF
# Vault AppRole credentials for $APP_NAME
# Generated: $(date)
# WARNING: Keep this file secure!

export VAULT_ADDR="$VAULT_ADDR"
export VAULT_ROLE_ID="$ROLE_ID"
export VAULT_SECRET_ID="$SECRET_ID"
export VAULT_TOKEN=""
EOF

chmod 600 "$CREDENTIALS_DIR/${APP_NAME}.env"

# Save role_id and secret_id separately for easier copying
echo "$ROLE_ID" > "$CREDENTIALS_DIR/${APP_NAME}.role-id"
chmod 600 "$CREDENTIALS_DIR/${APP_NAME}.role-id"

echo "$SECRET_ID" > "$CREDENTIALS_DIR/${APP_NAME}.secret-id"
chmod 600 "$CREDENTIALS_DIR/${APP_NAME}.secret-id"

echo -e "${GREEN}Credentials saved:${NC}"
echo -e "  ${GREEN}$CREDENTIALS_DIR/${APP_NAME}.env${NC}"
echo -e "  ${GREEN}$CREDENTIALS_DIR/${APP_NAME}.role-id${NC}"
echo -e "  ${GREEN}$CREDENTIALS_DIR/${APP_NAME}.secret-id${NC}"
echo ""


echo -e "${GREEN}Server secrets created: secret/$APP_NAME/server/config${NC}"
echo ""