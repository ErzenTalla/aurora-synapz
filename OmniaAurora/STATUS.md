# Omnia OS & Aurora — Status

This is the working folder for the Omnia OS / Aurora project. Separate from `AuroraSynapz/` (the investment platform) and `alpinetechwebsite-workbench/` (the web agency project) — those are two of the *domains* Aurora's briefings will cover, not part of this project's codebase.

## Where we are

Following the baby-steps MVP path: prove the daily-briefing loop manually before building any app or platform.

| Step | Item | Status |
|---|---|---|
| 0 | Define scope + question list | ✅ Done (see below) |
| 1 | Manual daily briefing (you paste context, Aurora responds in chat) | ✅ Done |
| 2 | Tighten format/voice | ✅ Done (format proven stable across 2026-06-16/17/18 briefings) |
| 3 | Automate one context source | ✅ Done — `aurora-cli` automates the whole loop (context → Claude → saved briefing) |
| 4 | Checkpoint: did this earn a real interface? | ✅ Done — decided yes, moved to Step 5 (2026-06-18) |
| 5 | First iPhone app (read-only, **voice-first** — talk to Aurora, not just chat; text remains a secondary option) | 🟡 Hands-on tested by user: 2/5. Expanded same day — conversational Today flow (Aurora speaks/listens per question), History tab, Chat-about-today's-briefing tab, in-app Profile editing, `aurora-cli` parity (history/chat/profile commands). Not yet re-tested by hand since the expansion. |
| 6 | First confirmed write action | ⏳ Pending |

## Scope (Step 0)

**Domains covered:** Aurora Synapz, AlpineTech, **and personal/life items** (not work-only).

**Core questions Aurora answers each morning:**
- What needs my decision today
- What's overdue or slipping
- What did I commit to recently that hasn't happened yet
- What's the single most important thing today

## Daily briefings

Logged in `daily-briefings/` as you run them, so we can look back and see what's actually useful versus noise, and refine the format over time.

## Vision reference

Original vision documents (not build specs) live in `vision/`.
