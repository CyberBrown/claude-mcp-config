#!/bin/bash

LIBRARY_FILE="$HOME/mcp-management/servers-library.json"
CONFIG_FILE="$HOME/.claude.json"
ENV_FILE="$HOME/mcp-management/.env"
SYNC_CONFIG="$HOME/mcp-management/sync-config"
PULL_SCRIPT="$HOME/mcp-management/secrets-pull.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to check if .env has real values (not placeholders)
env_has_real_values() {
    if [ ! -f "$ENV_FILE" ]; then
        return 1
    fi
    # Check if any line contains placeholder text
    if grep -qE "your_|YOUR_|_here|_HERE|placeholder" "$ENV_FILE" 2>/dev/null; then
        return 1
    fi
    # Check if file has at least one non-comment, non-empty line with a real value
    if grep -qE "^[A-Za-z_][A-Za-z0-9_]*=.{10,}" "$ENV_FILE" 2>/dev/null; then
        return 0
    fi
    return 1
}

# Function to auto-pull secrets if needed
auto_pull_secrets() {
    if env_has_real_values; then
        return 0
    fi

    echo -e "${YELLOW}MCP secrets not found or contain placeholders${NC}"

    # Check if sync is configured
    if [ ! -f "$SYNC_CONFIG" ]; then
        echo -e "${YELLOW}Secrets sync not configured.${NC}"
        echo "To enable auto-sync:"
        echo "  1. Deploy secrets-sync Worker: cd ~/mcp-management/secrets-sync && npm install && npm run deploy"
        echo "  2. Copy config: cp ~/mcp-management/sync-config.example ~/mcp-management/sync-config"
        echo "  3. Edit sync-config with your Worker URL and token"
        echo "  4. Push your secrets: ~/mcp-management/secrets-push.sh"
        echo ""
        echo "Or manually edit $ENV_FILE with your API keys."
        return 1
    fi

    # Try to pull secrets
    echo -e "${YELLOW}Attempting to pull secrets from Cloudflare...${NC}"
    if [ -x "$PULL_SCRIPT" ]; then
        "$PULL_SCRIPT" --force
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}Secrets synced successfully!${NC}"
            return 0
        fi
    fi

    echo -e "${RED}Failed to pull secrets. Please check your sync-config.${NC}"
    return 1
}

# Auto-pull secrets on startup if needed
auto_pull_secrets || true

# Load environment variables from .env file
if [ -f "$ENV_FILE" ]; then
    set -a  # automatically export all variables
    source "$ENV_FILE"
    set +a
fi

# Function to get current project path
get_project_path() {
    echo "$(pwd)"
}

# Function to show usage
usage() {
    echo "Usage: mcp-manager [command] [server-names...]"
    echo ""
    echo "Commands:"
    echo "  list              - Show all available servers in library"
    echo "  active            - Show currently active servers in this project"
    echo "  enable <servers>  - Enable one or more servers in this project"
    echo "  disable <servers> - Disable one or more servers in this project"
    echo "  update            - Pull repo and update all active servers from library"
    echo "  reset             - Disable all servers in this project"
    echo "  sync              - Sync secrets from Cloudflare"
    echo "  push              - Push local secrets to Cloudflare"
    echo ""
    echo "Examples:"
    echo "  mcp-manager list"
    echo "  mcp-manager active"
    echo "  mcp-manager enable vibe-check github"
    echo "  mcp-manager disable vibe-check"
    echo "  mcp-manager update"
    echo "  mcp-manager reset"
    echo "  mcp-manager sync"
    echo "  mcp-manager push"
}

# Function to sync secrets from Cloudflare
sync_secrets() {
    if [ ! -f "$SYNC_CONFIG" ]; then
        echo -e "${RED}Error: Secrets sync not configured${NC}"
        echo "See: ~/mcp-management/sync-config.example"
        exit 1
    fi

    if [ -x "$PULL_SCRIPT" ]; then
        "$PULL_SCRIPT"
    else
        echo -e "${RED}Error: Pull script not found or not executable${NC}"
        exit 1
    fi
}

# Function to push secrets to Cloudflare
push_secrets() {
    PUSH_SCRIPT="$HOME/mcp-management/secrets-push.sh"

    if [ ! -f "$SYNC_CONFIG" ]; then
        echo -e "${RED}Error: Secrets sync not configured${NC}"
        echo "See: ~/mcp-management/sync-config.example"
        exit 1
    fi

    if [ -x "$PUSH_SCRIPT" ]; then
        "$PUSH_SCRIPT"
    else
        echo -e "${RED}Error: Push script not found or not executable${NC}"
        exit 1
    fi
}

