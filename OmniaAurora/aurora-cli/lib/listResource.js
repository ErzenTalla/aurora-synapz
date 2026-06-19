import { randomUUID } from 'node:crypto';
import { getJSON, saveJSON } from './store.js';

export function createListResourceHandler(pathname, itemKey) {
  return async function handler(req, res) {
    if (req.headers['x-aurora-secret'] !== process.env.AURORA_APP_SECRET) {
      res.status(401).json({ error: 'Unauthorized' });
      return;
    }

    const data = await getJSON(pathname, { [itemKey]: [] });

    if (req.method === 'GET') {
      res.status(200).json(data);
      return;
    }

    if (req.method === 'POST') {
      const item = { id: randomUUID(), createdAt: new Date().toISOString(), ...(req.body || {}) };
      data[itemKey].push(item);
      await saveJSON(pathname, data);
      res.status(200).json(item);
      return;
    }

    if (req.method === 'PATCH') {
      const { id } = req.query;
      const item = data[itemKey].find((i) => i.id === id);
      if (!item) {
        res.status(404).json({ error: 'Not found' });
        return;
      }
      Object.assign(item, req.body || {});
      await saveJSON(pathname, data);
      res.status(200).json(item);
      return;
    }

    if (req.method === 'DELETE') {
      const { id } = req.query;
      data[itemKey] = data[itemKey].filter((i) => i.id !== id);
      await saveJSON(pathname, data);
      res.status(200).json({ ok: true });
      return;
    }

    res.status(405).json({ error: 'Method not allowed' });
  };
}
