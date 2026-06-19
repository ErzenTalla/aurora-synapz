import { disconnectGoogle } from '../aurora-cli/lib/google.js';

export default async function handler(req, res) {
  if (req.headers['x-aurora-secret'] !== process.env.AURORA_APP_SECRET) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  if (req.method !== 'POST') {
    res.status(405).json({ error: 'Method not allowed' });
    return;
  }

  await disconnectGoogle();
  res.status(200).json({ ok: true });
}
