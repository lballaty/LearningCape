# LearningCape

Multi-tier AI competency and governance tracker. Static frontend + Supabase (Postgres, Auth, Edge Functions).
Security and compliance controls: see `docs/SECURITY.md` (read before deploying).

## Setup
1. Create a Supabase project. Enable **Anonymous sign-ins** and the other Auth settings in `docs/SECURITY.md` section 3.
2. Apply `supabase/migrations/0001_init.sql`.
3. `supabase secrets set` the values named in `.env.example`, then `supabase functions deploy assistant_router delete_account` (do not pass `--no-verify-jwt`).
4. Edit `config.js` (URL and anon key only) and, if needed, the `connect-src` in the CSP.
5. `npm ci && npm run build:css`, then publish the static files (see `deploy/nginx.conf.example` for required headers).

After editing `curriculum.json` run `npm run sync:curriculum` (the Edge Function needs its own copy).
