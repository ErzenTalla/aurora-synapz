import 'dotenv/config';
import fs from 'node:fs';
import path from 'node:path';
import readline from 'node:readline/promises';
import { stdin, stdout } from 'node:process';
import Anthropic from '@anthropic-ai/sdk';
import { BRIEFING_SYSTEM_PROMPT, buildUserMessage } from './lib/buildPrompt.js';
import { QUESTIONS } from './lib/questions.js';

const ROOT = path.resolve(import.meta.dirname, '..');
const PROFILE_PATH = path.join(ROOT, 'context', 'profile.md');
const BRIEFINGS_DIR = path.join(ROOT, 'daily-briefings');

async function readAllStdin() {
  const chunks = [];
  for await (const chunk of stdin) chunks.push(chunk);
  return Buffer.concat(chunks).toString('utf-8');
}

async function gatherTodayContext() {
  const answers = [];

  if (stdin.isTTY) {
    const rl = readline.createInterface({ input: stdin, output: stdout });
    for (const [key, question] of QUESTIONS) {
      const answer = await rl.question(`${question}\n> `);
      if (answer.trim()) answers.push(`${key.toUpperCase()}: ${answer.trim()}`);
    }
    rl.close();
  } else {
    const lines = (await readAllStdin()).split('\n');
    QUESTIONS.forEach(([key], i) => {
      const answer = (lines[i] || '').trim();
      if (answer) answers.push(`${key.toUpperCase()}: ${answer}`);
    });
  }

  return answers.join('\n') || '(nothing given today)';
}

async function main() {
  if (!process.env.ANTHROPIC_API_KEY) {
    console.error('Missing ANTHROPIC_API_KEY — copy .env.example to .env and set it.');
    process.exit(1);
  }

  const profile = fs.readFileSync(PROFILE_PATH, 'utf-8');
  const todayContext = await gatherTodayContext();
  const now = new Date();
  const date = now.toISOString().slice(0, 10);
  const today = now.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });

  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  const model = process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-5';

  console.log('\nGenerating briefing...\n');

  const response = await client.messages.create({
    model,
    max_tokens: 2000,
    system: BRIEFING_SYSTEM_PROMPT,
    messages: [{ role: 'user', content: buildUserMessage({ profile, todayContext, today }) }],
  });

  const briefing = response.content
    .filter((block) => block.type === 'text')
    .map((block) => block.text)
    .join('\n');

  console.log(briefing);

  fs.mkdirSync(BRIEFINGS_DIR, { recursive: true });
  const outPath = path.join(BRIEFINGS_DIR, `${date}.md`);
  fs.writeFileSync(outPath, `# Aurora Daily Executive Briefing — ${date}\n\n## Input context\n${todayContext}\n\n## Briefing\n${briefing}\n`);

  console.log(`\nSaved to ${outPath}`);
}

main().catch((err) => {
  console.error('Aurora CLI failed:', err.message);
  process.exit(1);
});
