# LearningCape: notes for agents

Static frontend (`index.html`, `app.js`, built `styles.css`) + Supabase (Postgres, Auth, Edge Functions). Read `README.md` and `docs/SECURITY.md` first.

## Supabase project
- Dashboard: https://supabase.com/dashboard/project/xsepfjyoiqzkhdnpjckh
- Project ref: `xsepfjyoiqzkhdnpjckh`; API URL: `https://xsepfjyoiqzkhdnpjckh.supabase.co`
- Agents have **no dashboard/API access** unless the user provisions a token. Do not ask for secrets in chat. Never commit the `service_role` key, `LLM_API_KEY`, or any `.env`.
- The public anon key (role=anon, ref matches) and URL are set in `config.js`; CSP `connect-src` is pinned to the project host in `index.html` and `deploy/nginx.conf.example`. `.gitleaks.toml` allowlists `config.js` for that key. The nginx example still has `learn.example.com` as the domain.

## Status (as of 2026-11-18)
- Repo verified: SRI hash matches, curriculum copies identical, `styles.css` up to date, no unsafe DOM sinks, local-mode browser smoke test passed.
- NOT yet verified: any Supabase path (sign-in, sync, chat, erase). Migration `0001_init.sql` and both Edge Functions are not known to be deployed.
- Open launch items: see `docs/SECURITY.md` section 7 (Gap Review). Placeholders remain in `index.html` privacy modal, `.well-known/security.txt`, `deploy/nginx.conf.example`; CAPTCHA not wired into `signInAnonymously`.

## Known issues (not yet fixed)
1. `reset-track` clears only the local track; reload restores the old cloud track.
2. First sync with an existing cloud profile overwrites the local vault (offline items lost).
3. `deleteAll`: if `delete_account` succeeds but `signOut` throws, local data is kept and an error is shown.
4. `assistant_router` rate-limit count and insert are not atomic (small overshoot possible).
5. `user_sources.notes` column unused by the UI.
6. Curriculum is thin (3 modules per track, several generic landing pages).
7. Header label `v1.7-secure` matches nothing in `package.json`.

## Rules
- After editing `curriculum.json` run `npm run sync:curriculum`; after changing markup/classes run `npm run build:css` and commit `styles.css` (CI fails if stale).
- No `innerHTML`/inline handlers (CI greps for them). Keep CSP `script-src 'self'`.
- Mark docs Draft / Scaffolded / Ready for Review, never "Final".
- GitHub reports the repo moved to `lballaty/LearningCape` (capitalised).
