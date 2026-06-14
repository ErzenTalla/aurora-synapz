require('dotenv').config({ path: require('path').join(__dirname, '..', '.env.local') });
const pool = require('./index');

async function seedAdmin() {
  const email = 'erzentalla1@gmail.com';

  const { rows: [user] } = await pool.query('SELECT id FROM users WHERE email = $1', [email]);
  if (!user) { console.error('Admin user not found'); process.exit(1); }
  const userId = user.id;

  // Clear any existing data for this user
  await pool.query('DELETE FROM performance_history WHERE user_id = $1', [userId]);
  await pool.query('DELETE FROM documents        WHERE user_id = $1', [userId]);
  await pool.query('DELETE FROM transactions     WHERE user_id = $1', [userId]);
  await pool.query('DELETE FROM holdings         WHERE user_id = $1', [userId]);
  await pool.query('DELETE FROM portfolios       WHERE user_id = $1', [userId]);

  // Portfolio
  await pool.query(
    `INSERT INTO portfolios (user_id, total_value, cash_balance, day_change, day_change_pct, ytd_return, ytd_return_pct, inception_date)
     VALUES ($1,$2,$3,$4,$5,$6,$7,$8)`,
    [userId, 2841640.00, 310000.00, 19240.75, 0.68, 327890.50, 13.02, '2021-03-10']
  );

  // Holdings
  const holdings = [
    ['AAPL',  'Apple Inc.',               'Equity',        1500, 185.42, 142.00,  1.23,  0.67],
    ['MSFT',  'Microsoft Corp.',          'Equity',         800, 419.76, 298.00,  3.40,  0.82],
    ['NVDA',  'NVIDIA Corp.',             'Equity',         500, 875.30, 460.00, 12.10,  1.40],
    ['AMZN',  'Amazon.com Inc.',          'Equity',         400, 192.30, 155.00,  1.80,  0.94],
    ['BRK.B', 'Berkshire Hathaway B',    'Equity',         600, 382.10, 330.00, -1.20, -0.31],
    ['JPM',   'JPMorgan Chase & Co.',    'Equity',        1000, 196.84, 148.00,  0.95,  0.49],
    ['BND',   'Vanguard Total Bond ETF', 'Fixed Income',  3000,  75.12,  79.00, -0.08, -0.11],
    ['VXUS',  'Vanguard Total Intl ETF', 'Fixed Income',  2000,  62.34,  56.00,  0.24,  0.39],
    ['GLD',   'SPDR Gold Shares',        'Alternative',    800, 194.50, 165.00,  2.10,  1.09],
    ['VNQ',   'Vanguard Real Estate ETF','Alternative',    900,  88.20,  92.00, -0.35, -0.40],
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
    ['BUY',      'NVDA',  'NVIDIA Corp.',              100,  862.00,  86200.00, null,                    '2026-06-10 09:32:00'],
    ['DIVIDEND', 'JPM',   'JPMorgan Chase & Co.',     null,    null,   1240.00, 'Q2 2026 dividend',      '2026-06-05 00:00:00'],
    ['BUY',      'AMZN',  'Amazon.com Inc.',           100,  185.40,  18540.00, 'Initiated new position','2026-05-30 10:20:00'],
    ['SELL',     'BND',   'Vanguard Total Bond ETF',   500,   75.40,  37700.00, 'Rebalance',             '2026-05-28 14:15:00'],
    ['BUY',      'GLD',   'SPDR Gold Shares',          200,  188.20,  37640.00, 'Inflation hedge add',   '2026-05-20 10:00:00'],
    ['DEPOSIT',  null,    null,                        null,    null,  100000.00,'Monthly contribution',  '2026-05-01 00:00:00'],
    ['BUY',      'MSFT',  'Microsoft Corp.',           100,  404.20,  40420.00, null,                    '2026-04-18 11:45:00'],
    ['DIVIDEND', 'AAPL',  'Apple Inc.',               null,    null,    480.00, 'Q1 2026 dividend',      '2026-04-15 00:00:00'],
    ['SELL',     'VNQ',   'Vanguard Real Estate ETF',  200,   90.10,  18020.00, 'Rebalance',             '2026-04-10 13:30:00'],
    ['DEPOSIT',  null,    null,                        null,    null,  100000.00,'Monthly contribution',  '2026-04-01 00:00:00'],
    ['BUY',      'BRK.B', 'Berkshire Hathaway B',      100,  370.00,  37000.00, null,                    '2026-03-25 09:00:00'],
    ['DEPOSIT',  null,    null,                        null,    null,  100000.00,'Monthly contribution',  '2026-03-01 00:00:00'],
  ];
  for (const [type, symbol, name, shares, price, amount, note, created_at] of transactions) {
    await pool.query(
      `INSERT INTO transactions (user_id,type,symbol,name,shares,price,amount,note,created_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9)`,
      [userId, type, symbol, name, shares, price, amount, note, created_at]
    );
  }

  // Performance history (365 days)
  let val = 2510000;
  const now = new Date('2026-06-12');
  for (let i = 365; i >= 0; i--) {
    const d = new Date(now);
    d.setDate(d.getDate() - i);
    if (d.getDay() === 0 || d.getDay() === 6) continue;
    val = val * (1 + 0.00035 + (Math.random() - 0.48) * 0.016);
    const dateStr = d.toISOString().split('T')[0];
    await pool.query(
      `INSERT INTO performance_history (user_id, date, value) VALUES ($1, $2, $3)`,
      [userId, dateStr, Math.round(val * 100) / 100]
    );
  }

  // Documents
  const documents = [
    ['Q1 2026 Account Statement',      'Statement', 'Q1 2026',  312, '2026-04-05'],
    ['Q4 2025 Account Statement',      'Statement', 'Q4 2025',  298, '2026-01-07'],
    ['2025 Tax Document (1099)',        'Tax',       'FY 2025',  445, '2026-02-15'],
    ['2025 Annual Performance Report', 'Report',    'FY 2025', 1024, '2026-01-20'],
    ['Investment Policy Statement',    'Agreement', 'Ongoing',  180, '2021-03-10'],
    ['Q3 2025 Account Statement',      'Statement', 'Q3 2025',  287, '2025-10-06'],
    ['Q2 2025 Account Statement',      'Statement', 'Q2 2025',  275, '2025-07-04'],
  ];
  for (const [title, type, period, size_kb, created_at] of documents) {
    await pool.query(
      `INSERT INTO documents (user_id,title,type,period,size_kb,created_at) VALUES ($1,$2,$3,$4,$5,$6)`,
      [userId, title, type, period, size_kb, created_at]
    );
  }

  console.log(`Portfolio data seeded for ${email}`);
  await pool.end();
}

seedAdmin().catch(e => { console.error(e); process.exit(1); });
