#!/bin/bash

# Init vault
# Usage: ./init_vault.sh [KEYS_FILE:-/secure/vault-keys.json]

VAULT_ADDR="${VAULT_ADDR:-http://127.0.0.1:8200}"
KEYS_FILE="${1:-/secure/vault-keys.json}"

check_initialized() {
    vault status -format=json 2>/dev/null | jq -r '.initialized'
}

check_sealed() {
    vault status -format=json 2>/dev/null | jq -r '.sealed'
}

echo "Waiting for Vault to be ready..."
until curl -sf "${VAULT_ADDR}/v1/sys/health?standbyok=true&sealedok=true&uninitok=true" > /dev/null; do
    sleep 2
done

if [ "$(check_initialized)" = "false" ]; then
    echo "Initializing Vault..."

    vault operator init \
        -key-shares=5 \
        -key-threshold=3 \
        -format=json > "${KEYS_FILE}"

    chmod 600 "${KEYS_FILE}"

    echo "Vault initialized. Keys stored in ${KEYS_FILE}"
else
    echo "Vault already initialized."
fi

if [ "$(check_sealed)" = "true" ]; then
    echo "Unsealing Vault..."

    for i in 0 1 2; do
        KEY=$(jq -r ".unseal_keys_b64[${i}]" "${KEYS_FILE}")
        vault operator unseal "${KEY}" > /dev/null
    done

    echo "Vault unsealed successfully."
else
    echo "Vault already unsealed."
fi

vault status