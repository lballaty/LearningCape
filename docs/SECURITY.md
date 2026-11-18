# LearningCape Security & Compliance Baseline

Status: **Draft** (not "Ready for Review" until the Gap Review in section 7 is closed).
This is an engineering control baseline, not legal advice. Have counsel confirm the GDPR and AI Act items.

## 1. Threat model (short)

| Asset | Threat | Primary control |
|---|---|---|
| User rows (track, progress, vault) | Cross-user read/write via public anon key | Auth required; RLS `auth.uid()`; no `anon` grants |
| LLM API key and bill | Key theft; anonymous cost abuse | Key only in Edge secrets; JWT required; per-user rate limit; provider spend cap |
| Browser session | XSS, stored XSS via vault, `javascript:` links | No `innerHTML`; `textContent` rendering; http(s)-only URLs; strict CSP; SRI; no inline script |
| Supply chain | Malicious CDN or package | Vendored script + SRI; Dependabot; `npm audit`; gitleaks in CI |
| Service-role key | Leak, misuse | Server-side only (`delete_account`), acts only on the verified caller |
| Assistant output | Hallucinated or malicious links, prompt injection | Curated module list in prompt; URL allowlist scrub; text-only rendering; no tools or actions |
| Personal data | Over-collection, no erasure | Anonymous ID only; export + erase in UI; no query logging |

## 2. Control map

| Layer | Control | File |
|---|---|---|
| DB | RLS on all tables, owner-scoped; `anon` revoked; `authenticated` least privilege | `supabase/migrations/0001_init.sql` |
| DB | CHECK constraints (track, platform, URL scheme and length, id formats); 200-item vault cap; trigger functions with empty `search_path` | same |
| DB | `assistant_usage` is insert/select only, so users cannot reset their limit | same |
| API | `getUser()` JWT verification on every function; strict single-origin CORS; method and input validation; timeouts; generic errors; `no-store` | `supabase/functions/_shared/http.ts`, `assistant_router`, `delete_account` |
| API | Rate limit (default 20/hour/user, `ASSISTANT_MAX_PER_HOUR`) | `assistant_router/index.ts` |
| API | No query text logged (data minimisation) | `assistant_router/index.ts` |
| Client | Safe DOM building, URL validation, validated localStorage and curriculum parsing, delegated events | `app.js` |
| Client | CSP `script-src 'self'`, `style-src 'self'`, `connect-src` limited to Supabase, `no-referrer`, SRI | `index.html`, `deploy/nginx.conf.example` |
| Client | No third-party font or CDN requests (system fonts, vendored script, built CSS) | `styles.css`, `vendor/` |
| Privacy | Notice, AI-interaction disclosure and consent gate, export, erase | `index.html`, `app.js`, `delete_account` |
| Pipeline | Secret scanning, dependency audit, unsafe-sink grep, secret-in-client grep | `.github/workflows/security.yml` |

## 3. Credentials: where each secret lives

| Secret | Location | Never in |
|---|---|---|
| `LLM_API_KEY` | `supabase secrets set` | repo, `config.js`, browser, logs |
| `SUPABASE_SERVICE_ROLE_KEY` | Injected into Edge Functions by Supabase | repo, client, `.env` committed |
| Supabase anon key / URL | `config.js` (public by design; safe only because of RLS and required auth) | n/a |
| User session token | Browser storage managed by supabase-js (mitigated by CSP and no HTML sinks) | URLs, logs |

Operational rules:
1. Create a **dedicated LLM project key** with a hard monthly spend limit and only the endpoint scope needed. Rotate every 90 days and on any suspicion.
2. If any secret was ever committed, treat it as compromised: rotate first, then purge history.
3. Local `.env` files are for one-time `supabase secrets set` and are deleted afterwards.
4. Pin CI actions to commit SHAs and restrict `GITHUB_TOKEN` to read (already `contents: read`).

### Supabase dashboard settings (manual; not enforceable from code)
- Auth: enable **anonymous sign-ins**; enable **CAPTCHA** (Turnstile or hCaptcha) for sign-ups, which anonymous sign-ins count as, and add the token to `signInAnonymously({ options: { captchaToken } })`; tighten Auth rate limits; keep JWT expiry at 1 hour or less; disable unused providers and email sign-up.
- Edge Functions: deploy **with** JWT verification (default). Never use `--no-verify-jwt`.
- Database: SSL enforcement on; network restrictions if you have a fixed admin IP range; PITR/backups on; keep only `public` exposed in the Data API.
- Set the `ALLOWED_ORIGIN` secret to your exact production origin.

