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

### Payment gateway research for Kosovo (2026-06-18)
Context: AlpineTech already has an active business bank account at **Raiffeisen Bank Kosovo** — relevant since it's a settlement target for any gateway evaluated below.

- **Wise** — confirmed unsupported. Official Wise help page listing every country/territory eligible to hold money with Wise does not include Kosovo (neighbors Albania/Serbia also excluded; North Macedonia is the only nearby exception). A separate source confirms Wise Business also excludes Kosovo. Ruled out as an intermediary.
- **Paysera** — strongest regulatory fit found so far. EU-licensed Electronic Money Institution that was granted a license *directly by the Central Bank of Kosovo (BQK)* — the same regulator already named in the BQK blocker below. Its Kosovo payment-collection page explicitly lists **Raiffeisen Bank Kosovo** as a supported "Bank Link" partner (1 business day credit) alongside BPB, ProCredit, NLB, TEB, BKT, İşbank, Banka Ekonomike, Ziraat — meaning deposits could plausibly settle straight into AlpineTech's existing Raiffeisen account. Has a developer API (`developers.paysera.com`). Caveat: Paysera's Visa/Mastercard card acceptance (via Paysera Checkout) appears restricted to legal entities registered *within the EU*; the Kosovo-specific page only shows bank-transfer methods, no card option found. If true, this means Paysera would replace Stripe's bank-transfer-style deposits but **not** card deposits — a meaningfully different client UX than the current Stripe flow. Needs direct confirmation from Paysera support. Business account opening for a non-EU company costs €10 and goes through manual document review (up to 10 business days, since Kosovo isn't in their country dropdown).
- **Monri** — Visa/Mastercard payment facilitator, PCI-DSS certified, first SEE payment gateway (est. 2003, Croatia-based), modern API with redirect/hosted-checkout/SDK options (closest feature parity to the current Stripe integration). One directory (paymentproviders.io) lists it as Kosovo-supporting, but Monri's own "About us" page only names Croatia, Bosnia & Herzegovina, Serbia, Montenegro, Slovenia, and "the EU market" as established presence — Kosovo isn't explicitly confirmed. Needs a direct sales inquiry to verify Kosovo merchant onboarding and whether settlement to a Kosovo bank (e.g. Raiffeisen) is possible.
- **Profee** — appears on the same Kosovo-supporting directory listing as Monri, but no usable public docs/fees found yet. Lowest-confidence option, not pursued further.

**Next step:** contact Paysera directly to confirm (a) whether card payments are possible for a Kosovo-registered merchant or if it's bank-transfer-only, and (b) the concrete onboarding path for AlpineTech given the existing Raiffeisen Kosovo account. In parallel, a direct inquiry to Monri to confirm Kosovo merchant eligibility would clarify whether card-payment parity with Stripe is achievable through them instead. No gateway has been chosen yet — this is exploratory, nothing wired into code.

**Update (2026-06-18):** user submitted the inquiry via Paysera's "Na shkruani" business contact form (product: Paysera Checkout), covering the card-vs-bank-transfer question, settlement to the existing Raiffeisen Kosovo account, business account onboarding, and API/integration docs. Awaiting their reply (they quote ~3 business days). Monri has not been contacted yet. Step 6 stays paused until Paysera responds.

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

**2026-06-18:** Fixed the date-guessing bug — `index.js` now computes the real date/weekday via `Date()` and passes it explicitly into the prompt (`buildUserMessage`), with an instruction not to guess. Verified: briefing text now matches the real date. Also extracted the `QUESTIONS` list into `aurora-cli/lib/questions.js` so the CLI and the new backend (below) share one source of truth.

### Daily briefings log
`OmniaAurora/daily-briefings/` — 2026-06-16 (manual, before the CLI existed), 2026-06-17 (first fully automated run via `aurora-cli`), 2026-06-18 (first run with the date fix verified).

### Step 5 — first real interface (backend + native iOS app)
**2026-06-18:** Decided the manual/CLI loop earned a real interface. Built and deployed both halves:

