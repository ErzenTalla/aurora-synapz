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

module.exports = {
  isConfigured,
  getAccount:          ()    => alpacaFetch('/account'),
  getPositions:        ()    => alpacaFetch('/positions'),
  getPortfolioHistory: (qs)  => alpacaFetch(`/account/portfolio/history${qs || ''}`),
  submitOrder:         (body) => alpacaFetch('/orders', { method: 'POST', body: JSON.stringify(body) }),
};
