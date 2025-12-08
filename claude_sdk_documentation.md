SDK documentation
Building a macOS Application with Claude Agent SDK and MCP Servers
Installation
The Claude Agent SDK is available in TypeScript and Python.(1) For a macOS application, you can use either:
TypeScript:
npm install @anthropic-ai/claude-agent-sdk
(1)
Python:
# Installation via pip or uv
(1)
Authentication
Retrieve a Claude API key from the Claude Console and set the ANTHROPIC_API_KEY environment variable.(1)
Configuring MCP Servers
Basic MCP Configuration
Configure MCP servers in .mcp.json at your project root:(2)
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-filesystem"],
      "env": {
        "ALLOWED_PATHS": "/Users/me/projects"
      }
    }
  }
}
(2)
Using MCP Servers in the SDK
TypeScript:
import { query } from "@anthropic-ai/claude-agent-sdk";

for await (const message of query({
  prompt: "List files in my project",
  options: {
    mcpServers: {
      "filesystem": {
        command: "npx",
        args: ["@modelcontextprotocol/server-filesystem"],
        env: {
          ALLOWED_PATHS: "/Users/me/projects"
        }
      }
    },
    allowedTools: ["mcp__filesystem__list_files"]
  }
})) {
  if (message.type === "result" && message.subtype === "success") {
    console.log(message.result);
  }
}
(2)
Python:
from claude_agent_sdk import ClaudeAgentOptions, ClaudeSDKClient

git_mcp: dict[str, Any] = {
    "git": {
        "command": "uv",
        "args": ["run", "python", "-m", "mcp_server_git", "--repository", os.getcwd()],
    }
}

async with (
    ClaudeSDKClient(
        options=ClaudeAgentOptions(
            model="claude-sonnet-4-5",
            mcp_servers=git_mcp,
            allowed_tools=[
                "mcp__git"
            ],
            permission_mode="acceptEdits",
        )
    ) as agent
):
    await agent.query(
        "Use ONLY your git mcp tools to quickly explore this repo's history and gimme a brief summary."
    )
    async for msg in agent.receive_response():
        print_activity(msg)
(3)
MCP Transport Types
The SDK supports three transport types:(2)
1. stdio Servers
External processes communicating via stdin/stdout:(2)
{
  "mcpServers": {
    "my-tool": {
      "command": "node",
      "args": ["./my-mcp-server.js"],
      "env": {
        "DEBUG": "${DEBUG:-false}"
      }
    }
  }
}
(2)
2. HTTP/SSE Servers
Remote servers with network communication:(2)
{
  "mcpServers": {
    "remote-api": {
      "type": "sse",
      "url": "https://api.example.com/mcp/sse",
      "headers": {
        "Authorization": "Bearer ${API_TOKEN}"
      }
    }
  }
}
(2)
3. SDK MCP Servers
In-process servers running within your application.(2)
Tool Name Format
When MCP tools are exposed to Claude, their names follow the format:(4)
* Pattern: mcp__{server_name}__{tool_name}
* Example: A tool named get_weather in server my-custom-tools becomes mcp__my-custom-tools__get_weather(4)
Key Configuration Options
The ClaudeAgentOptions includes:(5)
Property	Description
allowed_tools	List of allowed tool names(5)
mcp_servers	MCP server configurations or path to config file(5)
permission_mode	Permission mode for tool usage(5)
model	Claude model to use(5)
cwd	Current working directory(5)
System Requirements
Each SDK instance requires:(6)
* Python 3.10+ (for Python SDK) or Node.js 18+ (for TypeScript SDK)(6)
* Node.js (required by Claude Code CLI)(6)
* Claude Code CLI: npm install -g @anthropic-ai/claude-code(6)
* Recommended: 1GiB RAM, 5GiB of disk, and 1 CPU(6)
Resource Management
MCP servers can expose resources that Claude can list and read.(2)
Additional Resources
For comprehensive setup instructions, configuration best practices, and troubleshooting tips, see the Claude Code MCP documentation.(3)
Building a macOS Application with Claude Agent SDK and MCP Servers
Installation
The Claude Agent SDK is available in TypeScript and Python.(1) For a macOS application, you can use either:
TypeScript:
npm install @anthropic-ai/claude-agent-sdk
(1)
Python:
# Installation via pip or uv
(1)
Authentication
Retrieve a Claude API key from the Claude Console and set the ANTHROPIC_API_KEY environment variable.(1)
Configuring MCP Servers
Basic MCP Configuration
Configure MCP servers in .mcp.json at your project root:(2)
{
  "mcpServers": {
    "filesystem": {
      "command": "npx",
      "args": ["@modelcontextprotocol/server-filesystem"],
      "env": {
        "ALLOWED_PATHS": "/Users/me/projects"
      }
    }
  }
}
(2)
Using MCP Servers in the SDK
TypeScript:
import { query } from "@anthropic-ai/claude-agent-sdk";

