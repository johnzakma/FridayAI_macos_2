# 🚀 Claude Chat macOS - Complete Setup Guide

## 📋 Prerequisites

1. **macOS 13.0+** (Ventura or later)
2. **Xcode 15.0+** (Download from Mac App Store)
3. **Node.js 18+** (Check: `node --version`)
   - Install from: https://nodejs.org/
4. **Claude API Key** from: https://console.anthropic.com/

---

## 🔧 Installation Steps

### Step 1: Download & Extract Project
1. Download the project ZIP
2. Extract to desired location (e.g., `~/Documents/ClaudeChatMac`)

### Step 2: Set Up Backend

Open Terminal and run:

```bash
cd ~/Documents/ClaudeChatMac/backend
npm install
```

Set your Claude API key permanently:

```bash
echo 'export ANTHROPIC_API_KEY="your-api-key-here"' >> ~/.zshrc
source ~/.zshrc
```

**Verify it's set:**
```bash
echo $ANTHROPIC_API_KEY
```

### Step 3: Build Xcode Project

From the project root:

```bash
cd ~/Documents/ClaudeChatMac
chmod +x build-app.sh
./build-app.sh
```

### Step 4: Open in Xcode

```bash
open ClaudeChatMac.xcodeproj
```

Or manually:
1. Double-click `ClaudeChatMac.xcodeproj`
2. Wait for Xcode to finish indexing

### Step 5: Configure Code Signing

In Xcode:
1. Select `ClaudeChatMac` project in Navigator (left sidebar)
2. Select `ClaudeChatMac` target
3. Go to **Signing & Capabilities** tab
4. Under "Team", select your Apple ID
   - If none exists, click "Add Account" and sign in

### Step 6: Build & Run

Click the **Play button (▶️)** in Xcode toolbar, or press `Cmd + R`

---

## ✅ Expected Behavior

1. **App Window Opens** - NOT a web browser
2. You see the welcome screen with "Think It. Type It. Launch It."
3. Type a message and press Enter
4. Claude responds in real-time

---

## 🐛 Troubleshooting

### ❌ "Browser opens instead of app window"
**Solution**: The Xcode project wasn't properly configured. Re-run:
```bash
./build-app.sh
open ClaudeChatMac.xcodeproj
```

### ❌ "Code signing failed"
**Solution**: 
1. Go to Xcode → Settings → Accounts
2. Add your Apple ID
3. Select it in project settings

### ❌ "Node.js not found"
**Solution**:
```bash
which node  # Should return a path
# If empty, install Node.js from nodejs.org
```

### ❌ "API key not set"
**Solution**:
```bash
export ANTHROPIC_API_KEY="your-key-here"
# Or add to ~/.zshrc for persistence
```

### ❌ "Backend not responding"
**Solution**: Test backend independently:
```bash
cd backend
npm start
# Type: {"type":"query","message":"Hello"}
# Press Enter - should see Claude response
```

---

## 📦 Project Structure

```
ClaudeChatMac/
├── ClaudeChatMac.xcodeproj/     # Xcode project (generated)
├── ClaudeChatMac/
│   ├── ClaudeChatMacApp.swift   # App entry
│   ├── ContentView.swift        # Main UI
│   ├── MessageView.swift        # Chat bubbles
│   ├── ClaudeService.swift      # Backend bridge
│   └── Info.plist              # App metadata
├── backend/
│   ├── claude-server.js         # Node.js server
│   ├── package.json
│   └── .mcp.json               # MCP config
└── build-app.sh                # Project generator
```

---

## 🎨 Design Features

✅ Native macOS window (not web browser)  
✅ Minimalist serif typography  
✅ System colors (adapts to dark mode)  
✅ Real-time streaming responses  
✅ SF Symbols icons  

---

## 🔑 Security Notes

- **Never commit API keys** to version control
- API key is read from shell environment only
- Backend process is sandboxed within app

---

## 🎯 Next Steps

- Customize welcome screen in `ContentView.swift`
- Add chat history persistence
- Implement export/share features

---

## 📞 Support

- **Claude API**: https://docs.anthropic.com/
- **MCP Docs**: https://modelcontextprotocol.io/
- **Swift/SwiftUI**: https://developer.apple.com/documentation/swiftui/
