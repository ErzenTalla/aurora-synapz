const express    = require('express');
const requireAuth = require('../middleware/auth');
const alpaca     = require('../services/alpaca');
const db         = require('../db/index');

const router = express.Router();

const ASSET_CLASS = {
  SPY: 'Equity',  QQQ: 'Equity',  VTI: 'Equity',  VOO: 'Equity',
  AAPL:'Equity',  MSFT:'Equity',  NVDA:'Equity',  AMZN:'Equity',
  GOOGL:'Equity', META:'Equity',  TSLA:'Equity',  JPM: 'Equity',
  'BRK.B':'Equity',
  BND: 'Fixed Income', AGG: 'Fixed Income', TLT: 'Fixed Income', VXUS: 'Fixed Income',
  GLD: 'Alternative',  SLV: 'Alternative',  VNQ: 'Alternative',  IAU: 'Alternative',
};

function assetClass(symbol) {
  return ASSET_CLASS[symbol] || 'Equity';
}

// GET /api/alpaca/status
router.get('/status', requireAuth, async (req, res) => {
  try {
    const { rows } = await db.query(
      'SELECT * FROM alpaca_sync_log WHERE user_id = $1 ORDER BY synced_at DESC LIMIT 1',
      [req.user.id]
    );
    res.json({ configured: alpaca.isConfigured(), last_sync: rows[0] || null });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/alpaca/sync — pull live data from Alpaca and update the DB
router.post('/sync', requireAuth, async (req, res) => {
  if (!alpaca.isConfigured()) {
    return res.status(503).json({ error: 'Alpaca API keys not configured' });
  }

  try {
    const userId = req.user.id;
    const [account, positions] = await Promise.all([
      alpaca.getAccount(),
      alpaca.getPositions(),
    ]);

    const totalValue  = parseFloat(account.portfolio_value);
    const cashBalance = parseFloat(account.cash);
    const dayChange   = positions.reduce((s, p) => s + parseFloat(p.unrealized_intraday_pl || 0), 0);
    const dayChangePct = totalValue > 0 ? (dayChange / (totalValue - dayChange)) * 100 : 0;

    // Recalculate YTD from last performance_history entry at year start vs now
    const yearStart = `${new Date().getFullYear()}-01-01`;
    const { rows: ytdRows } = await db.query(
      `SELECT value FROM performance_history WHERE user_id = $1 AND date >= $2 ORDER BY date ASC LIMIT 1`,
      [userId, yearStart]
    );
    const ytdBase   = ytdRows[0] ? parseFloat(ytdRows[0].value) : totalValue;
    const ytdReturn    = totalValue - ytdBase;
    const ytdReturnPct = ytdBase > 0 ? (ytdReturn / ytdBase) * 100 : 0;

    // Upsert portfolio row
    await db.query(`
      INSERT INTO portfolios (user_id, total_value, cash_balance, day_change, day_change_pct, ytd_return, ytd_return_pct, updated_at)
      VALUES ($1,$2,$3,$4,$5,$6,$7,NOW())
      ON CONFLICT (user_id) DO UPDATE SET
        total_value    = EXCLUDED.total_value,
        cash_balance   = EXCLUDED.cash_balance,
        day_change     = EXCLUDED.day_change,
        day_change_pct = EXCLUDED.day_change_pct,
        ytd_return     = EXCLUDED.ytd_return,
        ytd_return_pct = EXCLUDED.ytd_return_pct,
        updated_at     = NOW()
    `, [userId, totalValue, cashBalance, dayChange, dayChangePct, ytdReturn, ytdReturnPct]);

    // Replace holdings with live positions
    await db.query('DELETE FROM holdings WHERE user_id = $1', [userId]);
    for (const pos of positions) {
      await db.query(`
        INSERT INTO holdings (user_id, symbol, name, asset_class, shares, price, avg_cost, day_change, day_chg_pct)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
      `, [
        userId,
        pos.symbol,
        pos.symbol,
        assetClass(pos.symbol),
        parseFloat(pos.qty),
        parseFloat(pos.current_price),
        parseFloat(pos.avg_entry_price),
        parseFloat(pos.change_today || 0),
        parseFloat(pos.unrealized_intraday_plpc || 0) * 100,
      ]);
    }

    // Record performance snapshot for today
    const today = new Date().toISOString().split('T')[0];
    await db.query(`
      INSERT INTO performance_history (user_id, date, value) VALUES ($1,$2,$3)
      ON CONFLICT (user_id, date) DO UPDATE SET value = EXCLUDED.value
    `, [userId, today, totalValue]);

    // Log the sync
    await db.query(
      `INSERT INTO alpaca_sync_log (user_id, account_value, positions_count) VALUES ($1,$2,$3)`,
      [userId, totalValue, positions.length]
    );

    res.json({
      synced: true,
      portfolio_value: totalValue,
      cash: cashBalance,
      positions: positions.length,
      synced_at: new Date().toISOString(),
    });
  } catch (err) {
    console.error('Alpaca sync error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