# Function to check for updates
check_for_updates() {
    REPO_DIR="$HOME/mcp-management"
    if [ -d "$REPO_DIR/.git" ]; then
        cd "$REPO_DIR"
        # Fetch latest from remote quietly
        git fetch --quiet 2>/dev/null

        # Compare local and remote HEAD
        LOCAL=$(git rev-parse HEAD 2>/dev/null)
        REMOTE=$(git rev-parse @{u} 2>/dev/null)

        cd - > /dev/null

        if [ -n "$LOCAL" ] && [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
            return 0  # Update available
        fi
    fi
    return 1  # No update or couldn't check
}

# Function to list available servers
list_servers() {
    echo "Available MCP servers in library:"
    jq -r 'keys[]' "$LIBRARY_FILE" 2>/dev/null || echo "Error: Could not read library file"

    # Check for updates
    if check_for_updates; then
        echo ""
        echo -e "${YELLOW}⚠ Update available! Run 'mcp-manager update' to get the latest servers.${NC}"
    fi
}

# Function to show active servers
show_active() {
    PROJECT_PATH=$(get_project_path)
    
    if [ -f "$CONFIG_FILE" ]; then
        echo "Currently active MCP servers in $PROJECT_PATH:"
        jq -r --arg path "$PROJECT_PATH" '.projects[$path].mcpServers // {} | keys[]' "$CONFIG_FILE" 2>/dev/null || echo "None"
    else
        echo "No active servers (config file doesn't exist)"
    fi
}

# Function to enable servers
enable_servers() {
    PROJECT_PATH=$(get_project_path)
    
    # Create config file if it doesn't exist
    if [ ! -f "$CONFIG_FILE" ]; then
        echo '{"projects":{}}' > "$CONFIG_FILE"
    fi

    # Read current config
    CURRENT_CONFIG=$(cat "$CONFIG_FILE")
    
    # Initialize project if it doesn't exist
    CURRENT_CONFIG=$(echo "$CURRENT_CONFIG" | jq --arg path "$PROJECT_PATH" '
        if .projects[$path] then . 
        else .projects[$path] = {
            "allowedTools": [],
            "history": [],
            "mcpContextUris": [],
            "mcpServers": {},
            "enabledMcpjsonServers": [],
            "disabledMcpjsonServers": [],
            "hasTrustDialogAccepted": false,
            "ignorePatterns": [],
            "projectOnboardingSeenCount": 0,
            "hasClaudeMdExternalIncludesApproved": false,
            "hasClaudeMdExternalIncludesWarningShown": false
        } end
    ')

    # Add each requested server
    for SERVER in "$@"; do
        # Check if server exists in library
        SERVER_CONFIG=$(jq -r --arg name "$SERVER" '.[$name] // empty' "$LIBRARY_FILE")
        
        if [ -z "$SERVER_CONFIG" ]; then
            echo "Warning: Server '$SERVER' not found in library, skipping..."
            continue
        fi

        # Expand environment variables in the server config
        # This replaces ${VAR_NAME} with the actual environment variable value
        SERVER_CONFIG_EXPANDED=$(echo "$SERVER_CONFIG" | jq 'walk(
            if type == "string" and startswith("${") and endswith("}") then
                env[.[2:-1]]
            else
                .
            end
        )')
        
        # Add server to project config
        CURRENT_CONFIG=$(echo "$CURRENT_CONFIG" | jq --arg path "$PROJECT_PATH" --arg name "$SERVER" --argjson config "$SERVER_CONFIG_EXPANDED" \
            '.projects[$path].mcpServers[$name] = $config')
        
        echo "✓ Enabled: $SERVER"
    done

    # Write updated config
    echo "$CURRENT_CONFIG" | jq . > "$CONFIG_FILE"
    echo ""
    echo "Done! Restart Claude Code for changes to take effect."
}

# Function to disable servers
disable_servers() {
    PROJECT_PATH=$(get_project_path)
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "No config file found, nothing to disable"
        return
    fi

    CURRENT_CONFIG=$(cat "$CONFIG_FILE")

    for SERVER in "$@"; do
        CURRENT_CONFIG=$(echo "$CURRENT_CONFIG" | jq --arg path "$PROJECT_PATH" --arg name "$SERVER" \
            'del(.projects[$path].mcpServers[$name])')
        echo "✓ Disabled: $SERVER"
    done

    echo "$CURRENT_CONFIG" | jq . > "$CONFIG_FILE"
    echo ""
    echo "Done! Restart Claude Code for changes to take effect."
}

# Function to update servers from library
update_servers() {
    PROJECT_PATH=$(get_project_path)

    # Pull latest changes from repo
    echo "Pulling latest server library..."
    REPO_DIR="$HOME/mcp-management"
    if [ -d "$REPO_DIR/.git" ]; then
        cd "$REPO_DIR" && git pull --quiet
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Repository updated${NC}"
        else
            echo -e "${YELLOW}⚠ Could not pull repo (continuing with local library)${NC}"
        fi
        cd - > /dev/null
    else
        echo -e "${YELLOW}⚠ No git repo found at $REPO_DIR${NC}"
    fi
    echo ""

    if [ ! -f "$CONFIG_FILE" ]; then
        echo "No config file found, nothing to update"
        return
    fi

    CURRENT_CONFIG=$(cat "$CONFIG_FILE")

    # Get list of currently active servers
    ACTIVE_SERVERS=$(echo "$CURRENT_CONFIG" | jq -r --arg path "$PROJECT_PATH" '.projects[$path].mcpServers // {} | keys[]' 2>/dev/null)

    if [ -z "$ACTIVE_SERVERS" ]; then
        echo "No active servers to update in $PROJECT_PATH"
        return
    fi

    UPDATED=0
    SKIPPED=0

    for SERVER in $ACTIVE_SERVERS; do
        # Check if server exists in library
        SERVER_CONFIG=$(jq -r --arg name "$SERVER" '.[$name] // empty' "$LIBRARY_FILE")

        if [ -z "$SERVER_CONFIG" ]; then
            echo -e "${YELLOW}⊘ Skipped: $SERVER (not in library, keeping custom config)${NC}"
            ((SKIPPED++))
            continue
        fi

        # Expand environment variables in the server config
        SERVER_CONFIG_EXPANDED=$(echo "$SERVER_CONFIG" | jq 'walk(
            if type == "string" and startswith("${") and endswith("}") then
                env[.[2:-1]]
            else
                .
            end
        )')

        # Update server in project config
        CURRENT_CONFIG=$(echo "$CURRENT_CONFIG" | jq --arg path "$PROJECT_PATH" --arg name "$SERVER" --argjson config "$SERVER_CONFIG_EXPANDED" \
            '.projects[$path].mcpServers[$name] = $config')

        echo -e "${GREEN}✓ Updated: $SERVER${NC}"
        ((UPDATED++))
    done

    # Write updated config
    echo "$CURRENT_CONFIG" | jq . > "$CONFIG_FILE"
    echo ""
    echo "Updated $UPDATED server(s), skipped $SKIPPED custom server(s)."
    echo "Restart Claude Code for changes to take effect."
}

# Function to reset (disable all)
reset_servers() {
    PROJECT_PATH=$(get_project_path)
    
    if [ ! -f "$CONFIG_FILE" ]; then
        echo "No config file found"
        return
    fi
    
    CURRENT_CONFIG=$(cat "$CONFIG_FILE")
    CURRENT_CONFIG=$(echo "$CURRENT_CONFIG" | jq --arg path "$PROJECT_PATH" \
        '.projects[$path].mcpServers = {}')
    
    echo "$CURRENT_CONFIG" | jq . > "$CONFIG_FILE"
    echo "✓ All servers disabled in $PROJECT_PATH"
    echo ""
    echo "Restart Claude Code for changes to take effect."
}

# Main script logic
case "$1" in
    list)
        list_servers
        ;;
    active)
        show_active
        ;;
    enable)
        shift
        if [ $# -eq 0 ]; then
            echo "Error: Please specify at least one server to enable"
            usage
            exit 1
        fi
        enable_servers "$@"
        ;;
    disable)
        shift
        if [ $# -eq 0 ]; then
            echo "Error: Please specify at least one server to disable"
            usage
            exit 1
        fi
        disable_servers "$@"
        ;;
    update)
        update_servers
        ;;
    reset)
        reset_servers
        ;;
    sync)
        sync_secrets
        ;;
    push)
        push_secrets
        ;;
    *)
        usage
        ;;
esac