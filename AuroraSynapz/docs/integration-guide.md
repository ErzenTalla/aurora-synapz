# AuroraSynapz Signal API — Integration Guide

**Version:** 1.0 | **Base URL:** `https://aurorasyanapz.com` | **OpenAPI spec:** `docs/openapi.yaml`

---

## Overview

The Signal API exposes three endpoints that deliver Simons-generated portfolio rebalancing signals. Signals are produced once per trading day (Mon–Fri) by the Simons strategy cron job, which runs at approximately 19:45 UTC. Weekends and market holidays produce no new runs.

---

## Authentication

All endpoints except `/status` require an `X-API-Key` header.

```http
X-API-Key: your-api-key-here
```

Keys are provisioned by the AlpineTech admin via the AuroraSynapz admin UI (`/admin`). Contact AlpineTech to request access.

**How it works internally:** The server hashes your key with SHA-256 before comparing it to the stored hash. You pass the raw key; the server never stores it in plaintext.

### Error responses

| HTTP | Code | Meaning |
|------|------|---------|
| 401 | `NO_KEY` | `X-API-Key` header missing |
| 401 | `INVALID_KEY` | Key not found in the database |
| 403 | `KEY_REVOKED` | Key exists but has been deactivated |

---

## Rate Limits

Each API key is limited to **10 calls per day** (rolling calendar day, resets at midnight UTC).

When the limit is exceeded, the server returns HTTP `429` with:
- A `Retry-After` header: seconds until the counter resets
- A `resets_at` field in the body: ISO 8601 timestamp of the next reset

```http
HTTP/1.1 429 Too Many Requests
Retry-After: 9600

{
  "error": "Rate limit exceeded. Maximum 10 calls per day.",
  "code": "RATE_LIMIT_EXCEEDED",
  "retry_after": 9600,
  "resets_at": "2026-09-13T00:00:00.000Z"
}
```

**Tip:** The `/status` endpoint is public and does not count against your limit. Use it for health checks or polling.

---

## Endpoints

### 1. `GET /api/v1/signals/status` — Health check (no auth)

Returns engine status: last run ID, timestamp, trading mode, and circuit-breaker state.

**Request:**
```http
GET /api/v1/signals/status HTTP/1.1
Host: aurorasyanapz.com
```

**Response (200):**
```json
{
  "status": "ok",
  "last_run_id": "run-2026-09-12-001",
  "last_run_at": "2026-09-12T19:45:03.221Z",
  "trading_mode": "paper",
  "circuit_breaker": false
}
```

| Field | Type | Description |
|-------|------|-------------|
| `status` | string | Always `"ok"` if the service is up |
| `last_run_id` | string \| null | Unique ID of the most recent cron run; null if no run has occurred |
| `last_run_at` | ISO 8601 \| null | Timestamp of the most recent run |
| `trading_mode` | `"paper"` \| `"live"` \| null | Whether Simons is executing in paper or live brokerage mode |
| `circuit_breaker` | boolean | `true` means all signals are suppressed (see below) |

---

### 2. `GET /api/v1/signals/latest` — Most recent signal set

Returns the full signal payload from the latest cron run. Responses are cached in memory per `run_id` — calling this endpoint multiple times on the same day is efficient.

**Request:**
```http
GET /api/v1/signals/latest HTTP/1.1
Host: aurorasyanapz.com
X-API-Key: your-api-key-here
```

**Response (200):**
```json
{
  "run_id": "run-2026-09-12-001",
  "generated_at": "2026-09-12T19:45:03.221Z",
  "market_date": "2026-09-12",
  "trading_mode": "paper",
  "defensive_posture": false,
  "circuit_breaker": false,
  "signals": [
    {
      "symbol": "SPY",
      "action": "buy",
      "target_weight": 0.2667,
      "asset_class": "etf"
    },
    {
      "symbol": "QQQ",
      "action": "buy",
      "target_weight": 0.2667,
      "asset_class": "etf"
    },
    {
      "symbol": "AAPL",
      "action": "buy",
      "target_weight": 0.2667,
      "asset_class": "equity"
    }
  ],
  "cash_weight": 0.2,
  "disclaimer": "For informational purposes only. Not investment advice. Past performance does not guarantee future results."
}
```

| Field | Type | Description |
|-------|------|-------------|
| `run_id` | string | Unique run identifier |
| `generated_at` | ISO 8601 | When the cron job completed |
| `market_date` | date | Trading date these signals apply to |
| `trading_mode` | `"paper"` \| `"live"` | Brokerage execution mode |
| `defensive_posture` | boolean | `true` when BND is selected and SPY is not — risk-off allocation |
| `circuit_breaker` | boolean | `true` means all signals are suppressed; `signals` will be empty and `cash_weight` will be `1.0` |
| `signals` | array | Ordered list of selected assets; empty when circuit breaker is active |
| `signals[].symbol` | string | Ticker (e.g. `SPY`, `AAPL`) |
| `signals[].action` | `"buy"` | Always buy — Simons is long-only |
| `signals[].target_weight` | float | Fraction of portfolio to allocate (equity total = 0.80, split equally) |
| `signals[].asset_class` | `"etf"` \| `"equity"` | ETFs: SPY, QQQ, VTI, BND, GLD; all others are equity |
| `cash_weight` | float | Remaining allocation held as cash (normally `0.20`; `1.0` when circuit breaker active) |

