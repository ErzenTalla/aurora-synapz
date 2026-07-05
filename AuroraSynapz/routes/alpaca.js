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

// ── Core sync logic ──────────────────────────────────────────────
// Pulls one Alpaca account and redistributes value to ALL clients
// proportionally based on their units_owned in the fund.
async function runFundSync() {
  if (!alpaca.isConfigured()) throw new Error('Alpaca API keys not configured');

  const [account, positions] = await Promise.all([
    alpaca.getAccount(),
    alpaca.getPositions(),
  ]);

  const totalValue  = parseFloat(account.portfolio_value);
  const cashBalance = parseFloat(account.cash);
  const dayChange   = positions.reduce((s, p) => s + parseFloat(p.unrealized_intraday_pl || 0), 0);

  // Update fund unit price
  const { rows: [fund] } = await db.query('SELECT * FROM fund WHERE id = 1');
  const totalUnits = parseFloat(fund.total_units);
  const unitPrice  = totalUnits > 0 ? totalValue / totalUnits : 1.0;

  await db.query(
    `UPDATE fund SET total_value=$1, unit_price=$2, updated_at=NOW() WHERE id=1`,
    [totalValue, unitPrice]
  );

  // Replace fund-level holdings with live positions
  // Holdings are stored per-client proportionally — rebuild for all clients
  const { rows: clients } = await db.query(
    `SELECT user_id, units_owned FROM portfolios WHERE units_owned > 0`
  );

  const today    = new Date().toISOString().split('T')[0];
  const yearStart = `${new Date().getFullYear()}-01-01`;

  for (const client of clients) {
    const clientUnits = parseFloat(client.units_owned);
    const share       = totalUnits > 0 ? clientUnits / totalUnits : 0;
    const clientValue = clientUnits * unitPrice;
    const clientCash  = cashBalance * share;
    const clientDayChange    = dayChange * share;
    const clientDayChangePct = clientValue > 0 ? (clientDayChange / (clientValue - clientDayChange)) * 100 : 0;
    const userId = client.user_id;

    // YTD from first performance_history entry at year start
    const { rows: ytdRows } = await db.query(
      `SELECT value FROM performance_history WHERE user_id=$1 AND date >= $2 ORDER BY date ASC LIMIT 1`,
      [userId, yearStart]
    );
    const ytdBase      = ytdRows[0] ? parseFloat(ytdRows[0].value) : clientValue;
    const ytdReturn    = clientValue - ytdBase;
    const ytdReturnPct = ytdBase > 0 ? (ytdReturn / ytdBase) * 100 : 0;

    // Update portfolio
    await db.query(`
      UPDATE portfolios SET
        total_value    = $1,
        cash_balance   = $2,
        day_change     = $3,
        day_change_pct = $4,
        ytd_return     = $5,
        ytd_return_pct = $6,
        updated_at     = NOW()
      WHERE user_id = $7
    `, [clientValue, clientCash, clientDayChange, clientDayChangePct, ytdReturn, ytdReturnPct, userId]);

    // Replace holdings with proportional share of each position
    await db.query('DELETE FROM holdings WHERE user_id = $1', [userId]);
    for (const pos of positions) {
      const posValue     = parseFloat(pos.market_value || 0);
      const clientShares = parseFloat(pos.qty) * share;
      const price        = parseFloat(pos.current_price);
      const avgCost      = parseFloat(pos.avg_entry_price);
      await db.query(`
        INSERT INTO holdings (user_id, symbol, name, asset_class, shares, price, avg_cost, day_change, day_chg_pct)
        VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)
      `, [
        userId,
        pos.symbol,
        pos.symbol,
        assetClass(pos.symbol),
        clientShares,
        price,
        avgCost,
        parseFloat(pos.change_today || 0),
        parseFloat(pos.unrealized_intraday_plpc || 0) * 100,
      ]);
    }

    // Daily performance snapshot
    await db.query(`
      INSERT INTO performance_history (user_id, date, value) VALUES ($1,$2,$3)
      ON CONFLICT (user_id, date) DO UPDATE SET value = EXCLUDED.value
    `, [userId, today, clientValue]);

    // Sync log
    await db.query(
      `INSERT INTO alpaca_sync_log (user_id, account_value, positions_count) VALUES ($1,$2,$3)`,
      [userId, clientValue, positions.length]
    );
  }

  return { totalValue, cashBalance, positions: positions.length, clients: clients.length, unitPrice };
}

