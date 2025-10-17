# See all servers in your library

mcp-manager list

# See what's active in current project

mcp-manager active

# Enable servers for current project

mcp-manager enable server1 server2 server3

# Disable servers from current project

mcp-manager disable server1

# Remove all servers from current project

mcp-manager reset

# Installing New MCP Servers

## Process Overview

### Step 1: Find the server you want

Search for MCP servers at:

- https://github.com/modelcontextprotocol/servers
- https://mcp.so
- https://mcpservers.org

### Step 2: Add it to your library

Edit your library file:

````bash
nano ~/mcp-management/servers-library.json


Add the server configuration. For example:
For npm-based servers:

{
  "server-name": {
    "command": "npx",
    "args": ["-y", "@modelcontextprotocol/server-package-name"]
  }
}

For servers with API keys:
{
  "server-name": {
    "command": "npx",
    "args": ["-y", "package-name"],
    "env": {
      "API_KEY_NAME": "${API_KEY_NAME}"
    }
  }
}

For locally built servers (like vibe-check):
{
  "server-name": {
    "command": "node",
    "args": ["/full/path/to/server/build/index.js"],
    "env": {
      "API_KEY": "${API_KEY}",
      "OTHER_VAR": "value"
    }
  }
}

Step 3: Add API keys to .env (if needed)
nano ~/mcp-management/.env
API_KEY_NAME=your_actual_key_here

Step 4: Enable the server in your project
cd /path/to/your/project
mcp-manager enable server-name

Step 5: Restart Claude Code and verify
claude mcp list

# Installing OAuth-Based MCP Servers

Some MCP servers (like Sentry, Linear, Slack) use OAuth for authentication instead of API keys. These are typically **remote servers** that handle authentication through a web browser.

## OAuth Server Installation Process

### Step 1: Add OAuth server to library

OAuth servers are typically remote HTTP/SSE servers:
```bash
nano ~/mcp-management/servers-library.json

{
  "sentry": {
    "command": "npx",
    "args": ["mcp-remote", "https://mcp.sentry.io/sse"]
  }
}
Note: OAuth servers usually don't need env variables in the config because authentication happens through the browser.

Step 2: Enable the server in your project
cd /path/to/your/project
mcp-manager enable sentry

Step 3: Authenticate via OAuth flow
When you first use the server, Claude Code will:

Prompt you to authenticate
Open a browser window
Ask you to log in and authorize the connection
Store the OAuth token securely

Restart Claude Code and it should prompt for authentication:
claude mcp list
Step 4: Follow the OAuth prompts
The server will provide a URL or automatically open your browser. Complete the OAuth flow by:

Logging into the service (e.g., Sentry)
Authorizing Claude Code to access your account
Returning to Claude Code

Common OAuth MCP Servers
Sentry

{
  "sentry": {
    "command": "npx",
    "args": ["mcp-remote", "https://mcp.sentry.io/sse"]
  }
}

Linear (OAuth version)
{
  "linear": {
    "command": "npx",
    "args": ["mcp-remote", "https://mcp.linear.app/sse"]
  }
}
````
