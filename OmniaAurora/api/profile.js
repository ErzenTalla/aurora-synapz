import { getProfile, saveProfile } from '../aurora-cli/lib/store.js';

export default async function handler(req, res) {
  if (req.headers['x-aurora-secret'] !== process.env.AURORA_APP_SECRET) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  if (req.method === 'GET') {
    const profile = await getProfile();
    res.status(200).json({ profile });
    return;
  }

  if (req.method === 'POST') {
    const { profile } = req.body || {};
    if (typeof profile !== 'string' || !profile.trim()) {
      res.status(400).json({ error: 'Missing profile content' });
      return;
    }
    await saveProfile(profile);
    res.status(200).json({ profile });
    return;
  }

  res.status(405).json({ error: 'Method not allowed' });
}
