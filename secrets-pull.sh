#!/bin/bash
#
# Pull secrets from Cloudflare KV to local .env
#
# Usage: ./secrets-pull.sh [--force]
#
# Options:
#   --force    Overwrite existing .env without prompting
#
# Requires:
#   - SECRETS_SYNC_URL in sync-config
#   - SECRETS_SYNC_TOKEN in sync-config (or will prompt)
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENV_FILE="$SCRIPT_DIR/.env"
CONFIG_FILE="$SCRIPT_DIR/sync-config"
FORCE=false

# Parse arguments
if [ "$1" = "--force" ]; then
    FORCE=true
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Load sync config
if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
fi

# Check for required config
if [ -z "$SECRETS_SYNC_URL" ]; then
    echo -e "${RED}Error: SECRETS_SYNC_URL not set in $CONFIG_FILE${NC}"
    echo ""
    echo "To set up secrets sync:"
    echo "1. Deploy the secrets-sync Worker (see secrets-sync/)"
    echo "2. Create $CONFIG_FILE with:"
    echo "   SECRETS_SYNC_URL=https://mcp-secrets-sync.your-subdomain.workers.dev"
    echo "   SECRETS_SYNC_TOKEN=your-auth-token"
    exit 1
fi

if [ -z "$SECRETS_SYNC_TOKEN" ]; then
    echo -e "${YELLOW}SECRETS_SYNC_TOKEN not found in config${NC}"
    read -sp "Enter your sync token: " SECRETS_SYNC_TOKEN
    echo
fi

# Check if .env exists and prompt for overwrite
if [ -f "$ENV_FILE" ] && [ "$FORCE" != true ]; then
    echo -e "${YELLOW}Warning: .env file already exists${NC}"
    read -p "Overwrite? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted"
        exit 0
    fi
fi

# Pull from Cloudflare
echo -e "${YELLOW}Pulling secrets from Cloudflare...${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X GET "$SECRETS_SYNC_URL/secrets" \
    -H "Authorization: Bearer $SECRETS_SYNC_TOKEN")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" != "200" ]; then
    echo -e "${RED}Failed with HTTP $HTTP_CODE${NC}"
    echo "$BODY"
    exit 1
fi

# Convert JSON to .env format
echo -e "${YELLOW}Writing to .env...${NC}"

# Create backup if file exists
if [ -f "$ENV_FILE" ]; then
    cp "$ENV_FILE" "$ENV_FILE.backup"
    echo -e "Backup created at ${ENV_FILE}.backup"
fi

# Write new .env
echo "# MCP Management Secrets" > "$ENV_FILE"
echo "# Synced from Cloudflare: $(date -Iseconds)" >> "$ENV_FILE"
echo "#" >> "$ENV_FILE"

# Parse JSON and write each key=value
echo "$BODY" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"' >> "$ENV_FILE"

# Count keys
KEY_COUNT=$(echo "$BODY" | jq 'keys | length')

echo -e "${GREEN}Success! Pulled $KEY_COUNT secrets${NC}"
echo ""
echo "Keys:"
echo "$BODY" | jq -r 'keys[]' | sed 's/^/  - /'
