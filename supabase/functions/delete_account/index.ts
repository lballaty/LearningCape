// GDPR Art. 17 erasure: deletes the caller's auth user; FK cascades remove all rows.
import { createClient } from "npm:@supabase/supabase-js@2.45.4";
import { authenticate, corsHeaders, json } from "../_shared/http.ts";

Deno.serve(async (req) => {
  if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders(req) });
  if (req.method !== "POST") return json(req, { error: "method_not_allowed" }, 405);

  const ctx = await authenticate(req);
  if (!ctx) return json(req, { error: "unauthorized" }, 401);

  // Service-role key exists only here, server-side, and only ever acts on the verified caller's id.
  const admin = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
    { auth: { persistSession: false } },
  );
  const { error } = await admin.auth.admin.deleteUser(ctx.user.id);
  if (error) { console.error("delete_failed"); return json(req, { error: "server_error" }, 500); }
  return json(req, { ok: true });
});
