#!/bin/bash

LIBRARY_FILE="$HOME/mcp-management/servers-library.json"
CONFIG_FILE="$HOME/.claude.json"
ENV_FILE="$HOME/mcp-management/.env"

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
    echo "  reset             - Disable all servers in this project"
    echo ""
    echo "Examples:"
    echo "  mcp-manager list"
    echo "  mcp-manager active"
    echo "  mcp-manager enable vibe-check github"
    echo "  mcp-manager disable vibe-check"
    echo "  mcp-manager reset"
}

# Function to list available servers
list_servers() {
    echo "Available MCP servers in library:"
    jq -r 'keys[]' "$LIBRARY_FILE" 2>/dev/null || echo "Error: Could not read library file"
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
    reset)
        reset_servers
        ;;
    *)
        usage
        ;;
esac