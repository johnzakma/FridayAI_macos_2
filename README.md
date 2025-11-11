# Claude Chat macOS - Standalone App

A beautiful, standalone macOS application for chatting with Claude AI using the Agent SDK.

## Quick Start

```bash
# 1. Set your API key
export ANTHROPIC_API_KEY="sk-ant-your-key-here"

# 2. Build the app
./build-app.sh

# 3. Run it!
open "Claude Chat.app"
```

## Features

- 🚀 **No Xcode needed** - just double-click to run
- 💻 **Web-based UI** - elegant design matching modern macOS apps
- ⚡ **Real-time streaming** - see responses as they're generated
- 🔧 **MCP support** - filesystem access and extensible tools
- 🎨 **Beautiful design** - serif typography, smooth animations

## Requirements

- macOS 13.0+ (Ventura or later)
- Xcode Command Line Tools: `xcode-select --install`
- Node.js 18+: https://nodejs.org/
- Claude API Key: https://console.anthropic.com/

## What It Does

1. Builds a standalone `.app` bundle
2. Embeds a Node.js backend running Claude Agent SDK
3. Serves a web interface on `localhost:3030`
4. Opens your default browser to the chat interface

## Architecture

```
Claude Chat.app
├── Launcher (bash script)
│   └── Starts Node.js backend
│   └── Opens browser
└── Backend (Node.js)
    └── Claude Agent SDK
    └── MCP Server integration
    └── Web UI server
```

## Customization

All source files are in the `backend/` folder. After making changes:

```bash
rm -rf "Claude Chat.app"
./build-app.sh
```

## Troubleshooting

See `setup-instructions.md` for detailed troubleshooting steps.

Common issues:
- **"xcode-select not found"**: Install with `xcode-select --install`
- **"Node.js not found"**: Install from https://nodejs.org/
- **"API key not set"**: Run `export ANTHROPIC_API_KEY="your-key"`

## Distribution

To share the app:

1. Zip it: `zip -r "Claude Chat.zip" "Claude Chat.app"`
2. Recipients must set their own API key
3. They can run it with: `open "Claude Chat.app"`

**Note**: The app includes your API key in the bundle, so don't share your built version publicly.

## License

MIT
