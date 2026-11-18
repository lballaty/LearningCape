# LearningCape Development Plan

Path: `docs/PLAN.md` · Status: **Draft** · Date: 2026-11-18 · Reads with `docs/PRODUCT_BRIEF.md`, `docs/SECURITY.md`, `CLAUDE.md`.

"Agent" = can be done by a coding agent alone. "Owner" = needs the owner (accounts, dashboard, legal, or a product choice).

## Milestones

### M0. Cloud bring-up (Owner, then Agent verifies)
Project `xsepfjyoiqzkhdnpjckh` is reachable but empty.
1. Owner: run `supabase/migrations/0001_init.sql` in the SQL Editor.
2. Owner: enable anonymous sign-ins.
3. Owner: deploy `assistant_router` and `delete_account` (JWT verification on); set `ALLOWED_ORIGIN`; set `LLM_API_KEY` only if the assistant is wanted.
4. Agent: probe the API, then run end-to-end tests of sign-in, sync and erase.

Done when: a browser session creates a profile row, syncs progress and vault, and erase removes them.

### M1. Stabilise (Agent)
1. Fix known issues 1 to 3 in `CLAUDE.md` (level switch desync, local vault lost on first sync, erase error path).
2. Add Playwright end-to-end tests under `tests/` and run them in `.github/workflows/`.
3. Hide the assistant button when no cloud connection or key is configured.
4. Replace the `v1.7-secure` label with the `package.json` version.

Done when: tests pass in CI for local-only mode, and against the real project once M0 is complete.

### M2. Curriculum model v2 (Agent, owner reviews the schema)
Goal: structured paths with meaningful progress, and no hardcoded tracks.
1. New `curriculum.json` shape: track → modules → resources. Each resource has `id`, `title`, `desc`, `link`, `format` (course, video, article, repo, docs), `provider`, `minutes`, `last_verified`.
2. Progress is recorded per resource, using the existing `user_progress.subtask_id` column. Module and track progress are derived.
3. Render the level selector from `curriculum.json`; remove the track list from `app.js`, `index.html` and the edge function.
4. Migration `0002`: replace the fixed `track_id` list check with a format check, so adding a track needs no migration.
5. Org-ready design note only (no tables yet): every user table is keyed by the auth user id, so `organizations` and `memberships` can be added later as additive tables.

Done when: adding a track or resource is a JSON-only change, and progress shows per module and per track.

### M3. Content (Agent drafts, Owner approves)
1. Expand each track to roughly 6 to 8 modules with 2 to 4 free resources each, from several vendors and neutral bodies.
2. Each link points to a specific resource, not a landing page.
3. Add a scheduled CI link check.

Done when: the owner has approved the list for all five tracks.

### M4. Tracker features (Agent)
1. Progress overview: per-module bars, completion dates, time invested (sum of `minutes`).
2. Vault notes (the `user_sources.notes` column already exists).
3. Printable and exportable progress record (self-attested; clearly labelled as not a certificate).
4. Search (owner requirement): one box over all tracks' modules and resources and the user's vault; in-browser index built from `curriculum.json` and the vault; filters for track, format and completed state; results link to the module or vault item. No server call. The same index can later feed the assistant's retrieval.

### M5. Accounts (Agent, Owner for dashboard settings). Scheduled directly after M1.
1. Email and password sign-up, sign-in, sign-out and password reset. No MFA during the testing period (owner decision).
2. Owner: enable the Email provider; decide on email confirmation (assumed off during testing); leave MFA off.
3. Replace anonymous sign-in. Local data on the device is pushed to the account on first sign-in.
4. Update the privacy notice and `docs/SECURITY.md`: an email address is now stored, which the current text says is not the case. Record "no MFA" and "confirmation off" as accepted testing-period risks to revisit before wider release.
5. CAPTCHA on sign-up before wider release.

### M6. Translation-ready (Agent)
1. Move UI strings to `locales/en.json`; allow per-locale titles and descriptions in the curriculum.
2. Czech (`locales/cs.json`) follows after the first release.

### M7. First-user release (Owner decisions, Agent executes)
1. Build installers for the wrapped desktop app (open decision 2); set `ALLOWED_ORIGIN` and the CSP to the local origin; retire `deploy/nginx.conf.example`.
2. Fill the privacy notice and `.well-known/security.txt` placeholders.
3. Close the Gap Review in `docs/SECURITY.md` section 7.

Done when: the first user installs and starts the app on their own computer and completes the full flow (the brief's success measure).

### M8. Assistant on the user's ChatGPT plan (Agent; Owner tests with own login). Can follow M1.
1. Inside the wrapped desktop app (no separate server), the app's own background code handles Sign in with ChatGPT: dynamic client registration, PKCE, loopback callback, token storage in the operating system's credential store, Responses API calls with `store: false`.
2. Assistant sits behind a provider interface so other providers can be added.
3. Retrieval over the local curriculum index (shared with search, M4) so answers cite curated resources; keep the link allowlist.
4. Retire the `assistant_router` Edge Function, the `LLM_API_KEY` secret and the `assistant_usage` table once the local path works (the user's own plan and its cap replace our rate limit).
5. Add a licence file if the open-source route is relied on.

## Later (not scheduled)
Quizzes and testing; own coursework and labs; organisations, roles and reporting; assistant rebuild.

## Order and dependencies
M1 can start now. M0 blocks only the cloud half of M1's tests. M5 follows M1 and needs M0. M2 precedes M3 and M4. M6 is independent. M7 needs M0 to M3 at minimum.

## Open decisions (Owner)
| # | Decision | Default if unanswered |
|---|---|---|
| 1 | Resolved 2026-11-18: assistant uses Sign in with ChatGPT through a local helper (M8); no approval needed while the app is local | n/a |
| 2 | Desktop wrapper framework: Electron or Tauri (owner decided 2026-11-18 that it is one wrapped app, no separate server) | Electron |
| 3 | Does password sign-in replace anonymous sessions, and is email confirmation off during testing | Replace; off |
| 4 | Controller name and contact for the privacy notice | None; blocks M7 |

## Risks
| Risk | Mitigation |
|---|---|
| Third-party links change or disappear | `last_verified` field, scheduled link check, quarterly review |
| Password-only accounts without MFA or email confirmation are weaker | Accepted for the testing period only; revisit before wider release |
| Vanilla JS outgrows one file | Split `app.js` into ES modules during M2; no framework unless M4 proves it necessary |
| Content quality depends on curation effort | Owner approval gate in M3 |
