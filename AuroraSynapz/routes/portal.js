const express     = require('express');
const requireAuth = require('../middleware/auth');
const db          = require('../db/index');

const router = express.Router();
router.use(requireAuth);

router.get('/overview', async (req, res) => {
  try {
    const { rows: [portfolio] } = await db.query(
      'SELECT * FROM portfolios WHERE user_id = $1', [req.user.id]
    );
    if (!portfolio) return res.status(404).json({ error: 'Portfolio not found' });

    const { rows: holdings } = await db.query(
      'SELECT shares, avg_cost FROM holdings WHERE user_id = $1', [req.user.id]
    );
    const totalInvested  = holdings.reduce((s, h) => s + parseFloat(h.shares) * parseFloat(h.avg_cost), 0);
    const allTimeGain    = parseFloat(portfolio.total_value) - parseFloat(portfolio.cash_balance) - totalInvested;
    const allTimeGainPct = totalInvested > 0 ? (allTimeGain / totalInvested) * 100 : 0;

    res.json({ ...portfolio, total_invested: totalInvested, all_time_gain: allTimeGain, all_time_gain_pct: allTimeGainPct });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/holdings', async (req, res) => {
  try {
    const { rows } = await db.query(
      'SELECT * FROM holdings WHERE user_id = $1 ORDER BY shares * price DESC', [req.user.id]
    );
    const enriched = rows.map(h => ({
      ...h,
      market_value:    parseFloat(h.shares) * parseFloat(h.price),
      total_gain:      parseFloat(h.shares) * (parseFloat(h.price) - parseFloat(h.avg_cost)),
      total_gain_pct:  ((parseFloat(h.price) - parseFloat(h.avg_cost)) / parseFloat(h.avg_cost)) * 100,
      day_change_total: parseFloat(h.shares) * parseFloat(h.day_change),
    }));
    res.json(enriched);
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/transactions', async (req, res) => {
  try {
    const limit = Math.min(parseInt(req.query.limit || '20'), 100);
    const { rows } = await db.query(
      'SELECT * FROM transactions WHERE user_id = $1 ORDER BY created_at DESC LIMIT $2',
      [req.user.id, limit]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/performance', async (req, res) => {
  try {
    const range = req.query.range || '1Y';
    const days  = { '1M': 30, '3M': 90, '6M': 180, '1Y': 365, 'ALL': 9999 }[range] || 365;
    const cutoff = new Date();
    cutoff.setDate(cutoff.getDate() - days);
    const cutoffStr = cutoff.toISOString().split('T')[0];

    const { rows } = await db.query(
      `SELECT TO_CHAR(date, 'YYYY-MM-DD') AS date, value
       FROM performance_history
       WHERE user_id = $1 AND date >= $2
       ORDER BY date ASC`,
      [req.user.id, cutoffStr]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/allocation', async (req, res) => {
  try {
    const { rows: holdings } = await db.query(
      'SELECT asset_class, shares, price FROM holdings WHERE user_id = $1', [req.user.id]
    );
    const { rows: [portfolio] } = await db.query(
      'SELECT cash_balance, total_value FROM portfolios WHERE user_id = $1', [req.user.id]
    );

    const buckets = {};
    for (const h of holdings) {
      const val = parseFloat(h.shares) * parseFloat(h.price);
      buckets[h.asset_class] = (buckets[h.asset_class] || 0) + val;
    }
    buckets['Cash'] = parseFloat(portfolio.cash_balance);

    const total = parseFloat(portfolio.total_value);
    const allocation = Object.entries(buckets).map(([label, value]) => ({
      label,
      value: Math.round(value * 100) / 100,
      pct:   Math.round((value / total) * 10000) / 100,
    }));
    res.json(allocation);
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

router.get('/documents', async (req, res) => {
  try {
    const { rows } = await db.query(
      'SELECT * FROM documents WHERE user_id = $1 ORDER BY created_at DESC', [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

module.exports = router;
