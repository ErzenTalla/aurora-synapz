import 'dotenv/config';
import readline from 'node:readline/promises';
import { stdin, stdout } from 'node:process';
import Anthropic from '@anthropic-ai/sdk';
import { CHAT_SYSTEM_PROMPT } from './lib/buildPrompt.js';
import { getProfile, getBriefing, extractBriefingText, listBriefings } from './lib/store.js';

async function loadBriefing(requestedDate) {
  if (requestedDate) {
    return { date: requestedDate, text: extractBriefingText(await getBriefing(requestedDate)) };
  }
  const today = new Date().toISOString().slice(0, 10);
  try {
    return { date: today, text: extractBriefingText(await getBriefing(today)) };
  } catch {
    const briefings = await listBriefings();
    if (briefings.length === 0) throw new Error('No briefings saved yet — run `npm run brief` first.');
    const latest = briefings[0].date;
    return { date: latest, text: extractBriefingText(await getBriefing(latest)) };
  }
}

async function readAllStdin() {
  const chunks = [];
  for await (const chunk of stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString('utf-8');
}

async function main() {
  if (!process.env.ANTHROPIC_API_KEY) {
    console.error('Missing ANTHROPIC_API_KEY — copy .env.example to .env and set it.');
    process.exit(1);
  }

  const { date, text: briefingText } = await loadBriefing(process.argv[2]);
  console.log(`Chatting about the ${date} briefing. Type your questions, Ctrl+C to quit.\n`);

  const profile = await getProfile();
  const system = `${CHAT_SYSTEM_PROMPT}\n\nPERMANENT PROFILE:\n${profile}\n\nTHE BRIEFING YOU GAVE ON ${date}:\n${briefingText}`;
  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  const model = process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-5';
  const messages = [];

  async function ask(userText) {
    messages.push({ role: 'user', content: userText });
    const response = await client.messages.create({ model, max_tokens: 1000, system, messages });
    const reply = response.content.filter((b) => b.type === 'text').map((b) => b.text).join('\n');
    messages.push({ role: 'assistant', content: reply });
    console.log(`\nAurora: ${reply}\n`);
  }

  if (stdin.isTTY) {
    const rl = readline.createInterface({ input: stdin, output: stdout });
    while (true) {
      const userText = await rl.question('You: ');
      if (!userText.trim()) continue;
      await ask(userText.trim());
    }
  } else {
    const lines = (await readAllStdin()).split('\n').map((l) => l.trim()).filter(Boolean);
    for (const line of lines) {
      console.log(`You: ${line}`);
      await ask(line);
    }
  }
}

main().catch((err) => {
  console.error('aurora-cli chat failed:', err.message);
  process.exit(1);
});
