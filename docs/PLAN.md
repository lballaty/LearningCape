# LearningCape Development Plan

Path: `docs/PLAN.md` · Status: **Draft** · Date: 2026-11-18 (rewritten for the Flutter decision) · Reads with `docs/PRODUCT_BRIEF.md`, `docs/SECURITY.md`, `CLAUDE.md`.

"Agent" = a coding agent can do it alone. "Owner" = needs the owner (accounts, dashboard, devices, legal, or a product choice).

## Architecture
- **Client:** one Flutter app in `app/`, running on the user's device. First targets: macOS, iPad, iPhone. Windows and Android later. No separate server.
- **Data:** Supabase project `xsepfjyoiqzkhdnpjckh` (Postgres with row-level security, Auth). The schema in `supabase/migrations/` is kept and extended.
- **Local-first:** the app keeps its data in a local SQLite database and syncs to Supabase when signed in.
- **Assistant:** Sign in with ChatGPT inside the app (loopback callback on `127.0.0.1`), using the user's own plan. No server-side LLM key.
- **Existing web app** (`index.html`, `app.js`, etc.): reference implementation only. It is not developed further and is removed when the Flutter app reaches parity (F2). Its known bugs are not fixed; they become requirements for the new sync design.

## Milestones

### F0. Cloud bring-up (Owner, then Agent verifies)
1. Owner: run `supabase/migrations/0001_init.sql` in the SQL Editor.
2. Owner: enable the Email provider with password sign-in; email confirmation off for the testing period; MFA off.
3. Agent: probe the API and confirm tables and sign-up work.

Done when: a test account can sign up, sign in and write its own rows, and cannot read another account's rows.

### F1. Flutter foundation (Agent)
1. Create the Flutter project in `app/` (macOS and iOS targets), with theme, navigation and a state-management layer.
2. Local SQLite store with a full-text index (used by search in F5).
3. Curriculum model v2: track → modules → resources; each resource has `id`, `title`, `desc`, `link`, `format`, `provider`, `minutes`, `last_verified`. Bundled with the app as an asset. No hardcoded track list anywhere.
4. Migration `0002`: replace the fixed `track_id` list check with a format check; progress recorded per resource through `user_progress.subtask_id`.
5. CI: `flutter analyze`, unit and widget tests on every push; keep the secret scan.

Done when: the app builds, opens to the level selector rendered from the curriculum asset, and CI is green.

### F2. Feature parity with the web app (Agent)
Level selection and switching; module and resource lists; completion tracking with per-module and per-track progress; vault (add, complete, remove, notes); export my data; delete all my data (`delete_account` function stays).

Done when: everything the web app does works in the Flutter app in local-only mode, with tests; the web app files are then removed.

### F3. Accounts and sync (Agent; Owner for dashboard settings)
1. Email and password sign-up, sign-in, sign-out, password reset. No MFA in the testing period.
2. Sync rules written down first, then implemented: local data is merged into the account on first sign-in (never overwritten); switching level updates the cloud immediately; erase clears local data even if sign-out fails.
3. Session token kept in the device's secure storage.

Done when: two devices signed in to one account show the same progress and vault.

### F4. Content (Agent drafts, Owner approves)
1. Expand each track to roughly 6 to 8 modules with 2 to 4 free resources each, from several vendors and neutral bodies; every link points to a specific resource.
2. Scheduled CI link check.

### F5. Search and tracker features (Agent)
1. One search box over all tracks' modules and resources and the user's vault; filters for track, format and completed state; runs on the device.
2. Progress overview with completion dates and time invested.
3. Exportable progress record (self-attested; labelled as not a certificate).

### F6. Assistant on the user's ChatGPT plan (Agent; Owner tests with own login)
1. **Feasibility check first, on a real iPad and iPhone:** confirm the `127.0.0.1` callback arrives while the app is in the background. If it does not, the assistant ships on macOS only until OpenAI offers another route.
2. Sign in with ChatGPT: dynamic client registration, PKCE, loopback callback, tokens in secure storage, Responses API with `store: false`.
3. Provider interface so other providers can be added.
4. Answers grounded in the local curriculum index (shared with search), with the link allowlist kept.
5. Retire `assistant_router`, the `LLM_API_KEY` secret and the `assistant_usage` table.
6. Add a licence file if the open-source route is relied on.

### F7. Languages (Agent)
English strings in Flutter's localisation files from F1 onward; Czech added after the first release.

### F8. First-user release (Owner decisions, Agent executes)
1. Signed macOS build and TestFlight builds for iPad and iPhone.
2. Privacy notice with controller name and contact; note that an email address and (if used) a ChatGPT sign-in are involved.
3. Rewrite `docs/SECURITY.md` for the Flutter client (browser controls no longer apply; database rules stay) and close its Gap Review.

Done when: the first user installs the app on their own device and completes the full flow (the brief's success measure).

## Later (not scheduled)
Quizzes and testing; own coursework and labs; organisations, roles and reporting; Windows and Android builds; curriculum updates delivered from Supabase without an app release.

## Order and dependencies
F1 can start now. F0 blocks F3. F2 follows F1. F4 can run alongside F2. F5 follows F2. The F6 feasibility check should run as soon as F1 builds on a device, because its result affects scope. F8 needs F0 to F5.

## Build and test split
| Activity | Where |
|---|---|
| Code, unit and widget tests, Linux build | Cloud agent session |
| macOS, iPad and iPhone builds; device tests; ChatGPT login test | Owner's Mac (Xcode and Flutter installed), with iPad and iPhone attached; an agent session running on or connected to that Mac |
| Signing and TestFlight upload | Owner's Apple developer account |

## Open decisions (Owner)
| # | Decision | Default if unanswered |
|---|---|---|
| 1 | Resolved: assistant uses Sign in with ChatGPT inside the app (F6) | n/a |
| 2 | Resolved: Flutter, one app, no separate server | n/a |
| 3 | Does password sign-in replace anonymous sessions; is email confirmation off during testing | Replace; off |
| 4 | Controller name and contact for the privacy notice | None; blocks F8 |
| 5 | First platforms | macOS, iPad, iPhone |

## Risks
| Risk | Mitigation |
|---|---|
| ChatGPT login callback may not work on iPad and iPhone | Feasibility check early in F6; desktop-only assistant as fallback |
| OpenAI's sign-in is a preview and may change or restrict access | Provider interface; assistant is optional to the core app |
| Third-party links change or disappear | `last_verified` field, scheduled link check, quarterly review |
| Password-only accounts without MFA or email confirmation are weaker | Accepted for the testing period only; revisit before wider release |
| Cloud agent cannot build or run Apple targets | Build and test split above |
