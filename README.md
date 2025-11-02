# Claude MCP Manager

Simple commands to enable and disable Claude cli and Claude code MCP servers
Without this tool you have to update your config file every time you want to change MCP servers. Lame!
Create a library of MCP servers and activate and deactivate the ones you want to use with simple commands in cli.
Library prepopulated with a few good picks but you can of course change that to whatever you want and adding more is just simple copy paste of the MCP server JSON.

## Installation

### Prerequisites

The script uses jq for JSON processing. Install it first:
```bash
sudo apt-get update && sudo apt-get install -y jq
```

### Automated Installation (Recommended)

1. Clone the repository:
```bash
git clone https://github.com/CyberBrown/claude-mcp-config.git
cd claude-mcp-config
```

2. Run the installation script:
```bash
chmod +x install.sh
./install.sh
```

3. Configure your API keys:
```bash
nano ~/mcp-management/.env
```

4. Reload your shell:
```bash
source ~/.bashrc
```

### Manual Installation

If you prefer to install manually:

1. Clone the repository and create the installation directory:
```bash
git clone https://github.com/CyberBrown/claude-mcp-config.git
mkdir -p ~/mcp-management
```

2. Copy files to the installation directory:
```bash
cd claude-mcp-config
cp mcp-manager.sh servers-library.json .example.env commands.md ~/mcp-management/
chmod +x ~/mcp-management/mcp-manager.sh
```

3. Create your .env file:
```bash
cp ~/mcp-management/.example.env ~/mcp-management/.env
nano ~/mcp-management/.env  # Add your API keys
```

4. Add to your ~/.bashrc (manually edit the file and add these lines):
```bash
# Claude MCP Manager
export PATH="$HOME/mcp-management:$PATH"
alias mcp-manager="$HOME/mcp-management/mcp-manager.sh"
```

5. Reload your shell:
```bash
source ~/.bashrc
```

**IMPORTANT:** The directory must be named `mcp-management` (with an 'e' in 'management'). The script expects this exact path.


## Commands

### See all servers in your library

mcp-manager list

### See what's active in current project

mcp-manager active

### Enable servers for current project

mcp-manager enable server1 server2 server3

### Disable servers from current project

mcp-manager disable server1

### Remove all servers from current project

mcp-manager reset

## How to add new servers to library

See file commands.md for detailed instructions
