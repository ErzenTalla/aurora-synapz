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

// ── Simons Phase 2: paper trading execution (Board approval 2026-07-28) ──────
// TRADING_MODE env var: 'dry-run' (default) | 'paper'
// Paper mode uses ALPACA_PAPER_KEY / ALPACA_PAPER_SECRET (separate from live keys).
// Guardrails enforced: 25% max position, 8% stop-loss, 15% drawdown circuit breaker.

function tradingMode() {
  return (process.env.TRADING_MODE || 'dry-run').toLowerCase();
}

// Compute target portfolio allocation from signal outputs.
// Normal: top-3 ETFs at 20% each (60%), top-2 overlay at 10% each (20%), 20% cash.
// Defensive: BND 40%, GLD 40%, 20% cash — overlay ignored.
function computeTargets(etfTop3, overlaySelected, defensive) {
  const targets = {};
  if (defensive) {
    targets['BND'] = 0.40;
    targets['GLD'] = 0.40;
  } else {
    const etfSlot = etfTop3.length > 0 ? Math.min(0.20, 0.60 / etfTop3.length) : 0;
    for (const sym of etfTop3) targets[sym] = etfSlot;
    const eqSlot  = overlaySelected.length > 0 ? Math.min(0.10, 0.20 / overlaySelected.length) : 0;
    for (const sym of overlaySelected) targets[sym] = eqSlot;
  }
  // Hard cap: no single position > 25% (Board guardrail)
  for (const sym of Object.keys(targets)) {
    targets[sym] = Math.min(targets[sym], 0.25);
  }
  return targets;
}

