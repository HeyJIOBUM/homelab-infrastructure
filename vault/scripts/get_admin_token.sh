#!/bin/bash

# Create admin token from root token
# Usage: ./get_admin_token.sh [ROOT_TOKEN]

export VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
export VAULT_TOKEN="${1:-}"

if [ -z "$VAULT_TOKEN" ]; then
    echo "Error: Please provide root token as argument"
    echo "Usage: ./get_admin_token hvs.xxx..."
    exit 1
fi

echo "Connecting to Vault at $VAULT_ADDR..."
if ! vault status &>/dev/null; then
    echo "Error: Failed to connect to Vault"
    exit 1
fi
echo "Connected successfully"

# Create admin policy if it doesn't exist
if ! vault policy list | grep -q "^admin$"; then
    echo "Creating admin policy..."
    vault policy write admin - <<'EOF'
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF
fi

# Create admin token
echo "Creating admin token..."
ADMIN_TOKEN=$(vault token create \
    -policy=admin \
    -ttl=8760h \
    -format=json \
    | jq -r '.auth.client_token')

echo "Admin token created successfully"
echo "Token: $ADMIN_TOKEN"
echo ""
echo "You can now use this token for daily administration"
echo "Export it with: export VAULT_TOKEN=$ADMIN_TOKEN"