import { listBriefings, getBriefing, extractBriefingText } from '../aurora-cli/lib/store.js';

export default async function handler(req, res) {
  if (req.method !== 'GET') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  if (req.headers['x-aurora-secret'] !== process.env.AURORA_APP_SECRET) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const { date } = req.query;

  if (!date) {
    const briefings = await listBriefings();
    res.status(200).json({ briefings });
    return;
  }

  try {
    const content = await getBriefing(date);
    res.status(200).json({ date, briefing: extractBriefingText(content) });
  } catch {
    res.status(404).json({ error: `No briefing found for ${date}` });
  }
}
