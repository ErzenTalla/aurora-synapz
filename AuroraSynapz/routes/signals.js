const express  = require('express');
const db       = require('../db/index');
const apiAuth  = require('../middleware/apiAuth');

const router = express.Router();
const DISCLAIMER = 'For informational purposes only. Not investment advice. Past performance does not guarantee future results.';

function assetClass(symbol) {
  const etfs = ['SPY','QQQ','VTI','BND','GLD'];
  return etfs.includes(symbol) ? 'etf' : 'equity';
}

// ── GET /api/v1/signals/status — health check, no auth required
router.get('/status', async (req, res) => {
  try {
    const { rows } = await db.query(`
      SELECT run_id, run_mode, created_at
      FROM strategy_signals
      ORDER BY created_at DESC LIMIT 1
    `);
    const last = rows[0];
    const { rows: cb } = await db.query(
      `SELECT value FROM simons_state WHERE key = 'circuit_breaker'`
    );
    res.json({
      status: 'ok',
      last_run_id: last?.run_id || null,
      last_run_at: last?.created_at || null,
      trading_mode: last?.run_mode || null,
      circuit_breaker: cb[0]?.value === 'true',
    });
  } catch (err) {
    res.status(500).json({ error: 'Status check failed' });
  }
});

// ── GET /api/v1/signals/latest — most recent signal set
router.get('/latest', apiAuth, async (req, res) => {
  try {
    // Get the latest run_id
    const { rows: runRows } = await db.query(`
      SELECT DISTINCT run_id, run_mode, created_at
      FROM strategy_signals
      ORDER BY created_at DESC LIMIT 1
    `);
    if (!runRows.length) return res.status(404).json({ error: 'No signals available yet', code: 'NO_SIGNALS' });

    const { run_id, run_mode, created_at } = runRows[0];
    const market_date = new Date(created_at).toISOString().split('T')[0];

    // Get selected signals for this run
    const { rows: signals } = await db.query(`
      SELECT symbol, selected, target_pct, notes
      FROM strategy_signals
      WHERE run_id = $1 AND selected = TRUE
      ORDER BY rank ASC
    `, [run_id]);

    // Check circuit breaker
    const { rows: cb } = await db.query(
      `SELECT value FROM simons_state WHERE key = 'circuit_breaker'`
    );
    const circuit_breaker = cb[0]?.value === 'true';

    // Check defensive posture (BND or GLD dominant)
    const symbols = signals.map(s => s.symbol);
    const defensive_posture = symbols.includes('BND') && !symbols.includes('SPY');

    // Build signal array with weights
    const totalSignals = signals.length;
    const equityWeight = 0.80;
    const cashWeight   = 0.20;
    const perSignal    = totalSignals > 0 ? equityWeight / totalSignals : 0;

    const signalArray = circuit_breaker ? [] : signals.map(s => ({
      symbol:        s.symbol,
      action:        'buy',
      target_weight: parseFloat((perSignal).toFixed(4)),
      asset_class:   assetClass(s.symbol),
    }));

    res.json({
      run_id,
      generated_at:      created_at,
      market_date,
      trading_mode:      run_mode,
      defensive_posture,
      circuit_breaker,
      signals:           signalArray,
      cash_weight:       circuit_breaker ? 1.0 : parseFloat(cashWeight.toFixed(4)),
      disclaimer:        DISCLAIMER,
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch signals' });
  }
});

// ── GET /api/v1/signals/history?days=N — last N days of signals
router.get('/history', apiAuth, async (req, res) => {
  try {
    const days = Math.min(parseInt(req.query.days || '7'), 90);

    const { rows } = await db.query(`
      SELECT DISTINCT ON (DATE(created_at)) run_id, run_mode, created_at
      FROM strategy_signals
      WHERE created_at >= NOW() - ($1 || ' days')::INTERVAL
      ORDER BY DATE(created_at) DESC, created_at DESC
    `, [days]);

    const history = await Promise.all(rows.map(async (run) => {
      const { rows: signals } = await db.query(`
        SELECT symbol, selected, rank
        FROM strategy_signals
        WHERE run_id = $1 AND selected = TRUE
        ORDER BY rank ASC
      `, [run.run_id]);

      const totalSignals = signals.length;
      const perSignal = totalSignals > 0 ? 0.80 / totalSignals : 0;

      return {
        run_id:       run.run_id,
        market_date:  new Date(run.created_at).toISOString().split('T')[0],
        generated_at: run.created_at,
        trading_mode: run.run_mode,
        signals:      signals.map(s => ({
          symbol:        s.symbol,
          action:        'buy',
          target_weight: parseFloat(perSignal.toFixed(4)),
          asset_class:   assetClass(s.symbol),
        })),
      };
    }));

    res.json({ days, count: history.length, history, disclaimer: DISCLAIMER });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Failed to fetch signal history' });
  }
});

module.exports = router;