for await (const message of query({
  prompt: "List files in my project",
  options: {
    mcpServers: {
      "filesystem": {
        command: "npx",
        args: ["@modelcontextprotocol/server-filesystem"],
        env: {
          ALLOWED_PATHS: "/Users/me/projects"
        }
      }
    },
    allowedTools: ["mcp__filesystem__list_files"]
  }
})) {
  if (message.type === "result" && message.subtype === "success") {
    console.log(message.result);
  }
}
(2)
Python:
from claude_agent_sdk import ClaudeAgentOptions, ClaudeSDKClient

git_mcp: dict[str, Any] = {
    "git": {
        "command": "uv",
        "args": ["run", "python", "-m", "mcp_server_git", "--repository", os.getcwd()],
    }
}

async with (
    ClaudeSDKClient(
        options=ClaudeAgentOptions(
            model="claude-sonnet-4-5",
            mcp_servers=git_mcp,
            allowed_tools=[
                "mcp__git"
            ],
            permission_mode="acceptEdits",
        )
    ) as agent
):
    await agent.query(
        "Use ONLY your git mcp tools to quickly explore this repo's history and gimme a brief summary."
    )
    async for msg in agent.receive_response():
        print_activity(msg)
(3)
MCP Transport Types
The SDK supports three transport types:(2)
1. stdio Servers
External processes communicating via stdin/stdout:(2)
{
  "mcpServers": {
    "my-tool": {
      "command": "node",
      "args": ["./my-mcp-server.js"],
      "env": {
        "DEBUG": "${DEBUG:-false}"
      }
    }
  }
}
(2)
2. HTTP/SSE Servers
Remote servers with network communication:(2)
{
  "mcpServers": {
    "remote-api": {
      "type": "sse",
      "url": "https://api.example.com/mcp/sse",
      "headers": {
        "Authorization": "Bearer ${API_TOKEN}"
      }
    }
  }
}
(2)
3. SDK MCP Servers
In-process servers running within your application.(2)
Tool Name Format
When MCP tools are exposed to Claude, their names follow the format:(4)
* Pattern: mcp__{server_name}__{tool_name}
* Example: A tool named get_weather in server my-custom-tools becomes mcp__my-custom-tools__get_weather(4)
Key Configuration Options
The ClaudeAgentOptions includes:(5)
Property	Description
allowed_tools	List of allowed tool names(5)
mcp_servers	MCP server configurations or path to config file(5)
permission_mode	Permission mode for tool usage(5)
model	Claude model to use(5)
cwd	Current working directory(5)
System Requirements
Each SDK instance requires:(6)
* Python 3.10+ (for Python SDK) or Node.js 18+ (for TypeScript SDK)(6)
* Node.js (required by Claude Code CLI)(6)
* Claude Code CLI: npm install -g @anthropic-ai/claude-code(6)
* Recommended: 1GiB RAM, 5GiB of disk, and 1 CPU(6)
Resource Management
MCP servers can expose resources that Claude can list and read.(2)
Additional Resources
For comprehensive setup instructions, configuration best practices, and troubleshooting tips, see the Claude Code MCP documentation.(3)
