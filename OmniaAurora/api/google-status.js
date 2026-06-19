import { getValidAccessToken, getConnectedEmail } from '../aurora-cli/lib/google.js';

export default async function handler(req, res) {
  if (req.headers['x-aurora-secret'] !== process.env.AURORA_APP_SECRET) {
    res.status(401).json({ error: 'Unauthorized' });
    return;
  }

  const accessToken = await getValidAccessToken();
  if (!accessToken) {
    res.status(200).json({ connected: false, email: null });
    return;
  }

  const email = await getConnectedEmail(accessToken);
  res.status(200).json({ connected: true, email });
}
