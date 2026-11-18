# Vendored dependencies

| File | Package | Version | Integrity (SRI, also pinned in index.html) |
|---|---|---|---|
| supabase.js | @supabase/supabase-js (UMD build, dist/umd/supabase.js) | 2.119.0 | sha384-uteMfOloLDGt042uDz+xHGF3ym63/WQ6rFq7murQRG8Ih7QrXGEGNtWd8688sb4O |

Why vendored: no third-party script host at runtime (supply-chain risk, CSP `script-src 'self'`).

Update procedure: `npm i @supabase/supabase-js@2 --prefix /tmp/sb`, copy `dist/umd/supabase.js` here, recompute
`openssl dgst -sha384 -binary vendor/supabase.js | openssl base64 -A`, update the table above and the `integrity` attribute in index.html.
Review the release notes first; do not adopt a release younger than 14 days.
