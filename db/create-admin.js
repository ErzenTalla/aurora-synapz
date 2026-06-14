require('dotenv').config({ path: require('path').join(__dirname, '..', '.env.local') });
const bcrypt = require('bcryptjs');
const pool = require('./index');

async function createAdmin() {
  const name     = 'Erzen Talla';
  const email    = 'erzentalla1@gmail.com';
  const password = '12345678';
  const role     = 'admin';

  const hash = await bcrypt.hash(password, 12);

  // Remove existing account with this email if any
  await pool.query('DELETE FROM users WHERE email = $1', [email]);

  const { rows } = await pool.query(
    `INSERT INTO users (name, email, password, role)
     VALUES ($1, $2, $3, $4) RETURNING id, name, email, role`,
    [name, email, hash, role]
  );

  console.log('Admin account created:', rows[0]);
  await pool.end();
}

createAdmin().catch(err => { console.error(err); process.exit(1); });
