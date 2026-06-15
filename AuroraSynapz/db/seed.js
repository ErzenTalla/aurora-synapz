require('dotenv').config({ path: require('path').join(__dirname, '..', '.env') });
const bcrypt = require('bcryptjs');
const pool   = require('./index');
const setup  = require('./setup');

async function seed() {
  await setup();

  // Clear demo data
  await pool.query(`DELETE FROM performance_history WHERE user_id IN (SELECT id FROM users WHERE email = 'demo@aurorasyanapz.com')`);
  await pool.query(`DELETE FROM documents        WHERE user_id IN (SELECT id FROM users WHERE email = 'demo@aurorasyanapz.com')`);
  await pool.query(`DELETE FROM transactions     WHERE user_id IN (SELECT id FROM users WHERE email = 'demo@aurorasyanapz.com')`);
  await pool.query(`DELETE FROM holdings         WHERE user_id IN (SELECT id FROM users WHERE email = 'demo@aurorasyanapz.com')`);
  await pool.query(`DELETE FROM portfolios       WHERE user_id IN (SELECT id FROM users WHERE email = 'demo@aurorasyanapz.com')`);
  await pool.query(`DELETE FROM users            WHERE email = 'demo@aurorasyanapz.com'`);

  // Demo user
  const hash = bcrypt.hashSync('Demo1234!', 10);
  const { rows: [{ id: userId }] } = await pool.query(
    `INSERT INTO users (name, email, password, role) VALUES ($1, $2, $3, $4) RETURNING id`,
    ['James Hartwell', 'demo@aurorasyanapz.com', hash, 'client']
  );

  // Portfolio
  await pool.query(
    `INSERT INTO portfolios (user_id, total_value, cash_balance, day_change, day_change_pct, ytd_return, ytd_return_pct, inception_date)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
    [userId, 1247830.54, 198400.00, 8423.17, 0.68, 142380.20, 12.87, '2022-01-15']
  );

  // Holdings
  const holdings = [
    ['AAPL',  'Apple Inc.',               'Equity',        800,  185.42, 148.20,  1.23,  0.67],
    ['MSFT',  'Microsoft Corp.',          'Equity',        400,  419.76, 310.50,  3.40,  0.82],
    ['NVDA',  'NVIDIA Corp.',             'Equity',        200,  875.30, 480.00, 12.10,  1.40],
    ['BRK.B', 'Berkshire Hathaway B',    'Equity',        300,  382.10, 340.00, -1.20, -0.31],
    ['JPM',   'JPMorgan Chase & Co.',    'Equity',        500,  196.84, 155.00,  0.95,  0.49],
    ['BND',   'Vanguard Total Bond ETF', 'Fixed Income', 1500,   75.12,  78.40, -0.08, -0.11],
    ['VXUS',  'Vanguard Total Intl ETF', 'Fixed Income', 1000,   62.34,  58.20,  0.24,  0.39],
    ['GLD',   'SPDR Gold Shares',        'Alternative',   400,  194.50, 172.00,  2.10,  1.09],
    ['VNQ',   'Vanguard Real Estate ETF','Alternative',   500,   88.20,  95.40, -0.35, -0.40],
  ];
  for (const [symbol, name, asset_class, shares, price, avg_cost, day_change, day_chg_pct] of holdings) {
    await pool.query(
      `INSERT INTO holdings (user_id,symbol,name,asset_class,shares,price,avg_cost,day_change,day_chg_pct)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [userId, symbol, name, asset_class, shares, price, avg_cost, day_change, day_chg_pct]
    );
  }

  // Transactions
  const transactions = [
    ['BUY',      'NVDA',  'NVIDIA Corp.',              50,   862.00,  43100.00, null,                  '2026-06-10 09:32:00'],
    ['DIVIDEND', 'JPM',   'JPMorgan Chase & Co.',     null,    null,    487.50, 'Q2 2026 dividend',    '2026-06-05 00:00:00'],
    ['SELL',     'BND',   'Vanguard Total Bond ETF',  200,    75.40,  15080.00, 'Rebalance',           '2026-05-28 14:15:00'],
    ['BUY',      'GLD',   'SPDR Gold Shares',         100,   188.20,  18820.00, 'Inflation hedge add', '2026-05-20 10:00:00'],
    ['DEPOSIT',  null,    null,                       null,    null,   50000.00, 'Monthly contribution','2026-05-01 00:00:00'],
    ['BUY',      'MSFT',  'Microsoft Corp.',           50,   404.20,  20210.00, null,                  '2026-04-18 11:45:00'],
    ['DIVIDEND', 'AAPL',  'Apple Inc.',               null,    null,    192.00, 'Q1 2026 dividend',    '2026-04-15 00:00:00'],
    ['SELL',     'VNQ',   'Vanguard Real Estate ETF', 100,    90.10,   9010.00, 'Rebalance',           '2026-04-10 13:30:00'],
    ['BUY',      'BRK.B', 'Berkshire Hathaway B',      50,   370.00,  18500.00, null,                  '2026-03-25 09:00:00'],
    ['DEPOSIT',  null,    null,                       null,    null,   50000.00, 'Monthly contribution','2026-03-01 00:00:00'],
  ];
  for (const [type, symbol, name, shares, price, amount, note, created_at] of transactions) {
    await pool.query(
      `INSERT INTO transactions (user_id,type,symbol,name,shares,price,amount,note,created_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [userId, type, symbol, name, shares, price, amount, note, created_at]
    );
  }

  // Performance history (365 weekdays)
  let val = 1105000;
  const now = new Date('2026-06-12');
  for (let i = 365; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    if (d.getDay() === 0 || d.getDay() === 6) continue;
    val = val * (1 + 0.0003 + (Math.random() - 0.5) * 0.016);
    const dateStr = d.toISOString().split('T')[0];
    await pool.query(
      `INSERT INTO performance_history (user_id, date, value) VALUES ($1, $2, $3)`,
      [userId, dateStr, Math.round(val * 100) / 100]
    );
  }

  // Documents
  const documents = [
    ['Q1 2026 Account Statement',     'Statement', 'Q1 2026',  248, '2026-04-05'],
    ['Q4 2025 Account Statement',     'Statement', 'Q4 2025',  231, '2026-01-07'],
    ['2025 Tax Document (1099)',       'Tax',       'FY 2025',  312, '2026-02-15'],
    ['2025 Annual Performance Report', 'Report',    'FY 2025',  890, '2026-01-20'],
    ['Investment Policy Statement',   'Agreement', 'Ongoing',  156, '2022-01-15'],
    ['Q3 2025 Account Statement',     'Statement', 'Q3 2025',  219, '2025-10-06'],
  ];
  for (const [title, type, period, size_kb, created_at] of documents) {
    await pool.query(
      `INSERT INTO documents (user_id,title,type,period,size_kb,created_at) VALUES ($1,$2,$3,$4,$5,$6)`,
      [userId, title, type, period, size_kb, created_at]
    );
  }

  console.log('Database seeded.');
  console.log('  Demo login: demo@aurorasyanapz.com / Demo1234!');
  await pool.end();
}

seed().catch(e => { console.error(e); process.exit(1); });
