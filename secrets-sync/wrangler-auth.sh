#!/bin/bash
# Cloudflare Wrangler Authentication Helper
# Provides choice between browser OAuth and API token authentication

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/../sync-config"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Load existing config if available
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        source "$CONFIG_FILE"
    fi
}

# Check if we have valid authentication
check_auth() {
    # First check for API token in environment or config
    if [[ -n "$CLOUDFLARE_API_TOKEN" ]]; then
        echo -e "${GREEN}Using API token authentication${NC}"
        export CLOUDFLARE_API_TOKEN
        return 0
    fi

    # Check for existing wrangler OAuth session
    if npx wrangler whoami &>/dev/null; then
        echo -e "${GREEN}Already authenticated via OAuth${NC}"
        return 0
    fi

    return 1
}

# Show current auth status
show_status() {
    echo -e "${BLUE}Checking Cloudflare authentication status...${NC}"
    echo ""

    load_config

    if [[ -n "$CLOUDFLARE_API_TOKEN" ]]; then
        echo -e "${GREEN}API Token:${NC} Configured in sync-config"
        # Verify token works
        if CLOUDFLARE_API_TOKEN="$CLOUDFLARE_API_TOKEN" npx wrangler whoami &>/dev/null; then
            echo -e "${GREEN}Status:${NC} Valid"
        else
            echo -e "${RED}Status:${NC} Invalid or expired"
        fi
    else
        echo -e "${YELLOW}API Token:${NC} Not configured"
        echo ""
        echo -e "${BLUE}Checking OAuth session...${NC}"
        if npx wrangler whoami 2>/dev/null; then
            echo -e "${GREEN}OAuth Status:${NC} Authenticated"
        else
            echo -e "${RED}OAuth Status:${NC} Not authenticated"
        fi
    fi
}

# Browser OAuth authentication
auth_browser() {
    echo -e "${BLUE}Starting browser OAuth authentication...${NC}"
    echo ""
    echo "This will open a browser window for Cloudflare login."
    echo "If you're on a remote/headless server, use API token auth instead."
    echo ""
    read -p "Continue? (y/n): " confirm

    if [[ "$confirm" =~ ^[Yy]$ ]]; then
        npx wrangler login
        echo ""
        echo -e "${GREEN}Authentication complete!${NC}"
    else
        echo "Cancelled."
    fi
}

# API token authentication
auth_token() {
    echo -e "${BLUE}API Token Authentication Setup${NC}"
    echo ""
    echo "To create an API token:"
    echo "  1. Go to: https://dash.cloudflare.com/profile/api-tokens"
    echo "  2. Click 'Create Token'"
    echo "  3. Use the 'Edit Cloudflare Workers' template"
    echo "  4. Copy the generated token"
    echo ""

    read -p "Enter your Cloudflare API token (or press Enter to cancel): " token

    if [[ -z "$token" ]]; then
        echo "Cancelled."
        return
    fi

    # Verify the token works
    echo ""
    echo -e "${BLUE}Verifying token...${NC}"
    if CLOUDFLARE_API_TOKEN="$token" npx wrangler whoami &>/dev/null; then
        echo -e "${GREEN}Token is valid!${NC}"
        echo ""

        # Offer to save to config
        read -p "Save token to sync-config? (y/n): " save

        if [[ "$save" =~ ^[Yy]$ ]]; then
            save_token_to_config "$token"
            echo -e "${GREEN}Token saved to sync-config${NC}"
        else
            echo ""
            echo "Token not saved. To use it, either:"
            echo "  1. Add to sync-config: CLOUDFLARE_API_TOKEN=$token"
            echo "  2. Or export before commands: export CLOUDFLARE_API_TOKEN=$token"
        fi
    else
        echo -e "${RED}Token verification failed. Please check your token.${NC}"
    fi
}

# Save token to sync-config file
save_token_to_config() {
    local token="$1"

    if [[ ! -f "$CONFIG_FILE" ]]; then
        # Create from example
        if [[ -f "$CONFIG_FILE.example" ]]; then
            cp "$CONFIG_FILE.example" "$CONFIG_FILE"
        else
            echo "# MCP Secrets Sync Configuration" > "$CONFIG_FILE"
        fi
    fi

    # Check if CLOUDFLARE_API_TOKEN line exists
    if grep -q "^#*\s*CLOUDFLARE_API_TOKEN=" "$CONFIG_FILE"; then
        # Update existing line (commented or not)
        sed -i "s|^#*\s*CLOUDFLARE_API_TOKEN=.*|CLOUDFLARE_API_TOKEN=$token|" "$CONFIG_FILE"
    else
        # Append new line
        echo "" >> "$CONFIG_FILE"
        echo "CLOUDFLARE_API_TOKEN=$token" >> "$CONFIG_FILE"
    fi
}

# Main menu
main_menu() {
    echo ""
    echo -e "${BLUE}Cloudflare Wrangler Authentication${NC}"
    echo "===================================="
    echo ""
    echo "Choose authentication method:"
    echo ""
    echo "  1) Browser OAuth  - Opens browser for login (requires display)"
    echo "  2) API Token      - Use API token (works on remote/headless servers)"
    echo "  3) Check Status   - Show current authentication status"
    echo "  4) Exit"
    echo ""
    read -p "Select option (1-4): " choice

    case $choice in
        1) auth_browser ;;
        2) auth_token ;;
        3) show_status ;;
        4) exit 0 ;;
        *) echo "Invalid option"; main_menu ;;
    esac
}

# Parse command line arguments
case "${1:-}" in
    --status|-s)
        show_status
        ;;
    --browser|-b)
        auth_browser
        ;;
    --token|-t)
        auth_token
        ;;
    --check|-c)
        load_config
        if check_auth; then
            exit 0
        else
            echo -e "${RED}Not authenticated. Run ./wrangler-auth.sh to authenticate.${NC}"
            exit 1
        fi
        ;;
    --help|-h)
        echo "Usage: ./wrangler-auth.sh [option]"
        echo ""
        echo "Options:"
        echo "  --status, -s   Show current authentication status"
        echo "  --browser, -b  Authenticate via browser OAuth"
        echo "  --token, -t    Authenticate via API token"
        echo "  --check, -c    Check if authenticated (exit 0 if yes, 1 if no)"
        echo "  --help, -h     Show this help message"
        echo ""
        echo "Without options, shows interactive menu."
        ;;
    "")
        load_config
        main_menu
        ;;
    *)
        echo "Unknown option: $1"
        echo "Run ./wrangler-auth.sh --help for usage"
        exit 1
        ;;
esac
