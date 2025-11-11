#!/bin/bash

# Claude Chat macOS - Build Script
# This creates a standalone .app bundle you can double-click to run

set -e

echo "🚀 Building Claude Chat macOS App..."

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check prerequisites
echo -e "${BLUE}Checking prerequisites...${NC}"

if ! command -v swift &> /dev/null; then
    echo -e "${RED}❌ Swift not found. Please install Xcode Command Line Tools:${NC}"
    echo "   xcode-select --install"
    exit 1
fi

if ! command -v node &> /dev/null; then
    echo -e "${RED}❌ Node.js not found. Install from https://nodejs.org/${NC}"
    exit 1
fi

if [ -z "$ANTHROPIC_API_KEY" ]; then
    echo -e "${RED}❌ ANTHROPIC_API_KEY not set!${NC}"
    echo "   Set it with: export ANTHROPIC_API_KEY='your-key-here'"
    exit 1
fi

echo -e "${GREEN}✅ All prerequisites met${NC}"

# Install backend dependencies
echo -e "${BLUE}Installing Node.js dependencies...${NC}"
cd backend
npm install --silent
cd ..

# Create app bundle structure
APP_NAME="Claude Chat"
APP_BUNDLE="$APP_NAME.app"
CONTENTS="$APP_BUNDLE/Contents"

echo -e "${BLUE}Creating app bundle structure...${NC}"
rm -rf "$APP_BUNDLE"
mkdir -p "$CONTENTS/MacOS"
mkdir -p "$CONTENTS/Resources"
mkdir -p "$CONTENTS/Resources/backend"

