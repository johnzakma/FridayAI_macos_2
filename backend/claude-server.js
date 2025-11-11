import { query } from '@anthropic-ai/claude-agent-sdk';
import { createInterface } from 'readline';

const readline = createInterface({
  input: process.stdin,
  output: process.stdout,
  terminal: false
});

async function processQuery(userMessage) {
  try {
    let fullResponse = '';
    
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
        fullResponse += message.text;
        console.log(JSON.stringify({ type: 'chunk', text: message.text }));
      } else if (message.type === 'result' && message.subtype === 'success') {
        console.log(JSON.stringify({ type: 'complete', result: message.result }));
      }
    }
  } catch (error) {
    console.log(JSON.stringify({ type: 'error', message: error.message }));
  }
}

readline.on('line', async (line) => {
  try {
    const data = JSON.parse(line);
    if (data.type === 'query') {
      await processQuery(data.message);
    }
  } catch (error) {
    console.log(JSON.stringify({ type: 'error', message: 'Invalid input format' }));
  }
});

console.log(JSON.stringify({ type: 'ready' }));