- **Backend:** `OmniaAurora/api/briefing.js`, a new standalone Vercel project (`omnia-aurora`, separate from the `aurora-synapz` project) deployed to `https://omnia-aurora.vercel.app`. Reuses `aurora-cli/lib/buildPrompt.js` directly (same prompt logic, single source of truth), gated by a static shared-secret header (`X-Aurora-Secret`, single-user personal app — simplicity over a full auth system), and persists each day's briefing to Vercel Blob (`daily-briefings/YYYY-MM-DD.md`) so history survives regardless of which client generated it. Verified via curl: correct real date, well-formed briefing, confirmed written to Blob.
- **iOS app:** `OmniaAurora/iOS/`, a native SwiftUI app (XcodeGen-based) mirroring the existing `AuroraSynapz/iOS/` conventions (Models/Services/Views/Utils split, same project.yml shape). Captures the 6 daily-context questions via tap-to-dictate (`SFSpeechRecognizer` + `AVAudioEngine`), POSTs to the new backend, and reads the returned briefing aloud (`AVSpeechSynthesizer`). Builds cleanly and launches in Simulator; UI and mic/speech permission prompts confirmed visually via screenshot.

**Known gap:** the full tap-dictate-listen flow hasn't been exercised through the UI itself yet — sandbox had no Accessibility automation permission to script taps, and Simulator mic/speech dictation isn't reliably testable headlessly anyway. Network path is proven (curl), UI is proven (build + launch + screenshot), but the end-to-end human flow still needs a hands-on run on device/Simulator.

**Trade-off flagged and accepted:** `AURORA_APP_SECRET` is hardcoded as a literal string in `iOS/Aurora/Services/APIService.swift` and committed to git history. Deliberate simplicity choice for a personal single-user MVP — rotate the secret if this repo's visibility ever changes.

All of the above is committed (`583ba4c`), not yet pushed to `origin/master` (local branch is ahead by 7 commits as of 2026-06-18).

### Step 5 expansion — full functional app (same day, 2026-06-18)
User hand-tested the first Step 5 build: **2/5**. Decided to expand from "basics" to a fuller app rather than iterate slowly. Architecture shift: **Vercel Blob became the shared source of truth** for `profile.md` and briefing history (previously the backend only read a git-committed file) — both the iOS app and `aurora-cli` now read/write through a new shared module, `aurora-cli/lib/store.js` (`getProfile`/`saveProfile`/`listBriefings`/`getBriefing`/`saveBriefing`). The git-committed `context/profile.md` is now a seed/backup only; `aurora-cli`'s `npm run profile` mirrors Blob writes back into it so git stays a close (not live) record.

**Backend additions:** `api/profile.js` (GET/POST), `api/briefings.js` (list + `?date=` detail), `api/chat.js` (follow-up Q&A about a specific day's briefing, stateless — client resends the conversation each turn). `CHAT_SYSTEM_PROMPT` added to `buildPrompt.js` (short, conversational, no markdown — replies get read aloud).

**Deploy hiccup:** moving the profile-seed file read into `store.js` using `import.meta.dirname`-based path resolution broke on Vercel (`ENOENT` — ✘Vercel's file tracer didn't bundle `context/profile.md` since it couldn't statically trace that path pattern). Fixed by switching to the same `path.join(process.cwd(), ...)` pattern the original working code used, which the tracer does recognize; `store.js` now tries that first and falls back to an `import.meta.dirname`-relative path for local CLI use (cwd varies depending on where `aurora-cli` is invoked from).

**`aurora-cli` parity:** added `@vercel/blob` + `BLOB_READ_WRITE_TOKEN`; `npm run brief` now also pushes to Blob (not just the local file); three new commands — `npm run history` (list/view past briefings), `npm run chat` (follow-up Q&A from the terminal), `npm run profile` (opens `$EDITOR`, syncs to Blob and the local file on save). All four verified end-to-end, including non-destructive round-trip tests against the real profile/briefing data (temporarily wrote a test marker, confirmed sync, reverted both Blob and the local file before finishing).

**iOS app — conversational redesign:** `ContentView` is now a 4-tab `TabView` (Today/History/Chat/Profile) sharing one `SpeechService` instance via `@EnvironmentObject` (avoids conflicting `AVAudioEngine` sessions across tabs). `TodayView` replaces the old static 6-field form with a one-question-at-a-time flow — Aurora speaks each question (`AVSpeechSynthesizerDelegate` added to `SpeechService` so code can react when she's done talking), then auto-starts listening; typing remains available as a fallback per the original voice-first requirement. New `HistoryView`, `ChatView`, `ProfileView`. Build verified clean (`xcodebuild` succeeded), launched in Simulator, all 4 tabs visible.

**Same known gap as before:** couldn't script taps through History/Chat/Profile from this sandbox (no Accessibility automation permission); verified those paths via curl against the real deployed backend instead, plus code-level tracing against the now-confirmed-working endpoints. Full hands-on retest is the user's next step.

---

## How to use this doc
Read it any time to check overall status. It will be updated after each future work session on any project — new steps marked done, new blockers added, new pending items appended.
