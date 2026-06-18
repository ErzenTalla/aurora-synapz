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
| 4 | Admin document upload (for client docs/statements) | ✅ Done |
| 5 | Email notifications (deposits, withdrawals, fees) | ✅ Done |
| 6 | Real Stripe live keys | 🚧 Blocked — Stripe account approved, but paused on Kosovo payout problem (see below) |
| 7 | Live Alpaca account funding | 🚧 Blocked — waiting on user's Alpaca account approval |

### Also fixed along the way
- Vercel cron for nightly Alpaca sync was silently 404'ing (POST route vs GET-only cron) — fixed, now `GET /api/alpaca/cron-sync`.
- Added second cron for monthly fee collection (`GET /api/admin/fee/cron-collect`, 1st of month).
- Cleaned up demo/seed data (`demo@aurorasyanapz.com`) that had leaked fake value into real fund totals.
- Document uploads stored as `BYTEA` directly in Postgres (no separate blob storage needed) — admin uploads PDF/PNG/JPEG (max 10MB) per client via `/api/admin/documents`; clients download only their own files via `/api/portal/documents/:id/download` (404 on cross-user access). Pre-existing decorative seed "documents" (no real file attached) will fail to download — expected, they were placeholder rows from before real uploads existed.
- Added `services/email.js` — shared Nodemailer wrapper (SMTP, no-ops silently if unconfigured). Wired into: Stripe deposit confirm + webhook (`sendDepositConfirmation`), client withdrawal request (`sendWithdrawalRequested`), admin withdrawal approve/process/reject (`sendWithdrawalStatus`), and monthly fee collection (`sendFeeNotice`). Refactored the existing contact-form mailer (`routes/contact.js`) to use the same shared service instead of its own ad hoc transporter.

### Blocked on user / external
- **Stripe live keys (Step 6)** — Stripe account itself is approved, but user hit a wall trying to add payout bank details: Stripe doesn't list Kosovo as a supported payout country, and the bank account they want to use (Alpine's, in Kosovo) can't be added. Decided to pause Step 6 entirely (no live keys wired in) until resolved with legal/financial advisor — same underlying issue as the BQK item below, just surfaced concretely on the Stripe payout screen (2026-06-18).
- **Alpaca live account** — pending account document approval.
- **Kosovo regulatory/legal (BQK)** — user consulting separately with legal/financial advisor; gates real-money operation, no code action pending.

### Step 5 closeout (2026-06-18)
SMTP wired up with a dedicated Gmail account (`alpinetechconsultancy@gmail.com`, app password, not personal/Workspace) as the sender, notifications landing at `erzentalla1@gmail.com`. `SMTP_HOST=smtp.gmail.com`, `SMTP_PORT=587`, `SMTP_USER`, `SMTP_PASS`, `MAIL_TO` added to local `.env` and Vercel prod env vars; redeployed to production to pick up the new vars. Verified end-to-end by calling all four `services/email.js` functions directly (`sendDepositConfirmation`, `sendWithdrawalRequested`, `sendWithdrawalStatus`, `sendFeeNotice`) — all four delivered and confirmed correct by user. Did not run the flows through real Stripe/Alpaca/DB transactions against production, since that would mutate the seeded demo portfolio for no added signal (the email call sites are unconditional and untouched by this verification).

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
| 3 | Automate one context source | ✅ Done (2026-06-17) |
| 4 | Checkpoint: did this earn a real interface? | ⏳ Pending |
| 5 | First iPhone app (read-only) | ⏳ Pending |
| 6 | First confirmed write action | ⏳ Pending |

### Personal context profile
Built out in `OmniaAurora/context/profile.md` through a guided discovery conversation. Key findings: motivated by building durable systems/frameworks that outlive direct involvement (not ownership/company size); system-building is intrinsically motivating, pure execution is neutral (not draining); real costs already being paid for this work — family time, sleep, some money — these are the things to protect going forward. Status/recognition as a motivator is still untested.

### Tooling — `aurora-cli`
Built `OmniaAurora/aurora-cli/` — a small Node CLI (`npm run brief`) that asks the same 6 daily-context questions, combines them with the permanent profile, calls the Claude API to generate the Daily Executive Briefing, and saves it to `OmniaAurora/daily-briefings/YYYY-MM-DD.md` automatically.

**2026-06-17:** Real Anthropic API key obtained and added to `.env` (billing country: Austria, user's legitimate billing residence — unrelated to the separate Kosovo/BQK regulatory question for Aurora Synapz). First real run surfaced a bug: `index.js` used interactive `readline.question()` per prompt, which silently truncates after ~2 questions when stdin is piped/non-TTY (a Node readline limitation, not a one-off fluke) — fixed by detecting `stdin.isTTY` and falling back to reading all piped input at once, splitting by line in question order. `npm run brief` now runs end-to-end and saves to `OmniaAurora/daily-briefings/YYYY-MM-DD.md`.

**Known rough edge:** the model has no real-time clock, so it sometimes guesses/hallucinates the wrong date in the briefing text itself (the saved filename's date is correct since that comes from `new Date()` in code, not the model). Not yet fixed — would need the actual date passed into the prompt explicitly.

### Daily briefings log
`OmniaAurora/daily-briefings/` — 2026-06-16 (manual, before the CLI existed) and 2026-06-17 (first fully automated run via `aurora-cli`).

---

## How to use this doc
Read it any time to check overall status. It will be updated after each future work session on any project — new steps marked done, new blockers added, new pending items appended.
