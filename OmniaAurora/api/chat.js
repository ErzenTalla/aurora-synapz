import Anthropic from '@anthropic-ai/sdk';
import { CHAT_SYSTEM_PROMPT } from '../aurora-cli/lib/buildPrompt.js';
import { getProfile } from '../aurora-cli/lib/store.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  if (req.headers['x-aurora-secret'] !== process.env.AURORA_APP_SECRET) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { briefingDate, briefingText, messages } = req.body || {};
  if (!Array.isArray(messages) || messages.length === 0) {
    res.status(400).json({ error: 'Missing messages' });
    return;
  }

  const profile = await getProfile();
  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  const model = process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-5';

  const system = `${CHAT_SYSTEM_PROMPT}\n\nPERMANENT PROFILE:\n${profile}\n\nTHE BRIEFING YOU GAVE ON ${briefingDate || 'an earlier day'}:\n${briefingText || '(not provided)'}`;

  const response = await client.messages.create({
    model,
    max_tokens: 1000,
    system,
    messages: messages.map(({ role, content }) => ({ role, content })),
  });

  const reply = response.content
    .filter((block) => block.type === 'text')
    .map((block) => block.text)
    .join('\n');

  res.status(200).json({ reply });
}
