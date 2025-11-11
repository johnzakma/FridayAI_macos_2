# 🚀 Claude Chat macOS - Standalone App Setup

## 📋 Prerequisites

1. **macOS 13.0+** (Ventura or later)
2. **Xcode Command Line Tools**
   ```bash
   xcode-select --install
   ```
3. **Node.js 18+**
   - Install from: https://nodejs.org/
   - Verify: `node --version`
4. **Claude API Key**
   - Get it from: https://console.anthropic.com/

---

## 🔧 Installation Steps

### Step 1: Download & Extract Project

1. Download the project ZIP from IDE Web
2. Extract to a location like `~/Documents/ClaudeChatMac`

### Step 2: Set API Key

Open Terminal and set your Claude API key:

```bash
export ANTHROPIC_API_KEY="sk-ant-your-actual-key-here"
```

**IMPORTANT**: To make it permanent (recommended):

```bash
echo 'export ANTHROPIC_API_KEY="sk-ant-your-key-here"' >> ~/.zshrc
source ~/.zshrc
```

### Step 3: Build the App

Navigate to the project folder and run the build script:

```bash
cd ~/Documents/ClaudeChatMac
chmod +x build-app.sh
./build-app.sh
```

This will:
- ✅ Check prerequisites
- ✅ Install Node.js dependencies
- ✅ Create a `Claude Chat.app` bundle
- ✅ Embed your API key

The build takes about 30 seconds.

### Step 4: Run the App

Once the build completes, run:

```bash
open "Claude Chat.app"
```

**Or simply double-click `Claude Chat.app` in Finder!**

The app will:
1. Start a local backend server
2. Open the chat interface in your default browser
3. You can start chatting with Claude immediately

---

## ✅ Verify Installation

When the app launches:

1. Browser opens to `http://localhost:3030`
2. You see the welcome screen: "Think It. Type It. Launch It."
3. Type a message like "Hello Claude!"
4. Claude responds within a few seconds

---

## 🐛 Troubleshooting

### Error: "xcode-select not found"

Install Xcode Command Line Tools:

```bash
xcode-select --install
```

### Error: "Node.js not found"

Check Node.js installation:

```bash
which node  # Should show /usr/local/bin/node or /opt/homebrew/bin/node
node --version  # Should show v18 or higher
```

If not installed, get it from https://nodejs.org/

### Error: "ANTHROPIC_API_KEY not set"

Verify your API key is set:

```bash
echo $ANTHROPIC_API_KEY  # Should show your key starting with sk-ant-
```

If empty, set it again:

```bash
export ANTHROPIC_API_KEY="sk-ant-your-key-here"
```

Then rebuild the app.

### App doesn't open browser

Manually open: http://localhost:3030 in your browser

### "Cannot connect to Claude" error in browser

1. Check backend is running:
   ```bash
   lsof -i :3030  # Should show node process
   ```

2. Check backend logs:
   ```bash
   # The app logs to Console.app
   # Or run backend manually to see errors:
   cd "Claude Chat.app/Contents/Resources/backend"
   node claude-server.js
   ```

3. Verify API key is working:
   ```bash
   curl https://api.anthropic.com/v1/messages \
     -H "x-api-key: $ANTHROPIC_API_KEY" \
     -H "anthropic-version: 2023-06-01" \
     -H "content-type: application/json" \
     -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}'
   ```

---

## 📁 What Gets Created

After building, you'll have:

```
ClaudeChatMac/
├── Claude Chat.app/           ← Double-click to run!
│   └── Contents/
│       ├── MacOS/
│       │   └── Claude Chat    (Launcher script)
│       ├── Resources/
│       │   └── backend/       (Node.js server)
│       └── Info.plist
├── backend/                   (Original source)
├── build-app.sh              (Build script)
└── setup-instructions.md     (This file)
```

---

## 🎨 Features

- ✅ **No Xcode required** - just double-click to run
- ✅ **Web-based UI** - opens in your default browser
- ✅ **Real-time streaming** - see Claude's responses as they're generated
- ✅ **Beautiful design** - matching your reference image
- ✅ **MCP support** - filesystem access enabled
- ✅ **Quick actions** - pre-built prompts to get started

---

## 🔧 Customization

### Change Quick Action Buttons

Edit `Claude Chat.app/Contents/Resources/backend/public/index.html`

Find the quick actions section (around line 300) and modify:

```html
<button class="quick-btn" onclick="quickAction('Your custom prompt')">
  🎯 Your Button Text
</button>
```

### Change Port

Edit `Claude Chat.app/Contents/Resources/backend/claude-server.js`

Change `const PORT = 3030;` to your desired port.

### Add Custom Styling

Modify the `<style>` section in `index.html`

---

## 🚀 Quick Commands Cheatsheet

```bash
# Build the app
./build-app.sh

# Run the app
open "Claude Chat.app"

# Check if backend is running
lsof -i :3030

# Stop the app (if needed)
killall node

# Rebuild after changes
rm -rf "Claude Chat.app" && ./build-app.sh

# View logs
open /Applications/Utilities/Console.app
# Filter for "Claude Chat"
```

---

## 📦 Distributing the App

To share the app with others:

1. **Zip the app bundle**:
   ```bash
   zip -r "Claude Chat.zip" "Claude Chat.app"
   ```

2. **Recipients must**:
   - Have Node.js installed
   - Set their own `ANTHROPIC_API_KEY`
   - Run: `open "Claude Chat.app"`

**Note**: The app is not code-signed, so recipients may need to:
- Right-click → Open (first time only)
- Or go to System Settings → Privacy & Security → Allow

---

## 🎯 Next Steps

1. **Add to Applications folder**:
   ```bash
   cp -r "Claude Chat.app" /Applications/
   ```

2. **Create desktop shortcut**:
   - Drag `Claude Chat.app` to Desktop while holding ⌘ + ⌥

3. **Pin to Dock**:
   - Right-click app in Dock → Options → Keep in Dock

---

## 🔑 Security Notes

- Your API key is embedded in `Info.plist`
- The app only runs locally (no data leaves your machine except API calls)
- Backend runs on localhost:3030 (not accessible from network)
- Don't share the built app with your API key embedded

---

## 📞 Need Help?

- **Claude API Docs**: https://docs.anthropic.com/
- **MCP Documentation**: https://modelcontextprotocol.io/
- **Node.js Help**: https://nodejs.org/en/docs/

---

## ✨ Enjoy Your Claude Chat App!

You now have a standalone macOS app that you can:
- ✅ Run without Xcode
- ✅ Launch with a double-click
- ✅ Share with others (after they set their API key)
- ✅ Customize to your needs
