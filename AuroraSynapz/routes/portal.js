const express     = require('express');
const requireAuth = require('../middleware/auth');
const db          = require('../db/index');
const alpaca      = require('../services/alpaca');

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

// GET /api/portal/fee-info — client sees their fee rate and last charge date
router.get('/fee-info', async (req, res) => {
  try {
    const { rows: [p] } = await db.query(
      'SELECT fee_rate, last_fee_charged_at FROM portfolios WHERE user_id = $1', [req.user.id]
    );
    res.json(p || { fee_rate: 0.015, last_fee_charged_at: null });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/portal/withdraw — client requests a withdrawal
router.post('/withdraw', async (req, res) => {
  const userId = req.user.id;
  const amount = parseFloat(req.body.amount);

  if (!amount || isNaN(amount) || amount < 100) {
    return res.status(400).json({ error: 'Minimum withdrawal is $100' });
  }

  try {
    const { rows: [portfolio] } = await db.query(
      'SELECT * FROM portfolios WHERE user_id = $1', [userId]
    );
    if (!portfolio) return res.status(404).json({ error: 'Portfolio not found' });

    const currentValue = parseFloat(portfolio.total_value);
    if (amount > currentValue) {
      return res.status(400).json({ error: `Insufficient funds. Available: $${currentValue.toFixed(2)}` });
    }
    if (currentValue - amount < 0) {
      return res.status(400).json({ error: 'Cannot withdraw full balance — a minimum balance is required' });
    }

    // Calculate units to redeem at current fund unit price
    const { rows: [fund] } = await db.query('SELECT * FROM fund WHERE id = 1');
    const unitPrice     = parseFloat(fund.unit_price);
    const unitsToRedeem = amount / unitPrice;
    const clientShare   = parseFloat(portfolio.units_owned) / parseFloat(fund.total_units);

    // Deduct units from client and fund immediately (locks funds)
    await db.query(
      `UPDATE portfolios SET
         units_owned  = units_owned  - $1,
         total_value  = total_value  - $2,
         cash_balance = cash_balance - $3,
         updated_at   = NOW()
       WHERE user_id = $4`,
      [unitsToRedeem, amount, Math.min(amount, parseFloat(portfolio.cash_balance)), userId]
    );
    await db.query(
      `UPDATE fund SET total_value = total_value - $1, total_units = total_units - $2, updated_at = NOW() WHERE id = 1`,
      [amount, unitsToRedeem]
    );

    // Record the withdrawal request
    const { rows: [wr] } = await db.query(
      `INSERT INTO withdrawal_requests (user_id, amount, units_redeemed, unit_price)
       VALUES ($1, $2, $3, $4) RETURNING id`,
      [userId, amount, unitsToRedeem, unitPrice]
    );
    await db.query(
      `INSERT INTO transactions (user_id, type, amount, note) VALUES ($1, 'WITHDRAW', $2, $3)`,
      [userId, amount, `Withdrawal request #${wr.id} — pending processing`]
    );

    // Place Alpaca sell orders to raise cash for the withdrawal
    const sells = await sellForWithdrawal(amount, clientShare).catch(() => []);

    res.json({ success: true, withdrawalId: wr.id, amount, sells });
  } catch (err) {
    console.error('Withdraw error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// GET /api/portal/withdrawals — client's own withdrawal history
router.get('/withdrawals', async (req, res) => {
  try {
    const { rows } = await db.query(
      'SELECT * FROM withdrawal_requests WHERE user_id = $1 ORDER BY created_at DESC',
      [req.user.id]
    );
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

// Sell positions proportionally to raise cash for a withdrawal
async function sellForWithdrawal(amount, clientShare) {
  if (!alpaca.isConfigured()) return [];

  const [account, positions] = await Promise.all([
    alpaca.getAccount(),
    alpaca.getPositions(),
  ]);

  const alpacaCash  = parseFloat(account.cash);
  const clientCash  = alpacaCash * clientShare;
  const sellNeeded  = Math.max(0, amount - clientCash);
  if (sellNeeded < 1 || !positions.length) return [];

  const totalPositionsValue = positions.reduce((s, p) => s + parseFloat(p.market_value || 0), 0);
  if (totalPositionsValue <= 0) return [];

  const results = [];
  for (const pos of positions) {
    const posValue   = parseFloat(pos.market_value || 0);
    const sellAmount = (posValue / totalPositionsValue) * sellNeeded;
    if (sellAmount < 1) continue;
    try {
      const order = await alpaca.submitOrder({
        symbol: pos.symbol, notional: sellAmount.toFixed(2),
        side: 'sell', type: 'market', time_in_force: 'day',
      });
      results.push({ symbol: pos.symbol, amount: sellAmount, status: 'submitted', orderId: order.id });
    } catch (err) {
      results.push({ symbol: pos.symbol, amount: sellAmount, status: 'error', error: err.message });
    }
  }
  return results;
}

module.exports = router;