Retention jobs (pg_cron, run as `postgres`):
```sql
select cron.schedule('purge-assistant-usage', '17 3 * * *',
  $$delete from public.assistant_usage where created_at < now() - interval '7 days'$$);
select cron.schedule('purge-stale-anon-users', '41 3 * * 0',
  $$delete from auth.users where is_anonymous and coalesce(last_sign_in_at, created_at) < now() - interval '180 days'$$);
```
(Deleting the auth user cascades to all LearningCape rows. Adjust the retention period to match your published notice.)

## 4. Compliance mapping (indicative)

| Framework | Item | How addressed |
|---|---|---|
| GDPR | Art. 5(1)(c),(e) minimisation, storage limitation | Anonymous ID only, no query storage, retention jobs |
| GDPR | Art. 6, 12-14 lawful basis, transparency | In-app notice (controller placeholders to complete) |
| GDPR | Art. 17, 20 erasure, portability | "Delete all my data" (`delete_account`), "Export my data" |
| GDPR | Art. 25, 32 by design, security of processing | RLS, TLS, access control, CSP, rate limiting |
| GDPR | Art. 28, Chapter V processors, transfers | **Open:** DPAs with Supabase and the LLM provider; confirm hosting region and transfer mechanism (SCCs / DPF) |
| GDPR | Art. 30, 33-34, 35 | **Open:** records of processing, 72h breach procedure, DPIA screening |
| ePrivacy 5(3) | Terminal storage | Only strictly necessary storage (user-requested progress and session); no analytics or tracking; revisit before adding any |
| EU AI Act | Art. 50 transparency (user told they interact with AI) | Consent gate and "AI-generated" labels; **verify current applicability and timing with counsel** |
| OWASP LLM Top 10 | LLM01 injection, LLM02 disclosure, LLM05 output handling, LLM06 agency, LLM10 consumption | Instruction hierarchy plus untrusted-user framing; no sensitive data in prompt; text-only rendering and URL scrub; no tools; rate limit and token cap |
| OWASP Top 10 / ASVS | Access control, injection, misconfiguration, vulnerable components, integrity, auth | RLS, safe DOM, headers, Dependabot and audit, SRI, JWT verification |
| ISO/IEC 27001:2022 Annex A | 5.15, 5.34, 8.9, 8.24, 8.28 | Access control, privacy, configuration, cryptography (TLS), secure coding checks in CI |
| ISO/IEC 42001 | Transparency, third-party AI provider oversight | Disclosure; provider DPA and model-change review (**open**) |

## 5. Residual risks (accepted or open)

1. **Anonymous sessions are bearer sessions in localStorage.** Clearing the browser orphans cloud data; XSS would expose the token (hence the strict CSP). A later email-link upgrade path is advisable.
2. **Anonymous sign-up farming** can bypass per-user rate limits. CAPTCHA and Auth IP limits are the mitigation; the provider spend cap is the backstop.
3. **LLM provider sees question text.** Disclosed in-app; users are told not to enter personal data. Zero-retention terms with the provider are recommended.
4. **CDN-free CSS relies on committed `styles.css`.** CI fails if it is stale.
5. **Curated links are third-party sites** that can change or be compromised; review quarterly. Several modules point to generic landing pages rather than specific courses.

## 6. Vulnerability disclosure & incidents
Publish a real contact in `.well-known/security.txt`. Incident path: contain (rotate keys, disable function), assess personal-data impact, notify the supervisory authority within 72 hours where required, record in the breach register.

## 7. Gap Review (before "Ready for Review")
- [ ] Controller identity and AI provider named in the privacy notice
- [ ] DPAs signed, region and transfer basis recorded
- [ ] CAPTCHA enabled and wired into sign-in
- [ ] Spend cap set on the LLM key; key rotated into Supabase secrets
- [ ] Production CSP `connect-src` set to the exact project host
- [ ] `security.txt` contact and domain completed
- [ ] pg_cron retention jobs scheduled
- [ ] Full browser test of the Supabase paths (sign-in, sync, chat, erase) against a real project
