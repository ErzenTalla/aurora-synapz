import Anthropic from '@anthropic-ai/sdk';
import { BRIEFING_SYSTEM_PROMPT, buildUserMessage, formatTrackedContext } from '../aurora-cli/lib/buildPrompt.js';
import { formatTodayContext } from '../aurora-cli/lib/questions.js';
import { getProfile, saveBriefing, getTrackedContext } from '../aurora-cli/lib/store.js';

export default async function handler(req, res) {
  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  if (req.headers['x-aurora-secret'] !== process.env.AURORA_APP_SECRET) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const profile = await getProfile();
  const todayContext = formatTodayContext(req.body || {});
  const trackedContext = formatTrackedContext(await getTrackedContext());
  const now = new Date();
  const date = now.toISOString().slice(0, 10);
  const today = now.toLocaleDateString('en-US', { weekday: 'long', year: 'numeric', month: 'long', day: 'numeric' });

  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  const model = process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-5';

  const response = await client.messages.create({
    model,
    max_tokens: 2000,
    system: BRIEFING_SYSTEM_PROMPT,
    messages: [{ role: 'user', content: buildUserMessage({ profile, todayContext, today, trackedContext }) }],
  });

  const briefing = response.content
    .filter((block) => block.type === 'text')
    .map((block) => block.text)
    .join('\n');

  await saveBriefing(
    date,
    `# Aurora Daily Executive Briefing — ${date}\n\n## Input context\n${todayContext}\n\n## Briefing\n${briefing}\n`
  );

  res.status(200).json({ date, briefing });
}
