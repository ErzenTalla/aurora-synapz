const express     = require('express');
const requireAuth = require('../middleware/auth');
const db          = require('../db/index');
const emailSvc    = require('../services/email');
const { allocateUnits, executeTrades } = require('../services/fund');

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
    await allocateUnits(userId, amount);

    const trades = await executeTrades(userId, amount);
    emailSvc.sendDepositConfirmation({ to: req.user.email, name: req.user.name, amount });
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
      await allocateUnits(userId, amount).catch(console.error);
      await executeTrades(userId, amount).catch(console.error);

      const { rows: [user] } = await db.query('SELECT name, email FROM users WHERE id = $1', [userId]).catch(() => ({ rows: [] }));
      if (user) emailSvc.sendDepositConfirmation({ to: user.email, name: user.name, amount });
    }
  }

  res.json({ received: true });
});

module.exports = router;
