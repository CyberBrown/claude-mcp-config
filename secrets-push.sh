#!/bin/bash
#
# Push local .env secrets to Cloudflare KV
#
# Usage: ./secrets-push.sh
#
# Requires:
#   - SECRETS_SYNC_URL in sync-config
#   - SECRETS_SYNC_TOKEN in sync-config (or will prompt)
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
ENV_FILE="$SCRIPT_DIR/.env"
CONFIG_FILE="$SCRIPT_DIR/sync-config"

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
    echo "Example: SECRETS_SYNC_URL=https://mcp-secrets-sync.your-subdomain.workers.dev"
    exit 1
fi

if [ -z "$SECRETS_SYNC_TOKEN" ]; then
    echo -e "${YELLOW}SECRETS_SYNC_TOKEN not found in config${NC}"
    read -sp "Enter your sync token: " SECRETS_SYNC_TOKEN
    echo
fi

# Check .env exists
if [ ! -f "$ENV_FILE" ]; then
    echo -e "${RED}Error: .env file not found at $ENV_FILE${NC}"
    exit 1
fi

# Convert .env to JSON
echo -e "${YELLOW}Reading secrets from .env...${NC}"

JSON_BODY="{"
FIRST=true

while IFS= read -r line || [ -n "$line" ]; do
    # Skip empty lines and comments
    [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue

    # Parse KEY=VALUE
    if [[ "$line" =~ ^([A-Za-z_][A-Za-z0-9_]*)=(.*)$ ]]; then
        KEY="${BASH_REMATCH[1]}"
        VALUE="${BASH_REMATCH[2]}"

        # Remove surrounding quotes if present
        VALUE="${VALUE%\"}"
        VALUE="${VALUE#\"}"
        VALUE="${VALUE%\'}"
        VALUE="${VALUE#\'}"

        if [ "$FIRST" = true ]; then
            FIRST=false
        else
            JSON_BODY+=","
        fi

        # Escape special characters for JSON
        VALUE=$(echo -n "$VALUE" | sed 's/\\/\\\\/g; s/"/\\"/g; s/\t/\\t/g; s/\n/\\n/g')
        JSON_BODY+="\"$KEY\":\"$VALUE\""
    fi
done < "$ENV_FILE"

JSON_BODY+="}"

# Push to Cloudflare
echo -e "${YELLOW}Pushing secrets to Cloudflare...${NC}"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$SECRETS_SYNC_URL/secrets" \
    -H "Authorization: Bearer $SECRETS_SYNC_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$JSON_BODY")

HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
BODY=$(echo "$RESPONSE" | sed '$d')

if [ "$HTTP_CODE" = "200" ]; then
    echo -e "${GREEN}Success!${NC}"
    echo "$BODY" | jq .
else
    echo -e "${RED}Failed with HTTP $HTTP_CODE${NC}"
    echo "$BODY"
    exit 1
fi
