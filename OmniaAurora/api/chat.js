import Anthropic from '@anthropic-ai/sdk';
import { CHAT_SYSTEM_PROMPT, formatTrackedContext } from '../aurora-cli/lib/buildPrompt.js';
import { getProfile, getTrackedContext } from '../aurora-cli/lib/store.js';
import { getGoogleContext } from '../aurora-cli/lib/google.js';
import { getProjectContext } from '../aurora-cli/lib/github.js';

const TOOLS = [
  {
    name: 'add_task',
    description:
      "Add a new task to the user's task list. Use this only when the user explicitly asks to add, track, or create a task. Always describe the action in your text reply (e.g. \"I'll add 'X' to your Y tasks\") — the user sees a confirmation prompt before the task is actually created.",
    input_schema: {
      type: 'object',
      properties: {
        text: { type: 'string', description: 'Concise but specific task description.' },
        domain: {
          type: 'string',
          enum: ['alpinetech', 'aurorasynapz', 'omnia', 'personal', 'general'],
          description: 'Project or life area this task belongs to.',
        },
      },
      required: ['text', 'domain'],
    },
  },
];

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
  const [googleContext, githubContext] = await Promise.all([getGoogleContext(), getProjectContext()]);
  const extraContext = [googleContext, githubContext].filter(Boolean).join('\n\n');
  const trackedContext = formatTrackedContext(await getTrackedContext()) + (extraContext ? `\n\n${extraContext}` : '');
  const client = new Anthropic({ apiKey: process.env.ANTHROPIC_API_KEY });
  const model = process.env.ANTHROPIC_MODEL || 'claude-sonnet-4-5';

  const system = `${CHAT_SYSTEM_PROMPT}\n\nPERMANENT PROFILE:\n${profile}\n\n${trackedContext}\n\nTHE BRIEFING YOU GAVE ON ${briefingDate || 'an earlier day'}:\n${briefingText || '(not provided)'}`;

  const response = await client.messages.create({
    model,
    max_tokens: 1000,
    system,
    messages: messages.map(({ role, content }) => ({ role, content })),
    tools: TOOLS,
    tool_choice: { type: 'auto' },
  });

  const reply = response.content
    .filter((block) => block.type === 'text')
    .map((block) => block.text)
    .join('\n');

  const toolUseBlock = response.content.find((block) => block.type === 'tool_use');
  const pendingAction = toolUseBlock
    ? { type: toolUseBlock.name, params: toolUseBlock.input }
    : null;

  // If Claude went straight to tool_use with no text, give a fallback verbal description
  const finalReply = reply || (pendingAction ? `I'll add that to your tasks — confirm below.` : '');

  res.status(200).json({ reply: finalReply, ...(pendingAction ? { pendingAction } : {}) });
}
