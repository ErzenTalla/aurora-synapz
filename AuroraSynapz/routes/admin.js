const express      = require('express');
const bcrypt       = require('bcryptjs');
const requireAdmin = require('../middleware/requireAdmin');
const db           = require('../db/index');

const router = express.Router();
router.use(requireAdmin);

// ── Overview stats ──────────────────────────────────────────────
router.get('/stats', async (req, res) => {
  try {
    const [{ rows: [aum] }, { rows: [users] }, { rows: [contacts] }, { rows: [deposits] }] =
      await Promise.all([
        db.query('SELECT COALESCE(SUM(total_value),0) AS total_aum FROM portfolios'),
        db.query("SELECT COUNT(*) AS count FROM users WHERE role = 'client'"),
        db.query('SELECT COUNT(*) AS count FROM contacts'),
        db.query("SELECT COALESCE(SUM(amount),0) AS total FROM stripe_payments WHERE status = 'succeeded'"),
      ]);
    res.json({
      total_aum:      parseFloat(aum.total_aum),
      client_count:   parseInt(users.count),
      contact_count:  parseInt(contacts.count),
      total_deposits: parseFloat(deposits.total),
    });
  } catch (err) {
    console.error(err);
    res.status(500).json({ error: 'Server error' });
  }
});

// ── User list ────────────────────────────────────────────────────
router.get('/users', async (req, res) => {
  try {
    const { rows } = await db.query(`
      SELECT u.id, u.name, u.email, u.role, u.created_at,
             p.total_value, p.day_change_pct, p.updated_at AS last_sync
      FROM users u
      LEFT JOIN portfolios p ON p.user_id = u.id
      ORDER BY u.created_at DESC
    `);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Single user detail (portfolio + holdings + transactions) ─────
router.get('/users/:id', async (req, res) => {
  const uid = parseInt(req.params.id);
  try {
    const { rows: [user] } = await db.query(
      'SELECT id, name, email, role, created_at FROM users WHERE id = $1', [uid]
    );
    if (!user) return res.status(404).json({ error: 'User not found' });

    const [{ rows: [portfolio] }, { rows: holdings }, { rows: transactions }] =
      await Promise.all([
        db.query('SELECT * FROM portfolios WHERE user_id = $1', [uid]),
        db.query('SELECT * FROM holdings WHERE user_id = $1 ORDER BY shares * price DESC', [uid]),
        db.query('SELECT * FROM transactions WHERE user_id = $1 ORDER BY created_at DESC LIMIT 20', [uid]),
      ]);

    const enrichedHoldings = holdings.map(h => ({
      ...h,
      market_value:   parseFloat(h.shares) * parseFloat(h.price),
      total_gain:     parseFloat(h.shares) * (parseFloat(h.price) - parseFloat(h.avg_cost)),
      total_gain_pct: ((parseFloat(h.price) - parseFloat(h.avg_cost)) / parseFloat(h.avg_cost)) * 100,
    }));

    res.json({ user, portfolio, holdings: enrichedHoldings, transactions });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Create client ────────────────────────────────────────────────
router.post('/users', async (req, res) => {
  const { name, email, password, role = 'client' } = req.body;
  if (!name || !email || !password) {
    return res.status(400).json({ error: 'name, email and password are required' });
  }
  try {
    const hash = await bcrypt.hash(password, 12);
    const { rows: [user] } = await db.query(
      `INSERT INTO users (name, email, password, role)
       VALUES ($1, $2, $3, $4) RETURNING id, name, email, role, created_at`,
      [name, email.toLowerCase().trim(), hash, role]
    );
    res.status(201).json(user);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Email already in use' });
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Update user (name / email) ───────────────────────────────────
router.patch('/users/:id', async (req, res) => {
  const uid = parseInt(req.params.id);
  const { name, email } = req.body;
  if (!name && !email) return res.status(400).json({ error: 'Nothing to update' });
  try {
    const fields = [], vals = [];
    if (name)  { fields.push(`name = $${fields.length + 1}`);  vals.push(name); }
    if (email) { fields.push(`email = $${fields.length + 1}`); vals.push(email.toLowerCase().trim()); }
    vals.push(uid);
    const { rows: [user] } = await db.query(
      `UPDATE users SET ${fields.join(', ')} WHERE id = $${vals.length} RETURNING id, name, email, role`,
      vals
    );
    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json(user);
  } catch (err) {
    if (err.code === '23505') return res.status(409).json({ error: 'Email already in use' });
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Delete user (cascade) ────────────────────────────────────────
router.delete('/users/:id', async (req, res) => {
  const uid = parseInt(req.params.id);
  try {
    const { rows: [user] } = await db.query('SELECT role FROM users WHERE id = $1', [uid]);
    if (!user) return res.status(404).json({ error: 'User not found' });
    if (user.role === 'admin') return res.status(400).json({ error: 'Cannot delete an admin account' });

    await db.query('DELETE FROM performance_history WHERE user_id = $1', [uid]);
    await db.query('DELETE FROM documents           WHERE user_id = $1', [uid]);
    await db.query('DELETE FROM transactions        WHERE user_id = $1', [uid]);
    await db.query('DELETE FROM holdings            WHERE user_id = $1', [uid]);
    await db.query('DELETE FROM portfolios          WHERE user_id = $1', [uid]);
    await db.query('DELETE FROM alpaca_sync_log     WHERE user_id = $1', [uid]);
    await db.query('DELETE FROM stripe_payments     WHERE user_id = $1', [uid]);
    await db.query('DELETE FROM users               WHERE id      = $1', [uid]);

    res.json({ deleted: uid });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Contact submissions ──────────────────────────────────────────
router.get('/contacts', async (req, res) => {
  try {
    const { rows } = await db.query('SELECT * FROM contacts ORDER BY created_at DESC');
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Recent deposits ──────────────────────────────────────────────
router.get('/deposits', async (req, res) => {
  try {
    const { rows } = await db.query(`
      SELECT sp.*, u.name, u.email
      FROM stripe_payments sp
      JOIN users u ON u.id = sp.user_id
      ORDER BY sp.created_at DESC
      LIMIT 50
    `);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Withdrawal requests ──────────────────────────────────────────
router.get('/withdrawals', async (req, res) => {
  try {
    const { rows } = await db.query(`
      SELECT wr.*, u.name, u.email
      FROM withdrawal_requests wr
      JOIN users u ON u.id = wr.user_id
      ORDER BY wr.created_at DESC
    `);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

router.patch('/withdrawals/:id/status', async (req, res) => {
  const id     = parseInt(req.params.id);
  const status = req.body.status;
  const notes  = req.body.notes || null;

  if (!['approved', 'processed', 'rejected'].includes(status)) {
    return res.status(400).json({ error: 'Status must be approved, processed, or rejected' });
  }

  try {
    const { rows: [wr] } = await db.query('SELECT * FROM withdrawal_requests WHERE id = $1', [id]);
    if (!wr) return res.status(404).json({ error: 'Withdrawal not found' });
    if (wr.status === 'processed') return res.status(400).json({ error: 'Already processed' });

    // Rejecting: restore client units and fund balance
    if (status === 'rejected' && wr.status === 'pending') {
      const unitPrice = parseFloat(wr.unit_price);
      const amount    = parseFloat(wr.amount);
      const units     = parseFloat(wr.units_redeemed);

      await db.query(
        `UPDATE portfolios SET
           units_owned  = units_owned  + $1,
           total_value  = total_value  + $2,
           cash_balance = cash_balance + $2,
           updated_at   = NOW()
         WHERE user_id = $3`,
        [units, amount, wr.user_id]
      );
      await db.query(
        `UPDATE fund SET total_value = total_value + $1, total_units = total_units + $2, updated_at = NOW() WHERE id = 1`,
        [amount, units]
      );
      await db.query(
        `INSERT INTO transactions (user_id, type, amount, note) VALUES ($1, 'DEPOSIT', $2, $3)`,
        [wr.user_id, amount, `Withdrawal #${id} rejected — funds restored`]
      );
    }

    await db.query(
      `UPDATE withdrawal_requests SET status=$1, notes=$2, processed_at=NOW() WHERE id=$3`,
      [status, notes, id]
    );

    res.json({ success: true, id, status });
  } catch (err) {
    console.error('Update withdrawal error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

module.exports = router;
