const express     = require('express');
const requireAuth = require('../middleware/auth');
const db          = require('../db/index');
const alpaca      = require('../services/alpaca');

const router = express.Router();

function stripe() {
  const key = process.env.STRIPE_SECRET_KEY || '';
  if (!key || key === 'sk_test_placeholder') throw new Error('Stripe not configured — add STRIPE_SECRET_KEY to .env');
  return require('stripe')(key);
}

// GET /api/stripe/config — returns publishable key (safe to expose)
router.get('/config', requireAuth, (req, res) => {
  const pub = process.env.STRIPE_PUBLISHABLE_KEY || '';
  res.json({
    publishableKey: pub || 'pk_test_placeholder',
    configured: !!(pub && pub !== 'pk_test_placeholder'),
  });
});

// POST /api/stripe/create-payment-intent
router.post('/create-payment-intent', requireAuth, async (req, res) => {
  try {
    const s = stripe();
    const { amount } = req.body;
    if (!amount || isNaN(amount) || amount <= 0) {
      return res.status(400).json({ error: 'Invalid amount' });
    }

    const pi = await s.paymentIntents.create({
      amount:   Math.round(parseFloat(amount) * 100),
      currency: 'usd',
      metadata: { userId: String(req.user.id), amount: String(amount) },
    });

    res.json({ clientSecret: pi.client_secret });
  } catch (err) {
    console.error('Stripe create-payment-intent:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/stripe/confirm-deposit — called after client-side confirmation
router.post('/confirm-deposit', requireAuth, async (req, res) => {
  try {
    const s = stripe();
    const { paymentIntentId } = req.body;
    if (!paymentIntentId) return res.status(400).json({ error: 'paymentIntentId required' });

    const pi = await s.paymentIntents.retrieve(paymentIntentId);
    if (pi.status !== 'succeeded') {
      return res.status(400).json({ error: `Payment not completed (status: ${pi.status})` });
    }

    // Idempotency guard
    const { rows: existing } = await db.query(
      'SELECT id FROM stripe_payments WHERE stripe_payment_intent_id = $1', [paymentIntentId]
    );
    if (existing.length > 0) return res.json({ already_processed: true });

    const amount = pi.amount / 100;
    const userId = req.user.id;

    await db.query(
      `INSERT INTO stripe_payments (user_id, stripe_payment_intent_id, amount, status) VALUES ($1,$2,$3,'succeeded')`,
      [userId, paymentIntentId, amount]
    );
    await db.query(
      `INSERT INTO transactions (user_id, type, amount, note) VALUES ($1,'DEPOSIT',$2,$3)`,
      [userId, amount, `Stripe deposit`]
    );
    await db.query(
      `UPDATE portfolios SET cash_balance = cash_balance + $1, total_value = total_value + $1, updated_at = NOW() WHERE user_id = $2`,
      [amount, userId]
    );

    const trades = await executeTrades(userId, amount);
    res.json({ success: true, amount, trades });
  } catch (err) {
    console.error('Confirm deposit error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// POST /api/stripe/webhook — Stripe sends raw body; mounted with express.raw() in app.js
router.post('/webhook', async (req, res) => {
  let event;
  try {
    const s = stripe();
    const sig = req.headers['stripe-signature'];
    if (process.env.STRIPE_WEBHOOK_SECRET) {
      event = s.webhooks.constructEvent(req.body, sig, process.env.STRIPE_WEBHOOK_SECRET);
    } else {
      event = JSON.parse(req.body.toString());
    }
  } catch (err) {
    return res.status(400).send(`Webhook Error: ${err.message}`);
  }

  if (event.type === 'payment_intent.succeeded') {
    const pi     = event.data.object;
    const userId = parseInt(pi.metadata.userId, 10);
    const amount = pi.amount / 100;

    const { rows: existing } = await db.query(
      'SELECT id FROM stripe_payments WHERE stripe_payment_intent_id = $1', [pi.id]
    ).catch(() => ({ rows: [] }));

    if (!existing.length) {
      await db.query(
        `INSERT INTO stripe_payments (user_id, stripe_payment_intent_id, amount, status) VALUES ($1,$2,$3,'succeeded')`,
        [userId, pi.id, amount]
      ).catch(console.error);
      await db.query(
        `INSERT INTO transactions (user_id, type, amount, note) VALUES ($1,'DEPOSIT',$2,'Stripe deposit')`,
        [userId, amount]
      ).catch(console.error);
      await db.query(
        `UPDATE portfolios SET cash_balance = cash_balance + $1, total_value = total_value + $1, updated_at = NOW() WHERE user_id = $2`,
        [amount, userId]
      ).catch(console.error);
      await executeTrades(userId, amount).catch(console.error);
    }
  }

  res.json({ received: true });
});

// ── Alpaca auto-invest after deposit ──
const ALLOCATIONS = [
  { symbol: 'SPY', name: 'SPDR S&P 500 ETF',       pct: 0.40 },
  { symbol: 'BND', name: 'Vanguard Total Bond ETF', pct: 0.30 },
  { symbol: 'GLD', name: 'SPDR Gold Shares',         pct: 0.20 },
  // 10% stays as cash
];

async function executeTrades(userId, depositAmount) {
  const results = [];
  for (const alloc of ALLOCATIONS) {
    const notional = (depositAmount * alloc.pct).toFixed(2);
    try {
      const order = await alpaca.submitOrder({
        symbol: alloc.symbol,
        notional,
        side: 'buy',
        type: 'market',
        time_in_force: 'day',
      });
      await db.query(
        `INSERT INTO transactions (user_id, type, symbol, name, amount, note) VALUES ($1,'BUY',$2,$3,$4,'Auto-invest from deposit')`,
        [userId, alloc.symbol, alloc.name, parseFloat(notional)]
      );
      results.push({ symbol: alloc.symbol, notional, status: 'submitted', orderId: order.id });
    } catch (err) {
      console.error(`Trade ${alloc.symbol}:`, err.message);
      results.push({ symbol: alloc.symbol, notional, status: 'error', error: err.message });
    }
  }
  return results;
}

module.exports = router;