// ── GET /api/alpaca/status ───────────────────────────────────────
router.get('/status', requireAuth, async (req, res) => {
  try {
    const { rows } = await db.query(
      'SELECT * FROM alpaca_sync_log WHERE user_id = $1 ORDER BY synced_at DESC LIMIT 1',
      [req.user.id]
    );
    const { rows: [fund] } = await db.query('SELECT * FROM fund WHERE id = 1');
    res.json({ configured: alpaca.isConfigured(), last_sync: rows[0] || null, fund });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// ── POST /api/alpaca/sync — manual sync triggered by logged-in user ──
router.post('/sync', requireAuth, async (req, res) => {
  try {
    const result = await runFundSync();
    res.json({ synced: true, ...result, synced_at: new Date().toISOString() });
  } catch (err) {
    console.error('Alpaca sync error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── GET /api/alpaca/cron-sync — called by Vercel cron (no user auth) ──
// Protected by optional CRON_SECRET env var.
router.get('/cron-sync', async (req, res) => {
  const cronSecret = process.env.CRON_SECRET || '';
  if (cronSecret) {
    const auth = req.headers.authorization || '';
    if (auth !== `Bearer ${cronSecret}`) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
  }
  try {
    const result = await runFundSync();
    res.json({ synced: true, ...result, synced_at: new Date().toISOString() });
  } catch (err) {
    console.error('Cron sync error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── Simons Phase 1: strategy signal computation — DRY-RUN ONLY ───
// Board approval 2026-06-29; Head of IT sign-off 2026-07-04.
// This code path computes and LOGS signals to strategy_signals.
// It NEVER calls alpaca.submitOrder() and has no execution branch.
// Phase 2 (paper trading) requires separate Board approval.

const CORE_ETFS         = ['SPY', 'QQQ', 'VTI', 'BND', 'GLD'];
const OVERLAY_EQUITIES  = ['AAPL', 'MSFT', 'NVDA', 'AMZN', 'GOOGL', 'META', 'TSLA'];
const OVERLAY_THRESHOLD = 0.02;  // min composite momentum to select overlay equity
const DEFENSIVE_TRIGGER = -0.05; // SPY 20-day momentum below this → defensive posture

function isoDaysAgo(days) {
  return new Date(Date.now() - days * 86400000).toISOString().split('T')[0];
}

async function fetchDailyCloses(symbol) {
  const feed = process.env.ALPACA_DATA_FEED || 'iex';
  const qs = `?timeframe=1Day&start=${isoDaysAgo(300)}&limit=210&adjustment=split&feed=${feed}`;
  const data = await alpaca.getBars(symbol, qs);
  return (data.bars || []).map(b => b.c);
}

// Percent return over the last `lookback` trading days
function pctReturn(closes, lookback) {
  if (!closes || closes.length < lookback + 1) return null;
  const latest = closes[closes.length - 1];
  const past   = closes[closes.length - 1 - lookback];
  return past > 0 ? (latest - past) / past : null;
}

async function runStrategySignals() {
  if (!alpaca.isConfigured()) throw new Error('Alpaca API keys not configured');

  const runId  = `dryrun-${new Date().toISOString()}`;
  const closes = {};
  for (const sym of [...new Set([...CORE_ETFS, ...OVERLAY_EQUITIES])]) {
    try {
      closes[sym] = await fetchDailyCloses(sym);
    } catch (err) {
      closes[sym] = null;
      console.error(`strategy-run: bars fetch failed for ${sym}: ${err.message}`);
    }
  }

  const rows = [];

  // Core ETF rotation layer — 3-month (63d) + 6-month (126d), 50/50 composite
  const etf = CORE_ETFS.map(sym => {
    const short = pctReturn(closes[sym], 63);
    const long  = pctReturn(closes[sym], 126);
    const score = short !== null && long !== null ? 0.5 * short + 0.5 * long : null;
    return { sym, short, long, score };
  }).sort((a, b) => (b.score ?? -Infinity) - (a.score ?? -Infinity));
  etf.forEach((e, i) => rows.push({
    layer: 'etf_rotation', symbol: e.sym, short: e.short, long: e.long,
    score: e.score, rank: i + 1,
    selected: i < 3 && e.score !== null && e.score > 0,
    notes: e.score === null ? 'insufficient data' : null,
  }));

  // Momentum overlay layer — 20d + 50d, top 2 above threshold
  const eq = OVERLAY_EQUITIES.map(sym => {
    const short = pctReturn(closes[sym], 20);
    const long  = pctReturn(closes[sym], 50);
    const score = short !== null && long !== null ? 0.5 * short + 0.5 * long : null;
    return { sym, short, long, score };
  }).sort((a, b) => (b.score ?? -Infinity) - (a.score ?? -Infinity));
  eq.forEach((e, i) => rows.push({
    layer: 'momentum_overlay', symbol: e.sym, short: e.short, long: e.long,
    score: e.score, rank: i + 1,
    selected: i < 2 && e.score !== null && e.score > OVERLAY_THRESHOLD,
    notes: e.score === null ? 'insufficient data' : null,
  }));

  // Defensive check — SPY 20-day momentum
  const spy20 = pctReturn(closes.SPY, 20);
  const defensive = spy20 !== null && spy20 < DEFENSIVE_TRIGGER;
  rows.push({
    layer: 'defensive', symbol: 'SPY', short: spy20, long: null, score: spy20,
    rank: null, selected: defensive,
    notes: defensive ? 'DEFENSIVE: rotate signal to BND+GLD (log only — no orders)' : 'normal posture',
  });

  for (const r of rows) {
    await db.query(`
      INSERT INTO strategy_signals
        (run_id, run_mode, layer, symbol, momentum_short, momentum_long, composite_score, rank, selected, notes)
      VALUES ($1, 'dry-run', $2, $3, $4, $5, $6, $7, $8, $9)
    `, [runId, r.layer, r.symbol, r.short, r.long, r.score, r.rank, r.selected, r.notes]);
  }

  return {
    run_id: runId,
    dry_run: true,
    orders_placed: 0,
    signals_logged: rows.length,
    etf_top3: etf.slice(0, 3).map(e => e.sym),
    overlay_selected: eq.filter((e, i) => i < 2 && e.score !== null && e.score > OVERLAY_THRESHOLD).map(e => e.sym),
    defensive_posture: defensive,
  };
}

// ── POST /api/alpaca/strategy-run — admin-triggered dry run ──────
router.post('/strategy-run', requireAuth, async (req, res) => {
  if (req.user.role !== 'admin') {
    return res.status(403).json({ error: 'Admin only' });
  }
  try {
    const result = await runStrategySignals();
    res.json({ ...result, ran_at: new Date().toISOString() });
  } catch (err) {
    console.error('Strategy run error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// ── GET /api/alpaca/cron-strategy-run — Vercel cron (CRON_SECRET) ─
router.get('/cron-strategy-run', async (req, res) => {
  const cronSecret = process.env.CRON_SECRET || '';
  if (cronSecret) {
    const auth = req.headers.authorization || '';
    if (auth !== `Bearer ${cronSecret}`) {
      return res.status(401).json({ error: 'Unauthorized' });
    }
  }
  try {
    const result = await runStrategySignals();
    res.json({ ...result, ran_at: new Date().toISOString() });
  } catch (err) {
    console.error('Cron strategy run error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
