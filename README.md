# Claude MCP Manager

Simple commands to enable and disable Claude cli and Claude code MCP servers
Without this tool you have to update your config file every time you want to change MCP servers. Lame!
Create a library of MCP servers and activate and deactivate the ones you want to use with simple commands in cli.
Library prepopulated with a few good picks but you can of course change that to whatever you want and adding more is just simple copy paste of the MCP server JSON.

## Installation

Download repo, create new path mcp-management in root and copy files into that folder. You can configure claude mcp servers that are active project by project, so if you set things up in root you will have to do it again in your project dir.

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
