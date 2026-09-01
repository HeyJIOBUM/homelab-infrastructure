#!/bin/bash

# Basic vault configuration after init
# Usage: ./configure_vault.sh [ROOT_TOKEN]

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
VAULT_TOKEN="${1:-}"

if [ -z "$VAULT_TOKEN" ]; then
    echo -e "${RED}Error: Please provide root token as argument${NC}"
    exit 1
fi

# Test connection
echo -e "${YELLOW}Testing connection to Vault...${NC}"
if ! vault status &>/dev/null; then
    echo -e "${RED}Failed to connect to Vault${NC}"
    exit 1
fi
echo -e "${GREEN}Connected to Vault successfully${NC}"
echo ""

# Create admin policy
echo -e "${YELLOW}Creating policies...${NC}"

vault policy write admin - <<'EOF'
# Full access to all paths
path "*" {
  capabilities = ["create", "read", "update", "delete", "list", "sudo"]
}
EOF
echo -e "${GREEN}Admin policy created${NC}"

# Enable KVv2
echo -e "${YELLOW}Enabling secret engines...${NC}"

if ! vault secrets list | grep -q "secret/"; then
    vault secrets enable -path=secret kv-v2
    echo -e "${GREEN}KV v2 secret engine enabled (path: secret/)${NC}"
else
    echo -e "${BLUE}KV v2 is already enabled${NC}"
fi

# Enable AppRole
echo -e "${YELLOW}Setting up AppRole authentication...${NC}"

if ! vault auth list | grep -q "approle/"; then
    vault auth enable approle
    echo -e "${GREEN}AppRole authentication enabled${NC}"
else
    echo -e "${BLUE}AppRole is already enabled${NC}"
fi

echo ""
echo -e "${GREEN}Basic configuration completed${NC}"