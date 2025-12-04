# Claude MCP Manager

A command-line tool for managing MCP (Model Context Protocol) servers for Claude CLI and Claude Code.

Instead of manually editing configuration files every time you want to change MCP servers, this tool provides simple commands to enable and disable servers from a reusable library. Per-project configurations mean you can have different servers active for different projects.

## Features

- **Server Library**: Maintain a centralized library of MCP server configurations
- **Per-Project Settings**: Enable different servers for different projects
- **Environment Variables**: Secure API key management via `.env` file
- **Simple CLI**: Enable/disable servers with straightforward commands
- **Pre-configured Servers**: Ships with 14 popular MCP servers ready to use

## Installation

### Prerequisites

The script requires `jq` for JSON processing:

```bash
sudo apt-get update && sudo apt-get install -y jq
```

### Automated Installation (Recommended)

```bash
git clone https://github.com/CyberBrown/claude-mcp-config.git
cd claude-mcp-config
chmod +x install.sh
./install.sh
```

Configure your API keys:

```bash
nano ~/mcp-management/.env
```

Reload your shell:

```bash
source ~/.bashrc
```

### Manual Installation

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

3. Create your `.env` file:

```bash
cp ~/mcp-management/.example.env ~/mcp-management/.env
nano ~/mcp-management/.env
```

4. Add to your `~/.bashrc`:

```bash
# Claude MCP Manager
export PATH="$HOME/mcp-management:$PATH"
alias mcp-manager="$HOME/mcp-management/mcp-manager.sh"
```

5. Reload your shell:

```bash
source ~/.bashrc
```

## Usage

### List available servers

```bash
mcp-manager list
```

### Show active servers in current project

```bash
mcp-manager active
```

### Enable servers

```bash
mcp-manager enable server1 server2 server3
```

### Disable servers

```bash
mcp-manager disable server1
```

### Reset (disable all servers)

```bash
mcp-manager reset
```

## Included Servers

| Server | Description | Requirements |
|--------|-------------|--------------|
| `vibe-check` | Peer review for projects | `GEMINI_API_KEY` |
| `sequential-thinking` | Anthropic's reasoning server | None |
| `cloudflare` | Cloudflare integration | OAuth (browser) |
| `linear` | Todo list / issue tracking | OAuth (browser) |
| `vercel` | Vercel platform integration | None |
| `github` | GitHub integration | `GITHUB_PERSONAL_ACCESS_TOKEN` |
| `sentry` | Error logging integration | OAuth (browser) |
| `supabase` | Database management | OAuth (browser) |
| `gcloud` | Google Cloud integration | OAuth (browser) |
| `Pieces` | Code snippets & long-term memory | None |
| `GitMCP` | Remote Git server | `GITMCP_SERVER` |
| `context7` | Document library | `CONTEXT7_API_KEY` |
| `apify` | Web scraping | None |
| `developer-guides` | Developer documentation | None |

## Configuration

### Environment Variables

Create a `.env` file in `~/mcp-management/` with your API keys:

```bash
GEMINI_API_KEY=your_key_here
GITHUB_PERSONAL_ACCESS_TOKEN=your_token_here
CONTEXT7_API_KEY=your_key_here
GITMCP_SERVER=https://gitmcp.io/your-repo
```

### Adding Custom Servers

Edit `~/mcp-management/servers-library.json` to add new servers. See `commands.md` for detailed instructions.

Example server entry:

```json
{
  "my-server": {
    "command": "npx",
    "args": ["-y", "@scope/mcp-server"],
    "env": {
      "API_KEY": "${MY_API_KEY}"
    }
  }
}
```

Environment variables in the format `${VAR_NAME}` are automatically expanded from your `.env` file.

## How It Works

1. Server configurations are stored in `servers-library.json`
2. When you enable a server, it's added to `~/.claude.json` for your current project
3. Claude Code reads from `~/.claude.json` to determine which MCP servers to use
4. Restart Claude Code after making changes for them to take effect

## Troubleshooting

**Changes not taking effect?**
Restart Claude Code after enabling/disabling servers.

**Server not found?**
Check that the server name matches exactly what's in `mcp-manager list`.

**API key errors?**
Verify your `.env` file has the required keys and run `source ~/.bashrc` to reload.

## License

MIT
