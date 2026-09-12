const crypto = require('crypto');
const db     = require('../db/index');

const RATE_LIMIT = 10; // calls per day per key

module.exports = async function apiAuth(req, res, next) {
  const start = Date.now();

  const key = req.headers['x-api-key'];
  if (!key) return res.status(401).json({ error: 'Missing X-API-Key header', code: 'NO_KEY' });

  const keyHash = crypto.createHash('sha256').update(key).digest('hex');

  let client;
  try {
    const { rows } = await db.query(
      'SELECT * FROM api_clients WHERE api_key_hash = $1', [keyHash]
    );
    client = rows[0];
  } catch (err) {
    return res.status(500).json({ error: 'Auth check failed', code: 'DB_ERROR' });
  }

  if (!client) return res.status(401).json({ error: 'Invalid API key', code: 'INVALID_KEY' });
  if (!client.active) return res.status(403).json({ error: 'API key revoked', code: 'KEY_REVOKED' });

  // Reset daily counter if window_date is not today
  const today = new Date().toISOString().split('T')[0];
  if (client.window_date.toISOString().split('T')[0] !== today) {
    await db.query(
      'UPDATE api_clients SET calls_today=0, window_date=$1 WHERE id=$2',
      [today, client.id]
    );
    client.calls_today = 0;
  }

  // Rate limit check
  if (client.calls_today >= RATE_LIMIT) {
    const now = new Date();
    const midnight = new Date(Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate() + 1));
    const secondsUntilReset = Math.ceil((midnight - now) / 1000);
    res.set('Retry-After', String(secondsUntilReset));
    return res.status(429).json({
      error: 'Rate limit exceeded. Maximum 10 calls per day.',
      code: 'RATE_LIMIT_EXCEEDED',
      retry_after: secondsUntilReset,
      resets_at: midnight.toISOString(),
    });
  }

  // Increment counter
  await db.query(
    'UPDATE api_clients SET calls_today = calls_today + 1 WHERE id = $1',
    [client.id]
  );

  // Attach client to request for logging
  req.apiClient = client;
  req.apiStart  = start;

  // Log usage after response
  res.on('finish', async () => {
    const ms = Date.now() - start;
    await db.query(
      'INSERT INTO api_usage_log (client_id, endpoint, status_code, response_ms) VALUES ($1,$2,$3,$4)',
      [client.id, req.path, res.statusCode, ms]
    ).catch(() => {}); // never crash on logging failure
  });

  next();
};