**404 — No signals yet:**
```json
{ "error": "No signals available yet", "code": "NO_SIGNALS" }
```

This occurs when no cron runs have completed since the database was initialised.

---

### 3. `GET /api/v1/signals/history?days=N` — Historical signal sets

Returns one signal set per trading day for the past `days` calendar days. Days without a completed cron run (weekends, holidays) are absent from the response.

**Request:**
```http
GET /api/v1/signals/history?days=30 HTTP/1.1
Host: aurorasyanapz.com
X-API-Key: your-api-key-here
```

**Query parameters:**

| Parameter | Type | Default | Max | Description |
|-----------|------|---------|-----|-------------|
| `days` | integer | `7` | `90` | Look-back window in calendar days |

**Response (200):**
```json
{
  "days": 30,
  "count": 21,
  "history": [
    {
      "run_id": "run-2026-09-12-001",
      "market_date": "2026-09-12",
      "generated_at": "2026-09-12T19:45:03.221Z",
      "trading_mode": "paper",
      "signals": [
        {
          "symbol": "SPY",
          "action": "buy",
          "target_weight": 0.2667,
          "asset_class": "etf"
        }
      ]
    }
  ],
  "disclaimer": "For informational purposes only. Not investment advice. Past performance does not guarantee future results."
}
```

Note: history entries do not include `defensive_posture`, `circuit_breaker`, or `cash_weight` — use `/latest` for the full current payload.

---

## Understanding Signals

### Weight allocation model

Simons selects between 1 and N assets per run. The portfolio is always structured as:
- **80% equity** — split equally across all selected signals
- **20% cash** — held as a buffer

Example: if 3 assets are selected, each gets `0.80 / 3 ≈ 0.2667` target weight.

### Circuit breaker

When the circuit breaker is active (a volatility safety mechanism), `/latest` returns `signals: []` and `cash_weight: 1.0`. The portfolio should move entirely to cash. Monitor the `circuit_breaker` field before executing any rebalance.

### Defensive posture

`defensive_posture: true` indicates Simons has selected BND (bond ETF) without SPY (S&P 500) — a risk-off signal. This is informational; the weight model remains the same.

### Trading mode

`trading_mode: "paper"` means Simons is running against a paper brokerage account. Signals are still generated and valid, but live execution has not been enabled by the operator. `trading_mode: "live"` means Simons is executing real trades.

---

## Error Reference

| HTTP | Code | Description |
|------|------|-------------|
| 401 | `NO_KEY` | `X-API-Key` header missing |
| 401 | `INVALID_KEY` | Key not recognised |
| 403 | `KEY_REVOKED` | Key deactivated by admin |
| 404 | `NO_SIGNALS` | No cron runs have completed yet |
| 429 | `RATE_LIMIT_EXCEEDED` | 10 calls/day limit hit; see `Retry-After` header |
| 500 | — | Internal server error; retry after a short delay |

---

## FAQ

**Q: How do I get an API key?**
Contact AlpineTech (erzentalla1@gmail.com). Keys are provisioned via the admin UI and can be revoked at any time.

**Q: How often do signals update?**
Once per trading day, Mon–Fri, at approximately 19:45 UTC. There are no updates on weekends or market holidays.

**Q: Can I poll `/latest` multiple times during the day?**
Yes — responses are cached in memory per `run_id`. Repeated calls within the same trading day return the same payload and do not trigger new database queries. However, each call still counts against your 10-call daily limit.

**Q: What if `/latest` returns a 404?**
The system has not yet completed its first cron run. This will resolve automatically after the next trading day at ~19:45 UTC.

**Q: What do I do when I get a 429?**
Read the `Retry-After` header (seconds) or the `resets_at` field (UTC timestamp) and wait until then. The counter resets at midnight UTC every day.

**Q: Why is `signals` empty on `/latest`?**
The circuit breaker is active (`circuit_breaker: true`). The system has detected elevated volatility and is holding 100% cash. Wait for the next run — the circuit breaker is evaluated fresh each cron cycle.

**Q: Is `trading_mode` guaranteed to be stable?**
No. The operator can switch between paper and live mode at any time via environment variables. Always check `trading_mode` in each response.

---

*Generated by AlpineTech crew automation — 2026-09-13*
