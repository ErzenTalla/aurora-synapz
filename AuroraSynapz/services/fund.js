const db     = require('../db/index');
const alpaca = require('./alpaca');

// ── Unit allocation on deposit ──
// Each deposit buys units in the pooled fund at the current unit price.
// Unit price = fund.total_value / fund.total_units (starts at $1.00).
async function allocateUnits(userId, amount) {
  const { rows: [fund] } = await db.query('SELECT * FROM fund WHERE id = 1');
  const unitPrice  = fund.total_units > 0 ? parseFloat(fund.total_value) / parseFloat(fund.total_units) : 1.0;
  const newUnits   = amount / unitPrice;
  const newFundValue = parseFloat(fund.total_value) + amount;
  const newFundUnits = parseFloat(fund.total_units) + newUnits;
  const newUnitPrice = newFundUnits > 0 ? newFundValue / newFundUnits : 1.0;

  await db.query(
    `UPDATE fund SET total_value=$1, total_units=$2, unit_price=$3, updated_at=NOW() WHERE id=1`,
    [newFundValue, newFundUnits, newUnitPrice]
  );
  await db.query(
    `UPDATE portfolios
     SET units_owned  = units_owned + $1,
         total_value  = (units_owned + $1) * $2,
         cash_balance = cash_balance + $3,
         updated_at   = NOW()
     WHERE user_id = $4`,
    [newUnits, newUnitPrice, amount, userId]
  );

  return { unitPrice: newUnitPrice, unitsAllocated: newUnits };
}

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

// ── Manual batched invest ──
// Buys the same 40/30/20 split against a lump sum of cash that's already
// sitting in the pooled Alpaca account (e.g. after a manual bank wire),
// not tied to a single client's deposit — no per-user transaction row.
async function investCash(amount) {
  const results = [];
  for (const alloc of ALLOCATIONS) {
    const notional = (amount * alloc.pct).toFixed(2);
    try {
      const order = await alpaca.submitOrder({
        symbol: alloc.symbol,
        notional,
        side: 'buy',
        type: 'market',
        time_in_force: 'day',
      });
      results.push({ symbol: alloc.symbol, notional, status: 'submitted', orderId: order.id });
    } catch (err) {
      console.error(`Invest ${alloc.symbol}:`, err.message);
      results.push({ symbol: alloc.symbol, notional, status: 'error', error: err.message });
    }
  }
  return results;
}

module.exports = { ALLOCATIONS, allocateUnits, executeTrades, investCash };
