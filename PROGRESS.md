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
| 7 | Live Alpaca account | ✅ Done (2026-06-19) — live keys wired in, account verified ACTIVE, $0 funded so far |
| 8 | Manual (wire) deposit requests + admin Invest button | ✅ Done (2026-06-19) — bypasses Stripe for family-only use while Step 6 is blocked |
| 9 | iOS app: full client+admin parity + App Store readiness | 🚧 In progress (2026-06-19/20) — see below, code complete for Phases A-D, verification partially done |
| 10 | Production end-to-end verification (web + iOS) | ✅ Done (2026-06-20) — see below |
| 11 | App Store submission | 🚧 Not started — blocked on user's Apple Developer enrollment, see checklist below |

### Step 10 — production E2E verification, App Store + social media prep (2026-06-20)

Goal: verify the whole platform actually works on production before submitting the iOS app to the App Store and announcing anything publicly. Plan agreed with user: web E2E first, then add iOS UI tests (XCUITest) to finally close the "never tapped through the new screens" gap from Step 9, then App Store checklist, with social media held until after App Store approval.

**Critical bug found and fixed:** querying the live fund state before testing revealed `fund.total_units = 100001.35` (leftover paper-trading-era test units on the admin's own account, from before the Step 7 live-Alpaca cutover) while `fund.total_value = $0` (correctly synced from the now-live, unfunded Alpaca account). This meant `unit_price = 0/100001.35 = 0`, so **any real deposit confirmation right now would divide by zero** (`amount / unitPrice` → `Infinity`, rejected by Postgres) — this would have broken the Step 8 Wire Deposit feature for actual family clients, not just a test. Fixed by resetting the admin's phantom units and the fund table to the documented bootstrap state (`total_units=0, total_value=0, unit_price=1.0`) via a direct one-off Neon connection (`.env.local`'s `DATABASE_URL`) — zero impact on James Hartwell/demo's legacy `$1,247,830.54` (separate field, `units_owned=0`, untouched) or Endrit/Blerina (never had a confirmed deposit).

**Web E2E verified on production (after the fix), real money-equivalent round trip:**
- Submitted a real $100 Wire Deposit request as a logged-in user → admin Mark Received → confirmed fund/portfolio correctly went `$0/0 units` → `$100/100 units` at `$1.00/unit`.
- Submitted a $100 withdrawal (the documented $100 minimum) → confirmed immediate deduction back to `$0/0 units` → admin marked it `processed` → full admin lifecycle (pending → processed) exercised, not just reject.
- Net result: fund and portfolio both back to the same `$0/0` baseline as before the test — no residual value.
- Document upload/download: admin uploaded a real PDF for a client, client downloaded it byte-for-byte identical, cross-user download attempt correctly 404'd, test document deleted afterward.
- Fee preview: correctly returns `{collected: 0, clients: []}` right now since no client currently holds fund units — confirmed this is the `totalUnits <= 0` short-circuit in `collectFees()` working as designed, not a bug.
- Contact form: submitted and confirmed it lands in `/api/admin/contacts` (note: route expects `first_name`/`last_name`, not a single `name` field) and triggers the real notification email. No delete endpoint exists for contacts, so this test entry stays in the admin list (clearly labeled, harmless).

**Second critical bug found and fixed:** while preparing an iOS test client, found that `POST /api/admin/users` (the "Add Client" button) never created a matching `portfolios` row — only inserts into `users`. `GET /api/portal/overview` correctly 404s with no portfolio (`routes/portal.js:26`), but `dashboard.html`'s `loadOverview()` has no error handling around that call, so **the client dashboard was actually broken for Endrit and Blerina, your two real family clients, right now** (confirmed via direct DB query: only `user_id` 1 and 3 — demo and admin — had portfolio rows). Fixed by inserting a default `portfolios` row immediately after user creation (`routes/admin.js:99`, every column already defaults to 0 so it's a one-line insert), backfilled the missing rows for Endrit and Blerina directly via Neon, deployed to production, and verified via a disposable test client (`e2e-ios-test@aurorasyanapz.com`, created/will be deleted via the API) that `/api/portal/overview` now returns `200` instead of `404` immediately after client creation.

iOS XCUITest target added (`AuroraSyanapzUITests`, mirrors the pattern from the Omnia Aurora iOS app — `bundle.ui-testing` target type, wired into the `AuroraSyanapz` scheme's test action via an explicit `schemes:` block in `project.yml`). Smoke test (`testAppLaunchesToLoginScreen`) passes in Simulator, confirming this sandbox **can** drive real UI taps/assertions for this app — closing the gap flagged in Step 9 ("no XCUITest target ... Accessibility automation not allowed").

**Third bug found and fixed** while writing the client UI tests: the Overview tab crashed with a generic "The data couldn't be read because it is missing" error for any client with `total_value = 0` (i.e. every brand-new client before their first deposit — this currently includes Endrit and Blerina). Root cause: `routes/portal.js`'s `/allocation` endpoint computes `pct: Math.round((value / total) * 10000) / 100` with no zero-guard — `0/0` is `NaN`, which `JSON.stringify` silently serializes as `null`, and the iOS `AllocationItem.pct` field is a non-optional `Double`, so decoding throws. Fixed with a `total > 0 ? ... : 0` guard, deployed, verified the API now returns `"pct":0` instead of `null` and the Overview tab loads cleanly.

**Fourth bug found and fixed:** `DELETE /api/admin/users/:id` never cleaned up `deposit_requests`/`withdrawal_requests` rows, so deleting any client with deposit/withdrawal history (e.g. the disposable test client created for these UI tests) failed with a foreign-key violation. Added the two missing `DELETE` statements to match the existing cleanup pattern, deployed, verified by successfully deleting the test client afterward.

**iOS UI flow tests — all passing on real Simulator taps against the live production API:**
- Client (`ClientFlowTests`, as a disposable test client created/deleted via the admin API): login, submit a Wire Deposit request and see it appear in history, attempt an over-balance Withdraw and see the correct client-side validation error, Documents tab empty state, Account tab Face ID toggle.
- Admin (`AdminFlowTests`, real admin login): Deposit Requests screen (+ Invest panel) loads with live data, Withdrawals screen loads, Fee Management screen loads (preview + client rates), Documents screen loads and the upload sheet opens/cancels correctly.
- Full suite (38 unit tests + 9 UI tests) run together as a final check.

App Store submission itself still needs the user's Apple Developer account (Phase F, unchanged from Step 9). Social media announcement deliberately held until after App Store approval per user's decision.

**Step 10 closed out 2026-06-20.** Disposable test client (`user_id` 8, then 9 after recreation) deleted from production each time; no test data left behind. All code pushed to `origin/master` (commits `150089b`, `b1f2fff`).

### Step 11 — App Store submission checklist (next session starts here, as of 2026-06-20)

**Already done (code side):**
- Full client + admin feature parity, 38 unit tests + 9 UI tests (`AuroraSyanapzUITests`) passing against production
- Privacy manifest (`PrivacyInfo.xcprivacy`)
- Privacy policy live at `https://aurorasyanapz.com/privacy.html`
- Face ID app-lock, Keychain-based auth
- App icon present (`Assets.xcassets/AppIcon.appiconset/AppIcon.png`)
- Bundle ID `com.aurorasyanapz.app`, version `1.0.0 (1)`

**Done (2026-06-23):**
1. Apple Developer Program enrollment — user confirmed enrolled, Team ID `Q2Y8G759LA`.
2. Xcode signing Team — wired `DEVELOPMENT_TEAM: Q2Y8G759LA` + `CODE_SIGN_STYLE: Automatic` into `project.yml` (base settings, applies to all targets), regenerated the project (`xcodegen generate`), verified with a real `xcodebuild archive` (Release config) — succeeded.
3. App Store Connect app record created by user: Bundle ID `com.aurorasyanapz.app`, SKU `aurorasyanapz-ios-app`, name "Aurora Synapz".
4. Listing copy drafted (name, subtitle, promotional text, full description, keywords, support/marketing/privacy URLs) — written to reflect actual app functionality (client portal, deposits/withdrawals, documents, Face ID), not the institutional marketing-site copy, and notes the app is invite-only (no public sign-up, accounts issued by the advisor).
5. **First build uploaded to App Store Connect / TestFlight (2026-06-23).** Real blockers hit and fixed along the way:
   - Xcode had no live Developer Portal session (no Xcode-Token in keychain for any account) — automatic Distribution cert/profile creation failed until user signed back into the Apple ID in Xcode Settings → Accounts.
   - `xcodebuild -exportArchive` from the CLI doesn't auto-create profiles unless `-allowProvisioningUpdates` is passed — without it, export failed with "No profiles ... were found" even with a valid signed-in account.
   - Upload-time validation (stricter than the local archive-time warning) **rejected** the build: declaring only Portrait/Portrait-upside-down orientations isn't allowed for apps that support iPad, since iPad multitasking requires all 4 orientations. Fixed by setting `TARGETED_DEVICE_FAMILY: "1"` (iPhone-only) in `project.yml` instead of adding landscape support the app was never designed or tested for.
   - After that fix, archive → export with `destination: upload` in the export-options plist succeeded end-to-end directly from the CLI (no Transporter app needed) — **"Upload succeeded"**, build now processing in App Store Connect.

**Left — gated on the user:**
6. Wait for build processing to finish in App Store Connect, then select it for the TestFlight/App Store version.
7. Screenshots — Claude can generate these via Simulator now that signing works.
8. App Privacy questionnaire in App Store Connect — maps directly from `PrivacyInfo.xcprivacy`.
9. Export compliance — almost certainly "no" (HTTPS only, no custom crypto).
10. Age rating questionnaire.
11. Pricing (free) / availability (countries).
12. **App Review demo account** — app has no public sign-up (admin-issued accounts only), so App Review will need dedicated reviewer credentials supplied in App Store Connect's "App Review Information." Not yet created.
13. Submit for review.

Social media announcement stays held until after App Store approval (user's call, 2026-06-20).

### Also fixed along the way
- Vercel cron for nightly Alpaca sync was silently 404'ing (POST route vs GET-only cron) — fixed, now `GET /api/alpaca/cron-sync`.
- Added second cron for monthly fee collection (`GET /api/admin/fee/cron-collect`, 1st of month).
- Cleaned up demo/seed data (`demo@aurorasyanapz.com`) that had leaked fake value into real fund totals.
- Document uploads stored as `BYTEA` directly in Postgres (no separate blob storage needed) — admin uploads PDF/PNG/JPEG (max 10MB) per client via `/api/admin/documents`; clients download only their own files via `/api/portal/documents/:id/download` (404 on cross-user access). Pre-existing decorative seed "documents" (no real file attached) will fail to download — expected, they were placeholder rows from before real uploads existed.
- Added `services/email.js` — shared Nodemailer wrapper (SMTP, no-ops silently if unconfigured). Wired into: Stripe deposit confirm + webhook (`sendDepositConfirmation`), client withdrawal request (`sendWithdrawalRequested`), admin withdrawal approve/process/reject (`sendWithdrawalStatus`), and monthly fee collection (`sendFeeNotice`). Refactored the existing contact-form mailer (`routes/contact.js`) to use the same shared service instead of its own ad hoc transporter.

### Blocked on user / external
- **Stripe live keys (Step 6)** — Stripe account itself is approved, but user hit a wall trying to add payout bank details: Stripe doesn't list Kosovo as a supported payout country, and the bank account they want to use (Alpine's, in Kosovo) can't be added. Decided to pause Step 6 entirely (no live keys wired in) until resolved with legal/financial advisor — same underlying issue as the BQK item below, just surfaced concretely on the Stripe payout screen (2026-06-18).
- **Kosovo regulatory/legal (BQK)** — user consulting separately with legal/financial advisor; gates real-money operation, no code action pending.

### Step 9 — iOS app: full functionality + App Store readiness (in progress, 2026-06-19/20)

Audited the existing iOS app (`AuroraSynapz/iOS/`) and found it badly behind the backend: client-only had Overview/Holdings/Transactions/Documents/Account, admin only had Clients/Contacts. No Withdraw, no Deposit Request, no Fee Management, no admin document management, no Invest button — and real App Store blockers (no privacy manifest, JWT stored in `UserDefaults` instead of Keychain, dangling `LaunchScreenBackground` asset reference, unused Face ID string). Approved plan: build full client **and** admin parity, add a real Face ID app-lock, draft a privacy policy page.

**Done (code complete, build + 38 unit tests passing):**
- `PrivacyInfo.xcprivacy` added (no tracking, first-party-only data declared).
- Fixed the missing `LaunchScreenBackground` colorset (was referenced but didn't exist).
- `AuthStore` migrated from `UserDefaults` to Keychain (`Services/KeychainHelper.swift`), same public interface.
- Real Face ID app-lock implemented (`BiometricAuthenticator.swift`, `LockView.swift`), toggle in `AccountView`, re-locks on backgrounding.
- `NSPhotoLibraryUsageDescription` added (needed for proof-of-payment photo picker).
- `Models.swift`: added `Fund`, `WithdrawalRequest`, `DepositRequest`, `InvestCashStatus`, `TradeResult`, `InvestResult`, `FeePreviewClient`/`Result`, `StripeDeposit`; extended `Portfolio`/`AdminUser`/`Document`.
- `APIService.swift`: added a multipart/form-data helper (none existed — needed for deposit-proof and admin document upload) and ~20 missing endpoint methods; added a `401` → `NotificationCenter` → `AuthStore.logout()` path so expired sessions actually bounce to `LoginView` instead of leaving a dead error on screen.
- New client screens: `WithdrawView`, `DepositRequestView` (with `PhotosPicker` proof upload), real in-app document download in `DocumentsView` (was previously just "email support").
- New admin screens: `AdminDepositRequestsView` (review + the Invest panel — 40/30/20 split, mirrors today's web feature), `AdminWithdrawalsView`, `AdminFeeManagementView`, `AdminDocumentsView` (upload via `.fileImporter`, PDF/PNG/JPEG).
- **Real bug found and fixed via live-backend verification**: Postgres `NUMERIC` columns come back as JSON *strings* from the `pg` driver (e.g. `"total_value": "99978.9"`) wherever the backend doesn't explicitly `parseFloat()` before `res.json()` — confirmed by curling the real API with the user's login. This silently breaks plain `Double` Codable fields. Affected **pre-existing** models too (`Portfolio`, `Holding`, `Transaction`), not just the new ones — likely never caught because the old unit tests used hand-written JSON with unquoted numbers, never real server responses. Fixed with a `lossyDouble`/`lossyDoubleIfPresent` `KeyedDecodingContainer` extension and custom `init(from:)` on every affected model.

**Verification done:** `xcodegen generate` + `xcodebuild build` succeeds; `xcodebuild test` passes all 38 tests; app launches in Simulator (screenshot-confirmed login screen renders correctly, demo-fill button correctly gone); logged into the real production API with the user's actual admin credentials and confirmed live response shapes for `/api/admin/deposit-requests`, `/api/admin/invest/cash`, `/api/admin/withdrawals`, `/api/admin/fee/preview`, `/api/alpaca/status` (fund), `/api/admin/users` — this is what surfaced the NUMERIC-string bug above.

**Not yet done:**
- **Full interactive Simulator click-through** (tap through Withdraw/Deposit/admin screens with real data) — discovered this sandbox can query Simulator window geometry via Accessibility but **cannot** actually click/type (`osascript ... click at` fails with "not allowed assistive access"), and this project has no XCUITest target to script taps another way. Build+tests+live-API verification stand in for it for now; a hands-on pass on a real device/Simulator is still worth doing.
- **Phase F (not executable by me — needs the user's Apple ID/Developer account)**: Apple Developer Program enrollment, Xcode signing Team selection (currently no `DEVELOPMENT_TEAM` set — this is the actual "won't archive" blocker), App Store Connect app record, screenshots, listing copy, export-compliance/age-rating answers, Submit for Review.

**Privacy policy closeout (2026-06-20):** user approved the drafted `public/privacy.html` content as-is. Linked it from the marketing site footer (`index.html`, which already had a dead `href="#"` placeholder) and added a small link under the login form (`login.html`, which had no footer). URL is `https://aurorasyanapz.com/privacy.html` — ready to use as the required privacy-policy URL in App Store Connect once Phase F starts.

**Stripe deposit flow hidden (2026-06-20):** user flagged that the live Stripe Payment Element was surfacing payment methods like Amazon Pay (Stripe's dashboard-driven default, not app code) — a reminder that the card-deposit flow is still test-keys-only while Step 6 is blocked. Commented out the "Deposit Funds" (Stripe) nav link in `dashboard.html` so clients only see "Wire Deposit"; `/deposit.html` itself is untouched and still reachable directly. Re-enable by uncommenting once Step 6's Kosovo payout blocker is resolved.

Test deposit requests submitted during earlier dry-run testing (Blerina Mahmuti $100, Endrit Talla $10) were rejected by the user after confirming the upload/review flow worked — no fund impact, nothing to clean up.

### Step 7 closeout — live Alpaca account (2026-06-19)
Alpaca approved the live account. Swapped `ALPACA_API_KEY`/`ALPACA_SECRET_KEY` (live) and `ALPACA_ENDPOINT` (`https://api.alpaca.markets/v2`, was paper) in local `.env` and Vercel prod env vars (removed old paper vars first, since `vercel env add` fails on an existing key), then redeployed to production (`vercel --prod`, aliased to `aurorasyanapz.com`). Verified directly against Alpaca's REST API: account `283423123`, `status: ACTIVE`, currently `$0` cash/buying power (unfunded) — so no real orders execute yet, but the moment the account is funded, real deposits/withdrawals through the app will place real orders (`routes/stripe.js` auto-invests 40% SPY/30% BND/20% GLD on deposit; `routes/portal.js` auto-sells proportionally on withdrawal). No code changes were needed — the Alpaca integration was already endpoint-agnostic (no hardcoded "paper" logic anywhere in the codebase).

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

### Step 5 fully verified + Phase 1 complete (2026-06-19)

**Real UI automation unlocked:** added an `AuroraUITests` XCUITest target (XCUIApplication driving the actual Simulator — taps, typing, assertions), which doesn't need the Accessibility permission `osascript`-based automation required. This caught two genuine bugs on the first run: the Today flow's "Next" button was disabled while Aurora was still speaking the question (`.disabled(speech.isSpeaking)`), and `SpeechService.speak()` queued rather than interrupted utterances, both fixed. Step 5 is now hand-tested via real, repeatable automation rather than curl + visual inspection alone.

**Phase 1 of `vision/roadmap-v1.md` completed** (iPhone App, Voice+Chat, Notes, Tasks, Knowledge): added Tasks/Notes/Knowledge as a generic Blob-backed CRUD pattern (`aurora-cli/lib/listResource.js`), a new iOS **Workspace** tab, persistent chat history, a daily reminder notification, and a real app icon. Briefing and chat prompts now read this tracked data instead of guessing what's overdue.

**Critical storage bug found and fixed:** Vercel Blob stores created with `access: 'public'` are *always* served from CDN cache with no way to bypass it (the SDK's `useCache: false` option is explicitly "ignored for public blobs") — meaning reads right after a write could silently return stale/empty data. Discovered via real end-to-end verification (planted a task, asked Aurora about it, got "no open tasks" back). Fixed by migrating to a new `private` Blob store + the SDK's authenticated read path — also the more appropriate access level for personal data that never needed a public URL in the first place. All real data (profile, the one saved briefing) was preserved through the migration.

### Phase 2 started — Gmail + Calendar connected (2026-06-19)

Aurora can now read the user's real Gmail (read-only) and Google Calendar (read-only) instead of relying on what gets typed in by hand. OAuth runs server-side (Google Cloud "Web application" client — secret stays on Vercel, never on the phone; refresh token lives in the same private Blob store as everything else). A "Google Account" section in the iOS Profile tab handles connect/disconnect.

Verified end-to-end, not just that the connection succeeded: asked Aurora in chat what was in recent email and on the calendar, and the reply correctly referenced real Aurora Synapz notification emails (from the Step 5 email-notifications work) — proving the context wiring, not just the OAuth handshake.

**Known, accepted limitation:** the OAuth consent screen stays in Google's "Testing" publishing status — pursuing full verification (required for Gmail's "Restricted" scope) would mean weeks of review for an app only one person uses. The real consequence: refresh tokens expire after ~7 days, so reconnecting is one tap in Profile when it lapses.

Project Awareness (the third Phase 2 item — GitHub activity across the `aurora-synapz` and `alpinetechwebsite` repos) is the next planned piece, not yet started.

### Phase 2 complete — Project Awareness (GitHub) connected (2026-06-20)

Aurora now reads real GitHub activity (recent commits, open PRs, open issues) from `aurora-synapz` and `alpinetechwebsite`, feeding the same context pipeline used for tasks/notes/Gmail/calendar. Unlike Google, no OAuth dance was needed — a fine-grained, read-only personal access token (Contents/Issues/Pull requests, scoped to just those two repos) covers it, deliberately narrower than the broad `gh` CLI OAuth token already on this machine (which carries `delete_repo`/`read:org` — explicitly avoided as too broad to reuse here).

**Backend:** new `aurora-cli/lib/github.js` (`getProjectContext()`), mirroring `google.js`'s fail-open shape — returns `''` if `GITHUB_TOKEN` isn't set. Wired into `api/briefing.js` and `api/chat.js` alongside `getGoogleContext()`. Repos tracked via `GITHUB_REPOS` (defaults to the two above) — token scope and `GITHUB_REPOS` are kept in sync deliberately; granting the token broader repo access wouldn't add real awareness unless the env var list is expanded too.

**Verified end-to-end:** asked Aurora in chat for the latest commit message on `aurora-synapz` and it returned the real, current top commit (`"Close out Step 10 (production E2E verification), add Step 11 App Store checklist"`) plus correctly reported no open PRs/issues — proving live data, not generic filler.

**Side fix:** the user's `.zshrc` was missing the `nvm` init block entirely (file didn't exist), so `vercel` and other nvm-managed global CLIs resolved in sandboxed tool shells but not in the user's own interactive terminal. Added the standard `nvm.sh` sourcing block to `~/.zshrc`.

No iOS changes — GitHub access here is a static server-side token, not per-user OAuth, so there's no connect/disconnect UI needed (same as Tasks/Notes/Knowledge).

**Phase 2 is now fully complete** (Email, Calendar, Project Awareness). Next up per `vision/roadmap-v1.md`: Phase 3 (Agent Orchestration, Workflow Execution).

### Session close (2026-06-20) — Phase 3 starting point decided, not yet built

Stopping for today with Phase 2 fully shipped. Phase 3's roadmap entries (Agent Orchestration, Workflow Execution) are still just headings — no detailed spec exists yet, and it's a real architectural jump: everything built in Phases 1-2 is read-only (tasks/notes/knowledge, Gmail, calendar, GitHub), while Phase 3 is where Aurora starts actually doing things.

**Decided starting point for next session:** rather than jumping straight into multi-agent orchestration or full workflow execution, start Phase 3 with one small, explicitly-confirmed write action through chat — e.g. "add this as a task" triggers the existing Tasks API (`api/tasks.js`), but only after Aurora repeats the action back and the user confirms. This also closes out the original (pre-Phase-1/2) MVP roadmap's still-pending "Step 6: first confirmed write action," and follows architecture principle #4, "Human Approval for Sensitive Actions" (`vision/architecture-principles-v1.md`). Not yet scoped in detail or built — pick this up next session.

---

## How to use this doc
Read it any time to check overall status. It will be updated after each future work session on any project — new steps marked done, new blockers added, new pending items appended.