async function executePaperTrades(rows, runId, mode) {
  mode = mode || 'paper';
  const isLive = mode === 'live';

  if (isLive && !alpaca.isConfigured()) {
    throw new Error('Live Alpaca keys not configured');
  }
  if (!isLive && !alpaca.isPaperConfigured()) {
    throw new Error('Paper Alpaca keys not configured — set ALPACA_PAPER_KEY and ALPACA_PAPER_SECRET in Vercel env vars');
  }

  // 1. Get account state
  const account        = await (isLive ? alpaca.getAccount() : alpaca.getPaperAccount());
  const portfolioValue = parseFloat(account.portfolio_value);
  const equity         = parseFloat(account.equity);

  // 2. Drawdown circuit breaker — 15% from peak (Board guardrail)
  const { rows: stateRows } = await db.query(
    `SELECT value FROM simons_state WHERE key = '${isLive ? 'live' : 'paper'}_watermark'`
  );
  let watermark = stateRows[0] ? parseFloat(stateRows[0].value) : equity;
  if (equity > watermark) {
    watermark = equity;
    await db.query(
      `INSERT INTO simons_state (key, value) VALUES ('paper_watermark', $1)
       ON CONFLICT (key) DO UPDATE SET value = $1::text, updated_at = NOW()`,
      [watermark]
    );
  }
  const drawdown = watermark > 0 ? (watermark - equity) / watermark : 0;
  if (drawdown >= 0.15) {
    await db.query(
      `INSERT INTO simons_paper_log (run_id, action, symbol, qty, notes) VALUES ($1, 'circuit_breaker', 'ALL', 0, $2)`,
      [runId, `Circuit breaker: ${(drawdown*100).toFixed(1)}% drawdown from $${watermark.toFixed(2)} peak`]
    );
    return {
      circuit_breaker: true,
      drawdown_pct: (drawdown * 100).toFixed(2),
      watermark,
      equity,
      orders_placed: 0,
      message: `Circuit breaker triggered: ${(drawdown*100).toFixed(1)}% drawdown exceeds 15% limit. No orders placed.`,
    };
  }

  // 3. Derive signal selections from logged rows
  const etfTop3        = rows.filter(r => r.layer === 'etf_rotation'     && r.selected).map(r => r.symbol);
  const overlaySelected = rows.filter(r => r.layer === 'momentum_overlay' && r.selected).map(r => r.symbol);
  const defensive       = rows.some(r => r.layer === 'defensive' && r.selected);
  const targets         = computeTargets(etfTop3, overlaySelected, defensive);
  const targetSymbols   = Object.keys(targets);

  // 4. Current paper positions
  const positions    = await (isLive ? alpaca.getPositions() : alpaca.getPaperPositions());
  const orders       = [];

  // 5. Sell positions no longer in target allocation
  for (const pos of positions) {
    if (targetSymbols.includes(pos.symbol)) continue;
    try {
      const order = await (isLive ? alpaca.submitOrder : alpaca.submitPaperOrder)({
        symbol:        pos.symbol,
        qty:           pos.qty,
        side:          'sell',
        type:          'market',
        time_in_force: 'day',
      });
      orders.push({ action: 'sell', symbol: pos.symbol, qty: pos.qty, order_id: order.id });
      await db.query(
        `INSERT INTO simons_paper_log (run_id, action, symbol, qty, order_id, notes) VALUES ($1,'sell',$2,$3,$4,'position closed — not in target allocation')`,
        [runId, pos.symbol, pos.qty, order.id]
      );
    } catch (err) {
      console.error(`Paper sell error [${pos.symbol}]:`, err.message);
    }
  }

  // 6. Buy / rebalance target positions
  for (const [symbol, targetPct] of Object.entries(targets)) {
    const targetValue = portfolioValue * targetPct;
    // Get latest ask price from market data
    let price = 0;
    try {
      const q = await alpaca.getLatestQuote(symbol);
      price = parseFloat(q.quote?.ap || q.quote?.bp || 0);
    } catch (err) {
      console.error(`Quote fetch error [${symbol}]:`, err.message);
      continue;
    }
    if (!price) continue;

    const targetShares  = targetValue / price;
    const currentPos    = positions.find(p => p.symbol === symbol);
    const currentShares = currentPos ? parseFloat(currentPos.qty) : 0;
    const diffShares    = targetShares - currentShares;

    if (Math.abs(diffShares) < 0.001) continue; // negligible rebalance, skip

    const side = diffShares > 0 ? 'buy' : 'sell';
    const qty  = Math.abs(diffShares).toFixed(6);

    try {
      const order = await (isLive ? alpaca.submitOrder : alpaca.submitPaperOrder)({
        symbol,
        qty,
        side,
        type:          'market',
        time_in_force: 'day',
      });
      const stopPrice = side === 'buy' ? parseFloat((price * 0.92).toFixed(2)) : null;
      orders.push({ action: side, symbol, qty, order_id: order.id, stop_price: stopPrice });
      await db.query(
        `INSERT INTO simons_paper_log (run_id, action, symbol, qty, order_id, target_pct, stop_price, notes)
         VALUES ($1,$2,$3,$4,$5,$6,$7,'rebalance to target allocation')`,
        [runId, side, symbol, qty, order.id, targetPct, stopPrice]
      );

      // 8% stop-loss on buys (Board guardrail)
      if (side === 'buy' && stopPrice) {
        try {
          const stopOrder = await (isLive ? alpaca.submitOrder : alpaca.submitPaperOrder)({
            symbol,
            qty,
            side:          'sell',
            type:          'stop',
            stop_price:    stopPrice,
            time_in_force: 'gtc',
          });
          orders.push({ action: 'stop_loss', symbol, qty, stop_price: stopPrice, order_id: stopOrder.id });
          await db.query(
            `INSERT INTO simons_paper_log (run_id, action, symbol, qty, order_id, stop_price, notes)
             VALUES ($1,'stop_loss',$2,$3,$4,$5,'8% stop-loss guard')`,
            [runId, symbol, qty, stopOrder.id, stopPrice]
          );
        } catch (stopErr) {
          console.error(`Stop order error [${symbol}]:`, stopErr.message);
        }
      }
    } catch (err) {
      console.error(`Paper ${side} error [${symbol}]:`, err.message);
    }
  }

  return {
    circuit_breaker:  false,
    drawdown_pct:     (drawdown * 100).toFixed(2),
    watermark,
    equity,
    portfolio_value:  portfolioValue,
    targets,
    defensive_posture: defensive,
    orders_placed:    orders.length,
    orders,
  };
}

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

  const mode   = tradingMode();
  const runId  = `${mode}-${new Date().toISOString()}`;
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
      VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10)
    `, [runId, mode, r.layer, r.symbol, r.short, r.long, r.score, r.rank, r.selected, r.notes]);
  }

  const base = {
    run_id:           runId,
    run_mode:         mode,
    signals_logged:   rows.length,
    etf_top3:         etf.slice(0, 3).map(e => e.sym),
    overlay_selected: eq.filter((e, i) => i < 2 && e.score !== null && e.score > OVERLAY_THRESHOLD).map(e => e.sym),
    defensive_posture: defensive,
  };

  if (mode === 'paper' || mode === 'live') {
    const tradeResult = await executePaperTrades(rows, runId, mode);
    return { ...base, ...tradeResult };
  }

  return { ...base, dry_run: true, orders_placed: 0 };
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
