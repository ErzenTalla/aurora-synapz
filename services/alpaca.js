const BASE = 'https://api.alpaca.markets';

function isConfigured() {
  const key = process.env.ALPACA_API_KEY || '';
  return key && key !== 'your_alpaca_api_key_here';
}

async function alpacaFetch(path, opts = {}) {
  const res = await fetch(`${BASE}${path}`, {
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
    throw new Error(`Alpaca ${res.status} on ${path}: ${text}`);
  }
  return res.json();
}

module.exports = {
  isConfigured,
  getAccount:        ()       => alpacaFetch('/v2/account'),
  getPositions:      ()       => alpacaFetch('/v2/positions'),
  getPortfolioHistory: (qs='') => alpacaFetch(`/v2/account/portfolio/history${qs}`),
  submitOrder: (body)          => alpacaFetch('/v2/orders', { method: 'POST', body: JSON.stringify(body) }),
};
