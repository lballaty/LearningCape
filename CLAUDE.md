# LearningCape: notes for agents

Read first, in this order: `docs/STATUS-TRACKER.md` (where things stand and what to do next), `docs/PRODUCT_BRIEF.md` (what and why), `docs/PLAN.md` (milestones F0 to F8, open decisions, build and test split). Update the tracker at the end of every session.

## What this is
A standalone app that guides a person through curated AI learning for their role and tracks completion. It is being rebuilt as a Flutter app (`app/`, not yet created) with Supabase for data.

## Architecture (decided 2026-11-18)
- The app runs **on the user's device**; only the data is hosted (Supabase). **One Flutter app, no separate server.** First targets: macOS, iPad, iPhone.
- The assistant will use Sign in with ChatGPT on the user's own plan, with the `127.0.0.1` callback handled inside the app (plan F6). Do not add hosting config or a server-side LLM key.
- Apple builds and device tests need the owner's Mac. A cloud session can only do code, tests and Linux builds.

## Repo map
| Path | What it is |
|---|---|
| `docs/` | Tracker, brief, plan, security baseline (the security doc still describes the web app; rewrite is in F8) |
| `prototypes/siwc_prototype/` | Flutter port of the ChatGPT sign-in. Read its README for what is and is not verified |
| `supabase/` | Migration `0001_init.sql` and Edge Functions. The schema is kept and extended; `assistant_router` is retired in F6; `delete_account` stays |
| Repo root (`index.html`, `app.js`, `styles.css`, `curriculum.json`, `config.js`, `vendor/`, `deploy/`) | The original static web app. **Reference only**: do not extend it or fix its bugs. It is removed when the Flutter app reaches parity (F2) |

## Supabase project
- Dashboard: https://supabase.com/dashboard/project/xsepfjyoiqzkhdnpjckh
- Project ref: `xsepfjyoiqzkhdnpjckh`; API URL: `https://xsepfjyoiqzkhdnpjckh.supabase.co`
- The public anon key (role=anon) is in `config.js`; `.gitleaks.toml` allowlists that file. Reuse the same URL and key in the Flutter app.
- Agents have no dashboard access unless the owner provisions it. Do not ask for secrets in chat. Never commit the `service_role` key, any LLM key, or any `.env`.
- State when last probed (2026-11-18): reachable; migration not applied; anonymous sign-ins off; no functions deployed.

## Lessons from the web app (requirements for the new sync design)
1. Switching level must update the cloud immediately, not only local state.
2. First sign-in must merge local data into the account, never overwrite it.
3. Erase must clear local data even if sign-out fails.
4. No hardcoded track list; tracks come from the curriculum data.

## Rules
- Mark docs Draft / Scaffolded / Ready for Review, never "Final".
- Never log or commit tokens. The prototype's log is designed to exclude them; keep it that way.
- Flutter is not preinstalled in cloud sessions; the stable SDK tarball from storage.googleapis.com installs fine.
- While the web app remains: CI (`.github/workflows/security.yml`) checks that `styles.css` and the two `curriculum.json` copies are in sync. Leave those files alone and CI stays green.
- GitHub reports the repo moved to `lballaty/LearningCape` (capitalised).
