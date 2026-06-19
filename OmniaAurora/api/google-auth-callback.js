import { exchangeCodeForTokens } from '../aurora-cli/lib/google.js';

export default async function handler(req, res) {
  const { code, error } = req.query;

  res.setHeader('Content-Type', 'text/html');

  if (error || !code) {
    res.status(400).send(`<p>Google sign-in failed: ${error || 'no code returned'}.</p>`);
    return;
  }

  try {
    await exchangeCodeForTokens(code);
  } catch (err) {
    res.status(500).send(`<p>Failed to connect Google account: ${err.message}</p>`);
    return;
  }

  res.status(200).send(`
    <html><body style="font-family: -apple-system, sans-serif; text-align: center; padding-top: 80px;">
      <h2>Google account connected</h2>
      <p>You can close this and return to the Aurora app.</p>
    </body></html>
  `);
}
