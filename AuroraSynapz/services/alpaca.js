function base() {
  return (process.env.ALPACA_ENDPOINT || 'https://api.alpaca.markets/v2').replace(/\/$/, '');
}

function isConfigured() {
  const key = process.env.ALPACA_API_KEY || '';
  return !!(key && key !== 'your_alpaca_api_key_here');
}

async function alpacaFetch(path, opts = {}) {
  const url = `${base()}${path}`;
  const res = await fetch(url, {
    ...opts,
    headers: {
      'APCA-API-KEY-ID':     process.env.ALPACA_API_KEY || '',
      'APCA-API-SECRET-KEY': process.env.ALPACA_SECRET_KEY || '',
      'Content-Type': 'application/json',
      ...(opts.headers || {}),
    },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Alpaca ${res.status} [${path}]: ${text}`);
  }
  return res.json();
}

// ── Market data (Alpaca Market Data API v2) ──────────────────────
// Read-only signal sources for Simons Phase 1 (Board-approved 2026-06-29).
// Data API base differs from the trading API base — always use
// data.alpaca.markets regardless of ALPACA_ENDPOINT (paper/live).
function dataBase() {
  return 'https://data.alpaca.markets/v2';
}

async function alpacaDataFetch(path) {
  const url = `${dataBase()}${path}`;
  const res = await fetch(url, {
    headers: {
      'APCA-API-KEY-ID':     process.env.ALPACA_API_KEY || '',
      'APCA-API-SECRET-KEY': process.env.ALPACA_SECRET_KEY || '',
    },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Alpaca Data ${res.status} [${path}]: ${text}`);
  }
  return res.json();
}


// ── Paper account (Simons Phase 2 — Board approval 2026-07-28) ──────────────
// Uses separate ALPACA_PAPER_KEY / ALPACA_PAPER_SECRET env vars.
// Paper endpoint is always paper-api.alpaca.markets — never the live endpoint.
function paperBase() {
  return 'https://paper-api.alpaca.markets/v2';
}

function isPaperConfigured() {
  const key = process.env.ALPACA_PAPER_KEY || '';
  return !!key;
}

async function paperFetch(path, opts = {}) {
  const url = `${paperBase()}${path}`;
  const res = await fetch(url, {
    ...opts,
    headers: {
      'APCA-API-KEY-ID':     process.env.ALPACA_PAPER_KEY    || '',
      'APCA-API-SECRET-KEY': process.env.ALPACA_PAPER_SECRET || '',
      'Content-Type': 'application/json',
      ...(opts.headers || {}),
    },
  });
  if (!res.ok) {
    const text = await res.text();
    throw new Error(`Alpaca Paper ${res.status} [${path}]: ${text}`);
  }
  return res.json();
}

module.exports = {
  isConfigured,
  isPaperConfigured,
  getAccount:          ()      => alpacaFetch('/account'),
  getPositions:        ()      => alpacaFetch('/positions'),
  getPortfolioHistory: (qs)    => alpacaFetch(`/account/portfolio/history${qs || ''}`),
  submitOrder:         (body)  => alpacaFetch('/orders', { method: 'POST', body: JSON.stringify(body) }),
  // Paper account (Phase 2)
  getPaperAccount:     ()      => paperFetch('/account'),
  getPaperPositions:   ()      => paperFetch('/positions'),
  getPaperOrders:      (qs)    => paperFetch(`/orders${qs || ''}`),
  submitPaperOrder:    (body)  => paperFetch('/orders', { method: 'POST', body: JSON.stringify(body) }),
  cancelPaperOrder:    (id)    => paperFetch(`/orders/${id}`, { method: 'DELETE' }),
  // Read-only market data wrappers (shared between dry-run and paper mode)
  getBars:             (symbol, qs) => alpacaDataFetch(`/stocks/${symbol}/bars${qs || ''}`),
  getLatestQuote:      (symbol)     => alpacaDataFetch(`/stocks/${symbol}/quotes/latest`),
};
