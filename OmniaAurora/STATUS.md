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
| 5 | First iPhone app (read-only, **voice-first** — talk to Aurora, not just chat; text remains a secondary option) | ✅ Done — conversational Today flow, History, Chat, in-app Profile editing, Workspace tab (Tasks/Notes/Knowledge), persistent chat history, daily reminder notification, real app icon. Verified via XCUITest in Simulator (full add/complete/delete cycle against the live backend); user couldn't test on physical device this round. |
| 6 | First confirmed write action | ✅ Done — Tasks/Notes/Knowledge are real read-write resources (Vercel Blob, private store); briefing and chat prompts read this tracked data instead of guessing. |

**Phase 1 (roadmap-v1.md) is now complete**: iPhone App, Voice + Chat, Notes, Tasks, Knowledge all shipped.

**Phase 2 (Email + Calendar) — started 2026-06-19**: Gmail + Google Calendar connected (read-only, OAuth via a Google Cloud "Web application" client, `erzentalla1@gmail.com` as the connected account). Briefing and chat now read real calendar events and recent email instead of guessing — verified end-to-end (chat correctly surfaced real Aurora Synapz notification emails; briefing referenced the same). Known limitation: the OAuth consent screen is in Google's "Testing" status (avoids the multi-week verification process required for Gmail's "Restricted" scope), so the refresh token expires after ~7 days — reconnecting is one tap ("Connect Google Account" in the Profile tab) when it lapses. Project Awareness (the third Phase 2 item) not yet started.

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
