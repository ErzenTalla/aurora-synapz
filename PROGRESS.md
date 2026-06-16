# ClaudeInfrastructure — Progress Tracker

Living document covering all active projects. Updated after each work session.

---

## Aurora Synapz (investment platform)

Live at: https://aurorasyanapz.com

**Architecture:** Single pooled Alpaca brokerage account, unit-based fund accounting (mutual-fund style). Each client owns `units_owned`; `unit_price = fund.total_value / fund.total_units`; client value = `units_owned × unit_price`. Deposits buy units, withdrawals and monthly fees redeem units — all symmetric operations keeping `fund` and `portfolios` consistent.

### Build order

| Step | Item | Status |
|---|---|---|
| 1 | Multi-client isolation (unit-based fund model) | ✅ Done |
| 2 | Withdrawal flow (client request → Alpaca proportional sell → admin approve/reject) | ✅ Done |
| 3 | Management fee mechanism (monthly, per-client rate, cron-collected) | ✅ Done |
| 4 | Admin document upload (for client docs/statements) | ⏳ Next |
| 5 | Email notifications (deposits, withdrawals, fees) | ⏳ Pending |
| 6 | Real Stripe live keys | 🚧 Blocked — waiting on user's Stripe account approval |
| 7 | Live Alpaca account funding | 🚧 Blocked — waiting on user's Alpaca account approval |

### Also fixed along the way
- Vercel cron for nightly Alpaca sync was silently 404'ing (POST route vs GET-only cron) — fixed, now `GET /api/alpaca/cron-sync`.
- Added second cron for monthly fee collection (`GET /api/admin/fee/cron-collect`, 1st of month).
- Cleaned up demo/seed data (`demo@aurorasyanapz.com`) that had leaked fake value into real fund totals.

### Blocked on user / external
- **Stripe live keys** — pending account document approval.
- **Alpaca live account** — pending account document approval.
- **Kosovo regulatory/legal (BQK)** — user consulting separately with legal/financial advisor; gates real-money operation, no code action pending.

### Not yet built (known gaps beyond the step list)
- Email notifications (Step 5).
- Admin document upload (Step 4).

---

## AlpineTech Website

Local workbench: `alpinetechwebsite-workbench/` (not yet a git-tracked subfolder of this repo's commits — separate repo).

### Status
- PR #1 (full backend, client portal, admin panel) — **merged** into `main` (2026-06-15), followed by a direct fix commit `aa72c64` restoring static Vercel deployment.
- PR #2 open: https://github.com/ErzenTalla/alpinetechwebsite/pull/2 — "Add Neon contact intake readiness" (opened 2026-06-16). Postgres/Neon-backed contact form scaffold behind fail-closed feature flags; explicitly review-only, does not activate production contact collection, portal/auth, or payments.
- Local workbench branch `feature/backend-portal` has an unstaged `package-lock.json` change sitting uncommitted.

### Known pending items
- Stripe keys needed for real payment testing.
- If deploying to Vercel: current DB is SQLite, which doesn't persist on Vercel's serverless filesystem — needs migration to a hosted DB (Turso, Neon, or Supabase) before production deploy.

---

## Omnia OS & Aurora (new project — started 2026-06-16)

Working folder: `OmniaAurora/`. Vision: Aurora = conversational companion/chief-of-staff; Omnia OS = the platform/engine behind it (User → Aurora → Omnia OS → execution). Full vision docs in `OmniaAurora/vision/`.

### Approach
Deliberately staged "baby steps" MVP — prove the daily-briefing loop manually before building any app or platform. No agent delegation, no write actions yet.

| Step | Item | Status |
|---|---|---|
| 0 | Define scope + question list | ✅ Done |
| 1 | Manual daily briefing (chat-based) | ✅ Done once (2026-06-16) |
| 2 | Tighten format/voice | ⏳ Ongoing, informal |
| 3 | Automate one context source | 🟡 In progress — see below |
| 4 | Checkpoint: did this earn a real interface? | ⏳ Pending |
| 5 | First iPhone app (read-only) | ⏳ Pending |
| 6 | First confirmed write action | ⏳ Pending |

### Personal context profile
Built out in `OmniaAurora/context/profile.md` through a guided discovery conversation. Key findings: motivated by building durable systems/frameworks that outlive direct involvement (not ownership/company size); system-building is intrinsically motivating, pure execution is neutral (not draining); real costs already being paid for this work — family time, sleep, some money — these are the things to protect going forward. Status/recognition as a motivator is still untested.

### Tooling — `aurora-cli`
Built `OmniaAurora/aurora-cli/` — a small Node CLI (`npm run brief`) that asks the same 6 daily-context questions, combines them with the permanent profile, calls the Claude API to generate the Daily Executive Briefing, and saves it to `OmniaAurora/daily-briefings/YYYY-MM-DD.md` automatically.

**Where we left off:** code is written and `npm install` succeeded; tool correctly fails with a clear error when no API key is set (verified). **Blocked on the user obtaining an Anthropic Console API key** (console.anthropic.com → Settings → API Keys — separate product/billing from the Claude Desktop app/Pro subscription). Once the key is in `OmniaAurora/aurora-cli/.env`, next step is to actually run `npm run brief` together and validate the first automated briefing.

### Daily briefings log
`OmniaAurora/daily-briefings/` — one logged so far (2026-06-16, done manually before the CLI existed).

---

## How to use this doc
Read it any time to check overall status. It will be updated after each future work session on any project — new steps marked done, new blockers added, new pending items appended.
