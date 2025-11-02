#!/bin/bash

# Claude MCP Manager Installation Script
set -e

INSTALL_DIR="$HOME/mcp-management"
BASHRC="$HOME/.bashrc"

echo "Installing Claude MCP Manager..."
echo ""

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    echo "Error: jq is required but not installed."
    echo "Please install it first:"
    echo "  sudo apt-get update && sudo apt-get install -y jq"
    exit 1
fi

# Create the installation directory with correct spelling
echo "Creating directory: $INSTALL_DIR"
mkdir -p "$INSTALL_DIR"

# Copy files to installation directory
echo "Copying files..."
cp mcp-manager.sh "$INSTALL_DIR/"
cp servers-library.json "$INSTALL_DIR/"
cp .example.env "$INSTALL_DIR/"
cp commands.md "$INSTALL_DIR/"

# Make the script executable
chmod +x "$INSTALL_DIR/mcp-manager.sh"

# Create .env file if it doesn't exist
if [ ! -f "$INSTALL_DIR/.env" ]; then
    echo "Creating .env file from template..."
    cp "$INSTALL_DIR/.example.env" "$INSTALL_DIR/.env"
    echo "NOTE: Please edit $INSTALL_DIR/.env and add your API keys"
fi

# Check if bashrc already has the configuration
if grep -q "mcp-management" "$BASHRC" 2>/dev/null; then
    echo ""
    echo "WARNING: Found existing mcp-management configuration in $BASHRC"
    echo "Please check your $BASHRC file and remove any duplicate or malformed entries."
    echo ""
    echo "The correct entries should be:"
    echo '  export PATH="$HOME/mcp-management:$PATH"'
    echo '  alias mcp-manager="$HOME/mcp-management/mcp-manager.sh"'
    echo ""
    read -p "Do you want to continue and add the configuration anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Installation aborted. Files have been copied to $INSTALL_DIR"
        exit 0
    fi
fi

# Add to bashrc
echo ""
echo "Adding configuration to $BASHRC..."
cat >> "$BASHRC" << 'EOF'

# Claude MCP Manager
export PATH="$HOME/mcp-management:$PATH"
alias mcp-manager="$HOME/mcp-management/mcp-manager.sh"
EOF

echo ""
echo "✓ Installation complete!"
echo ""
echo "Next steps:"
echo "  1. Edit $INSTALL_DIR/.env and add your API keys"
echo "  2. Reload your shell: source ~/.bashrc"
echo "  3. Try it out: mcp-manager list"
echo ""
