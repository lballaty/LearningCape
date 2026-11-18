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

### M5. Accounts (Agent, Owner for dashboard settings)
1. Optional email magic-link sign-in that upgrades the anonymous account and keeps its data.
2. CAPTCHA wired into anonymous sign-in.

### M6. Translation-ready (Agent)
1. Move UI strings to `locales/en.json`; allow per-locale titles and descriptions in the curriculum.
2. Czech (`locales/cs.json`) follows after the first release.

### M7. First-user release (Owner decisions, Agent executes)
1. Choose hosting and domain; set `ALLOWED_ORIGIN` and the CSP to match.
2. Fill the privacy notice and `.well-known/security.txt` placeholders.
3. Close the Gap Review in `docs/SECURITY.md` section 7.

Done when: the first user completes the full flow on the hosted URL (the brief's success measure).

## Later (not scheduled)
Quizzes and testing; own coursework and labs; organisations, roles and reporting; assistant rebuild.

## Order and dependencies
M1 can start now. M0 blocks only the cloud half of M1's tests. M2 precedes M3 and M4. M5 and M6 are independent of each other. M7 needs M0 to M3 at minimum.

## Open decisions (Owner)
| # | Decision | Default if unanswered |
|---|---|---|
| 1 | AI assistant: keep as is, rebuild, or remove | Keep, hidden without a key |
| 2 | Hosting for the first tester | None; blocks M7 |
| 3 | Email sign-in before or after the first tester | After |
| 4 | Controller name and contact for the privacy notice | None; blocks M7 |

## Risks
| Risk | Mitigation |
|---|---|
| Third-party links change or disappear | `last_verified` field, scheduled link check, quarterly review |
| Anonymous-only accounts lose data when the browser is cleared | M5 email upgrade; export already exists |
| Vanilla JS outgrows one file | Split `app.js` into ES modules during M2; no framework unless M4 proves it necessary |
| Content quality depends on curation effort | Owner approval gate in M3 |
