// Public client configuration. The anon key is public by design; security comes from RLS + authenticated functions.
// NEVER put the service-role key, LLM API key, or any other secret in this file.
window.LEARNINGCAPE_CONFIG = {
  SUPABASE_URL: 'https://YOUR-PROJECT-ID.supabase.co',
  SUPABASE_ANON_KEY: 'YOUR-SUPABASE-ANON-KEY'
};
