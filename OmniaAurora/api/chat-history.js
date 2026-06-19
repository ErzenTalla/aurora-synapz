import { getJSON, saveJSON } from '../aurora-cli/lib/store.js';

export default async function handler(req, res) {
  if (req.headers['x-aurora-secret'] !== process.env.AURORA_APP_SECRET) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { date } = req.query;
  if (!date) {
    res.status(400).json({ error: 'Missing date' });
    return;
  }
  const pathname = `chat-history/${date}.json`;

  if (req.method === 'GET') {
    const data = await getJSON(pathname, { messages: [] });
    res.status(200).json(data);
    return;
  }

  if (req.method === 'POST') {
    const { messages } = req.body || {};
    if (!Array.isArray(messages)) {
      res.status(400).json({ error: 'Missing messages' });
      return;
    }
    await saveJSON(pathname, { messages });
    res.status(200).json({ messages });
    return;
  }

  res.status(405).json({ error: 'Method not allowed' });
}
