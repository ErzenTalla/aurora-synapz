const express      = require('express');
const multer       = require('multer');
const bcrypt       = require('bcryptjs');
const requireAdmin = require('../middleware/requireAdmin');
const db           = require('../db/index');
const alpaca       = require('../services/alpaca');
const emailSvc     = require('../services/email');

const router = express.Router();
router.use(requireAdmin);

const upload = multer({
  storage: multer.memoryStorage(),
  limits: { fileSize: 10 * 1024 * 1024 }, // 10MB
  fileFilter: (req, file, cb) => {
    const allowed = ['application/pdf', 'image/png', 'image/jpeg'];
    if (!allowed.includes(file.mimetype)) return cb(new Error('Only PDF, PNG, or JPEG files are allowed'));
    cb(null, true);
  },
});

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
             p.total_value, p.day_change_pct, p.updated_at AS last_sync,
             p.fee_rate, p.last_fee_charged_at
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

// ── Documents ─────────────────────────────────────────────────

// GET /api/admin/documents — list all documents (newest first)
router.get('/documents', async (req, res) => {
  try {
    const { rows } = await db.query(`
      SELECT d.id, d.user_id, d.title, d.type, d.period, d.size_kb,
             d.filename, d.mime_type, d.created_at, u.name, u.email
      FROM documents d
      JOIN users u ON u.id = d.user_id
      ORDER BY d.created_at DESC
    `);
    res.json(rows);
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

// POST /api/admin/documents — upload a document for a client
router.post('/documents', upload.single('file'), async (req, res) => {
  const userId = parseInt(req.body.user_id);
  const { title, type, period } = req.body;

  if (!userId || !title || !type || !period) {
    return res.status(400).json({ error: 'user_id, title, type, and period are required' });
  }
  if (!req.file) return res.status(400).json({ error: 'A file is required' });

  try {
    const { rows: [user] } = await db.query('SELECT id FROM users WHERE id = $1', [userId]);
    if (!user) return res.status(404).json({ error: 'Client not found' });

    const sizeKb = Math.ceil(req.file.size / 1024);
    const { rows: [doc] } = await db.query(
      `INSERT INTO documents (user_id, title, type, period, size_kb, filename, mime_type, file_data, uploaded_by)
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9)
       RETURNING id, user_id, title, type, period, size_kb, filename, mime_type, created_at`,
      [userId, title, type, period, sizeKb, req.file.originalname, req.file.mimetype, req.file.buffer, req.user.id]
    );
    res.status(201).json(doc);
  } catch (err) {
    console.error('Document upload error:', err.message);
    res.status(500).json({ error: 'Server error' });
  }
});

// DELETE /api/admin/documents/:id
router.delete('/documents/:id', async (req, res) => {
  const id = parseInt(req.params.id);
  try {
    const { rows: [doc] } = await db.query('DELETE FROM documents WHERE id = $1 RETURNING id', [id]);
    if (!doc) return res.status(404).json({ error: 'Document not found' });
    res.json({ deleted: id });
  } catch (err) {
    res.status(500).json({ error: 'Server error' });
  }
});

// ── Fee management ──────────────────────────────────────────────

// Core fee collection logic — runs per client, redeems units at current price
async function collectFees(dryRun = false) {
  const { rows: [fund] } = await db.query('SELECT * FROM fund WHERE id = 1');
  const unitPrice  = parseFloat(fund.unit_price);
  const totalUnits = parseFloat(fund.total_units);
  if (totalUnits <= 0) return { collected: 0, clients: [] };

  const { rows: clients } = await db.query(
    `SELECT p.*, u.name, u.email FROM portfolios p JOIN users u ON u.id = p.user_id
     WHERE p.units_owned > 0 AND u.role = 'client'`
  );

  const results = [];
  let totalFeeCollected = 0;

  for (const client of clients) {
    const totalValue  = parseFloat(client.total_value);
    const feeRate     = parseFloat(client.fee_rate);     // annual rate e.g. 0.015
    const monthlyRate = feeRate / 12;
    const feeAmount   = totalValue * monthlyRate;
    if (feeAmount < 0.01) continue;

    const feeUnits    = feeAmount / unitPrice;
    results.push({ userId: client.user_id, name: client.name, email: client.email, feeAmount, feeRate, totalValue });

    if (!dryRun) {
      const cashDeduct = Math.min(feeAmount, parseFloat(client.cash_balance));
      await db.query(
        `UPDATE portfolios SET
           units_owned         = units_owned         - $1,
           total_value         = total_value         - $2,
           cash_balance        = cash_balance        - $3,
           last_fee_charged_at = NOW(),
           updated_at          = NOW()
         WHERE user_id = $4`,
        [feeUnits, feeAmount, cashDeduct, client.user_id]
      );
      await db.query(
        `INSERT INTO transactions (user_id, type, amount, note) VALUES ($1, 'FEE', $2, $3)`,
        [client.user_id, feeAmount, `Monthly management fee (${(feeRate * 100).toFixed(2)}% p.a.)`]
      );
      emailSvc.sendFeeNotice({ to: client.email, name: client.name, amount: feeAmount, feeRate });
      totalFeeCollected += feeAmount;
    }
  }

  if (!dryRun && totalFeeCollected > 0) {
    const totalFeeUnits = totalFeeCollected / unitPrice;
    await db.query(
      `UPDATE fund SET total_value = total_value - $1, total_units = total_units - $2, updated_at = NOW() WHERE id = 1`,
      [totalFeeCollected, totalFeeUnits]
    );
  }

  return { collected: totalFeeCollected, clients: results };
}

// GET /api/admin/fee/preview — show upcoming fees without collecting
router.get('/fee/preview', async (req, res) => {
  try {
    const result = await collectFees(true);
    res.json(result);
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// POST /api/admin/fee/collect — manually collect fees now
router.post('/fee/collect', async (req, res) => {
  try {
    const result = await collectFees(false);
    res.json({ success: true, ...result });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// GET /api/admin/fee/cron-collect — monthly cron (no user auth, optional CRON_SECRET)
router.get('/fee/cron-collect', async (req, res) => {
  const cronSecret = process.env.CRON_SECRET || '';
  if (cronSecret) {
    const auth = req.headers.authorization || '';
    if (auth !== `Bearer ${cronSecret}`) return res.status(401).json({ error: 'Unauthorized' });
  }
  try {
    const result = await collectFees(false);
    res.json({ success: true, ...result, collected_at: new Date().toISOString() });
  } catch (err) {
    res.status(500).json({ error: err.message });
  }
});

// PATCH /api/admin/users/:id/fee-rate — set a custom fee rate for a client
router.patch('/users/:id/fee-rate', async (req, res) => {
  const uid     = parseInt(req.params.id);
  const feeRate = parseFloat(req.body.fee_rate);
  if (isNaN(feeRate) || feeRate < 0 || feeRate > 0.10) {
    return res.status(400).json({ error: 'Fee rate must be between 0% and 10%' });
  }
  try {
    await db.query('UPDATE portfolios SET fee_rate = $1 WHERE user_id = $2', [feeRate, uid]);
    res.json({ success: true, user_id: uid, fee_rate: feeRate });
  } catch (err) {
    res.status(500).json({ error: err.message });
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
    const { rows: [wr] } = await db.query(
      `SELECT wr.*, u.name, u.email FROM withdrawal_requests wr
       JOIN users u ON u.id = wr.user_id WHERE wr.id = $1`, [id]
    );
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

    emailSvc.sendWithdrawalStatus({ to: wr.email, name: wr.name, amount: wr.amount, withdrawalId: id, status });
    res.json({ success: true, id, status });
  } catch (err) {
    console.error('Update withdrawal error:', err.message);
    res.status(500).json({ error: err.message });
  }
});

// Multer errors (oversized file, wrong type) land here instead of crashing
router.use((err, req, res, next) => {
  if (err instanceof multer.MulterError || err.message?.includes('Only PDF')) {
    return res.status(400).json({ error: err.message });
  }
  next(err);
});

module.exports = router;
