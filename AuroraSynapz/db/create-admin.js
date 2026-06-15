require('dotenv').config({ path: require('path').join(__dirname, '..', '.env.local') });
const bcrypt = require('bcryptjs');
const pool = require('./index');

async function createAdmin() {
  const name     = 'Erzen Talla';
  const email    = 'erzentalla1@gmail.com';
  const password = '12345678';
  const role     = 'admin';

  const hash = await bcrypt.hash(password, 12);

  // Remove existing account with this email if any (cascade dependents first)
  const { rows: [existing] } = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  if (existing) {
    const uid = existing.id;
    await pool.query('DELETE FROM performance_history WHERE user_id = $1', [uid]);
    await pool.query('DELETE FROM documents           WHERE user_id = $1', [uid]);
    await pool.query('DELETE FROM transactions        WHERE user_id = $1', [uid]);
    await pool.query('DELETE FROM holdings            WHERE user_id = $1', [uid]);
    await pool.query('DELETE FROM portfolios          WHERE user_id = $1', [uid]);
    await pool.query('DELETE FROM alpaca_sync_log     WHERE user_id = $1', [uid]);
    await pool.query('DELETE FROM stripe_payments     WHERE user_id = $1', [uid]);
    await pool.query('DELETE FROM users               WHERE id      = $1', [uid]);
  }

  const { rows } = await pool.query(
    `INSERT INTO users (name, email, password, role)
     VALUES ($1, $2, $3, $4) RETURNING id, name, email, role`,
    [name, email, hash, role]
  );

  console.log('Admin account created:', rows[0]);
  await pool.end();
}

createAdmin().catch(err => { console.error(err); process.exit(1); });