# Copy backend files
echo -e "${BLUE}Copying backend files...${NC}"
cp -r backend/* "$CONTENTS/Resources/backend/"

# Create launcher script
echo -e "${BLUE}Creating launcher script...${NC}"
cat > "$CONTENTS/MacOS/Claude Chat" << 'LAUNCHER_EOF'
#!/bin/bash

# Get the directory where this script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
RESOURCES="$DIR/../Resources"

# Start backend server
cd "$RESOURCES/backend"
node claude-server.js &
BACKEND_PID=$!

# Wait for backend to be ready
sleep 2

# Open the web interface in default browser
open "http://localhost:3030"

# Wait for backend process
wait $BACKEND_PID
LAUNCHER_EOF

chmod +x "$CONTENTS/MacOS/Claude Chat"

# Create Info.plist
echo -e "${BLUE}Creating Info.plist...${NC}"
cat > "$CONTENTS/Info.plist" << 'PLIST_EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>Claude Chat</string>
    <key>CFBundleIdentifier</key>
    <string>com.claude.chat</string>
    <key>CFBundleName</key>
    <string>Claude Chat</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSEnvironment</key>
    <dict>
        <key>ANTHROPIC_API_KEY</key>
        <string>${ANTHROPIC_API_KEY}</string>
    </dict>
</dict>
</plist>
PLIST_EOF

# Replace environment variable in Info.plist
sed -i '' "s/\${ANTHROPIC_API_KEY}/$ANTHROPIC_API_KEY/g" "$CONTENTS/Info.plist"

# Create web interface
echo -e "${BLUE}Creating web interface...${NC}"
cat > "$CONTENTS/Resources/backend/public/index.html" << 'HTML_EOF'
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Claude Chat</title>
  <style>
    * {
      margin: 0;
      padding: 0;
      box-sizing: border-box;
    }

    body {
      font-family: -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'Segoe UI', sans-serif;
      background: #f5f5f7;
      color: #1d1d1f;
      height: 100vh;
      display: flex;
      flex-direction: column;
    }

    .welcome-screen {
      display: flex;
      flex-direction: column;
      align-items: center;
      justify-content: center;
      height: 100vh;
      padding: 40px;
      text-align: center;
    }

    .badge {
      background: linear-gradient(135deg, #ff6b35 0%, #ff8c42 100%);
      color: white;
      padding: 8px 20px;
      border-radius: 20px;
      font-size: 11px;
      font-weight: 600;
      letter-spacing: 0.5px;
      margin-bottom: 60px;
      text-transform: uppercase;
    }

    .hero-text {
      font-family: 'New York', 'Georgia', serif;
      font-size: 72px;
      font-weight: 300;
      line-height: 0.9;
      margin-bottom: 30px;
      letter-spacing: -2px;
    }

    .subtitle {
      font-size: 18px;
      color: #666;
      margin-bottom: 50px;
      font-weight: 400;
    }

    .subtitle strong {
      font-weight: 600;
      color: #1d1d1f;
    }

    .input-container {
      width: 100%;
      max-width: 700px;
      background: white;
      border-radius: 12px;
      box-shadow: 0 4px 20px rgba(0,0,0,0.08);
      padding: 20px;
      display: flex;
      align-items: center;
      gap: 12px;
      margin-bottom: 20px;
    }

    .input-container svg {
      width: 20px;
      height: 20px;
      color: #999;
      flex-shrink: 0;
    }

    #messageInput {
      flex: 1;
      border: none;
      outline: none;
      font-size: 14px;
      font-family: inherit;
      color: #1d1d1f;
    }

    #messageInput::placeholder {
      color: #999;
    }

    .send-btn {
      background: #007aff;
      color: white;
      border: none;
      padding: 10px 24px;
      border-radius: 8px;
      font-size: 13px;
      font-weight: 600;
      cursor: pointer;
      transition: all 0.2s;
      font-family: inherit;
    }

    .send-btn:hover {
      background: #0051d5;
      transform: translateY(-1px);
    }

    .send-btn:disabled {
      background: #ccc;
      cursor: not-allowed;
      transform: none;
    }

    .quick-actions {
      display: flex;
      gap: 12px;
      flex-wrap: wrap;
      justify-content: center;
    }

    .quick-btn {
      background: white;
      border: 1px solid #e5e5e7;
      padding: 10px 18px;
      border-radius: 8px;
      font-size: 13px;
      cursor: pointer;
      transition: all 0.2s;
      display: flex;
      align-items: center;
      gap: 8px;
      color: #666;
      font-family: inherit;
    }

    .quick-btn:hover {
      border-color: #007aff;
      color: #007aff;
      transform: translateY(-2px);
      box-shadow: 0 4px 12px rgba(0,122,255,0.15);
    }

    .chat-container {
      display: none;
      flex-direction: column;
      height: 100vh;
      max-width: 1200px;
      margin: 0 auto;
      width: 100%;
    }

    .chat-container.active {
      display: flex;
    }

    .messages {
      flex: 1;
      overflow-y: auto;
      padding: 24px;
    }

    .message {
      margin-bottom: 20px;
      display: flex;
      gap: 12px;
      animation: slideIn 0.3s ease;
    }

    @keyframes slideIn {
      from {
        opacity: 0;
        transform: translateY(10px);
      }
      to {
        opacity: 1;
        transform: translateY(0);
      }
    }

    .message.user {
      flex-direction: row-reverse;
    }

    .avatar {
      width: 32px;
      height: 32px;
      border-radius: 50%;
      display: flex;
      align-items: center;
      justify-content: center;
      flex-shrink: 0;
      font-size: 16px;
    }

    .message.user .avatar {
      background: #e5e5e7;
    }

    .message.assistant .avatar {
      background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
      color: white;
    }

    .message-content {
      max-width: 70%;
      background: white;
      padding: 14px 18px;
      border-radius: 16px;
      box-shadow: 0 2px 8px rgba(0,0,0,0.06);
      font-size: 14px;
      line-height: 1.6;
    }

    .message.user .message-content {
      background: #007aff;
      color: white;
    }

    .timestamp {
      font-size: 11px;
      color: #999;
      margin-top: 4px;
    }

    .input-area {
      padding: 20px 24px;
      background: white;
      border-top: 1px solid #e5e5e7;
    }

    .typing-indicator {
      display: none;
      align-items: center;
      gap: 8px;
      color: #999;
      font-size: 13px;
      margin-bottom: 12px;
    }

    .typing-indicator.active {
      display: flex;
    }

    .typing-dots {
      display: flex;
      gap: 4px;
    }

    .typing-dots span {
      width: 6px;
      height: 6px;
      background: #999;
      border-radius: 50%;
      animation: bounce 1.4s infinite ease-in-out;
    }

    .typing-dots span:nth-child(1) {
      animation-delay: -0.32s;
    }

    .typing-dots span:nth-child(2) {
      animation-delay: -0.16s;
    }

    @keyframes bounce {
      0%, 80%, 100% {
        transform: scale(0);
      }
      40% {
        transform: scale(1);
      }
    }
  </style>
</head>
<body>
  <div id="welcome" class="welcome-screen">
    <div class="badge">⚡️ CLAUDE AGENT SDK POWERED</div>
    
    <div class="hero-text">
      <div>Think It.</div>
      <div>Type It.</div>
      <div>Launch It.</div>
    </div>
    
    <p class="subtitle">
      Chat with <strong>Claude AI</strong> powered by the Agent SDK
    </p>
    
    <div class="input-container">
      <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
        <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
      </svg>
      <input 
        type="text" 
        id="messageInput" 
        placeholder="Ask Claude anything..."
        autocomplete="off"
      />
      <button class="send-btn" onclick="sendMessage()">Send</button>
    </div>
    
    <div class="quick-actions">
      <button class="quick-btn" onclick="quickAction('Explain quantum computing')">
        🔬 Quantum Computing
      </button>
      <button class="quick-btn" onclick="quickAction('Write a Python script')">
        💻 Python Script
      </button>
      <button class="quick-btn" onclick="quickAction('Plan a trip to Japan')">
        ✈️ Travel Planning
      </button>
      <button class="quick-btn" onclick="quickAction('Surprise me!')">
        ⭐ Surprise Me
      </button>
    </div>
  </div>

  <div id="chat" class="chat-container">
    <div id="messages" class="messages"></div>
    <div class="input-area">
      <div id="typingIndicator" class="typing-indicator">
        <span>Claude is typing</span>
        <div class="typing-dots">
          <span></span>
          <span></span>
          <span></span>
        </div>
      </div>
      <div class="input-container">
        <svg fill="none" stroke="currentColor" viewBox="0 0 24 24">
          <path stroke-linecap="round" stroke-linejoin="round" stroke-width="2" d="M13 10V3L4 14h7v7l9-11h-7z"/>
        </svg>
        <input 
          type="text" 
          id="chatInput" 
          placeholder="Ask Claude anything..."
          autocomplete="off"
        />
        <button class="send-btn" id="sendBtn" onclick="sendMessage()">Send</button>
      </div>
    </div>
  </div>

  <script>
    const welcome = document.getElementById('welcome');
    const chat = document.getElementById('chat');
    const messages = document.getElementById('messages');
    const messageInput = document.getElementById('messageInput');
    const chatInput = document.getElementById('chatInput');
    const sendBtn = document.getElementById('sendBtn');
    const typingIndicator = document.getElementById('typingIndicator');

    let isProcessing = false;

    messageInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') sendMessage();
    });

    chatInput.addEventListener('keypress', (e) => {
      if (e.key === 'Enter') sendMessage();
    });

    function quickAction(text) {
      messageInput.value = text;
      sendMessage();
    }

    function switchToChat() {
      welcome.style.display = 'none';
      chat.classList.add('active');
    }

    function addMessage(content, isUser) {
      const messageDiv = document.createElement('div');
      messageDiv.className = `message ${isUser ? 'user' : 'assistant'}`;
      
      const time = new Date().toLocaleTimeString('en-US', { 
        hour: 'numeric', 
        minute: '2-digit' 
      });

      messageDiv.innerHTML = `
        <div class="avatar">${isUser ? '👤' : '✨'}</div>
        <div>
          <div class="message-content">${content}</div>
          <div class="timestamp">${time}</div>
        </div>
      `;

      messages.appendChild(messageDiv);
      messages.scrollTop = messages.scrollHeight;
      return messageDiv;
    }

    async function sendMessage() {
      const input = welcome.style.display === 'none' ? chatInput : messageInput;
      const text = input.value.trim();
      
      if (!text || isProcessing) return;

      switchToChat();
      addMessage(text, true);
      input.value = '';
      
      isProcessing = true;
      sendBtn.disabled = true;
      typingIndicator.classList.add('active');

      try {
        const response = await fetch('/query', {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ message: text })
        });

        const reader = response.body.getReader();
        const decoder = new TextDecoder();
        let assistantMessage = null;
        let fullText = '';

        while (true) {
          const { done, value } = await reader.read();
          if (done) break;

          const chunk = decoder.decode(value);
          const lines = chunk.split('\n').filter(l => l.trim());

          for (const line of lines) {
            try {
              const data = JSON.parse(line);
              
              if (data.type === 'chunk') {
                fullText += data.text;
                if (!assistantMessage) {
                  assistantMessage = addMessage(fullText, false);
                } else {
                  assistantMessage.querySelector('.message-content').textContent = fullText;
                }
              }
            } catch (e) {
              console.error('Parse error:', e);
            }
          }
        }
      } catch (error) {
        addMessage('Error: Could not connect to Claude. Please check your setup.', false);
        console.error('Error:', error);
      } finally {
        isProcessing = false;
        sendBtn.disabled = false;
        typingIndicator.classList.remove('active');
        chatInput.focus();
      }
    }
  </script>
</body>
</html>
HTML_EOF

mkdir -p "$CONTENTS/Resources/backend/public"

# Update backend to serve web interface
cat > "$CONTENTS/Resources/backend/claude-server.js" << 'SERVER_EOF'
import { query } from '@anthropic-ai/claude-agent-sdk';
import { createServer } from 'http';
import { readFile } from 'fs/promises';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = 3030;

async function processQuery(userMessage) {
  const chunks = [];
  
  try {
    for await (const message of query({
      prompt: userMessage,
      options: {
        model: 'claude-sonnet-4-5',
        mcpServers: {
          filesystem: {
            command: 'npx',
            args: ['@modelcontextprotocol/server-filesystem'],
            env: {
              ALLOWED_PATHS: process.env.HOME
            }
          }
        }
      }
    })) {
      if (message.type === 'text') {
        chunks.push({ type: 'chunk', text: message.text });
      }
    }
    chunks.push({ type: 'complete' });
  } catch (error) {
    chunks.push({ type: 'error', message: error.message });
  }
  
  return chunks;
}

const server = createServer(async (req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type');

  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  if (req.url === '/' && req.method === 'GET') {
    try {
      const html = await readFile(join(__dirname, 'public', 'index.html'), 'utf-8');
      res.writeHead(200, { 'Content-Type': 'text/html' });
      res.end(html);
    } catch (error) {
      res.writeHead(500);
      res.end('Error loading page');
    }
    return;
  }

  if (req.url === '/query' && req.method === 'POST') {
    let body = '';
    
    req.on('data', chunk => {
      body += chunk.toString();
    });

    req.on('end', async () => {
      try {
        const { message } = JSON.parse(body);
        
        res.writeHead(200, {
          'Content-Type': 'application/json',
          'Transfer-Encoding': 'chunked'
        });

        const chunks = await processQuery(message);
        
        for (const chunk of chunks) {
          res.write(JSON.stringify(chunk) + '\n');
        }
        
        res.end();
      } catch (error) {
        res.writeHead(500);
        res.end(JSON.stringify({ type: 'error', message: error.message }));
      }
    });
    return;
  }

  res.writeHead(404);
  res.end('Not found');
});

server.listen(PORT, () => {
  console.log(`Claude Chat server running on http://localhost:${PORT}`);
});
SERVER_EOF

echo -e "${GREEN}✅ Build complete!${NC}"
echo ""
echo -e "${BLUE}📦 App bundle created: ${GREEN}$APP_BUNDLE${NC}"
echo ""
echo -e "${BLUE}To run the app:${NC}"
echo -e "   ${GREEN}open \"$APP_BUNDLE\"${NC}"
echo ""
echo -e "${BLUE}Or double-click the app in Finder${NC}"
