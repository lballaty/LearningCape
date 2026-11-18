-- LearningCape Initial Supabase Migration (hardened)
-- Run via `supabase db push`, or paste into the Supabase SQL Editor on a clean database.
-- Requires: Supabase Auth with anonymous sign-ins enabled.
-- Principle: deny by default; every row is owned by auth.uid(); no access for role anon.

-- 1. Tables ---------------------------------------------------------------

create table public.user_profiles (
  client_uuid uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  track_id    text not null check (track_id in ('everyday','student','office','engineer','executive')),
  created_at  timestamptz not null default now(),
  updated_at  timestamptz not null default now()
);

create table public.user_sources (
  id          uuid primary key default gen_random_uuid(),
  client_uuid uuid not null default auth.uid() references public.user_profiles(client_uuid) on delete cascade,
  title       text not null check (char_length(title) between 1 and 200),
  platform    text not null check (platform in ('GitHub','YouTube','Google Skills','Paid Course','Custom PDF')),
  url         text check (url is null or (char_length(url) <= 2048 and url ~* '^https?://')),
  completed   boolean not null default false,
  notes       text check (notes is null or char_length(notes) <= 2000),
  created_at  timestamptz not null default now()
);
create index user_sources_owner_idx on public.user_sources (client_uuid);

create table public.user_progress (
  id          uuid primary key default gen_random_uuid(),
  client_uuid uuid not null default auth.uid() references public.user_profiles(client_uuid) on delete cascade,
  module_id   text not null check (module_id ~ '^[a-z0-9-]{1,20}$'),
  subtask_id  text not null default 'default' check (subtask_id ~ '^[a-z0-9-]{1,40}$'),
  is_completed boolean not null default false,
  updated_at  timestamptz not null default now(),
  unique (client_uuid, module_id, subtask_id)
);

-- Per-user usage log used for assistant rate limiting (insert/select only).
create table public.assistant_usage (
  id         bigint generated always as identity primary key,
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);
create index assistant_usage_user_time_idx on public.assistant_usage (user_id, created_at desc);

-- 2. Trigger functions (empty search_path, not callable via the API) ------

create function public.set_updated_at() returns trigger
language plpgsql set search_path = '' as $$
begin new.updated_at = now(); return new; end $$;

create function public.enforce_source_limit() returns trigger
language plpgsql set search_path = '' as $$
begin
  if (select count(*) from public.user_sources where client_uuid = new.client_uuid) >= 200 then
    raise exception 'vault_limit_reached';
  end if;
  return new;
end $$;

revoke all on function public.set_updated_at()      from public, anon, authenticated;
revoke all on function public.enforce_source_limit() from public, anon, authenticated;

create trigger trg_profiles_updated before update on public.user_profiles
  for each row execute function public.set_updated_at();
create trigger trg_progress_updated before update on public.user_progress
  for each row execute function public.set_updated_at();
create trigger trg_sources_limit before insert on public.user_sources
  for each row execute function public.enforce_source_limit();

-- 3. Privileges: nothing for anon; minimum for authenticated --------------

revoke all on public.user_profiles, public.user_sources, public.user_progress, public.assistant_usage from anon;
revoke all on public.user_profiles, public.user_sources, public.user_progress, public.assistant_usage from authenticated;

grant select, insert, update, delete on public.user_profiles to authenticated;
grant select, insert, update, delete on public.user_sources  to authenticated;
grant select, insert, update, delete on public.user_progress to authenticated;
grant select, insert                 on public.assistant_usage to authenticated;
grant usage on sequence public.assistant_usage_id_seq to authenticated;

-- 4. Row-Level Security ---------------------------------------------------

alter table public.user_profiles   enable row level security;
alter table public.user_sources    enable row level security;
alter table public.user_progress   enable row level security;
alter table public.assistant_usage enable row level security;

create policy "own profile" on public.user_profiles
  for all to authenticated
  using (client_uuid = (select auth.uid())) with check (client_uuid = (select auth.uid()));

create policy "own sources" on public.user_sources
  for all to authenticated
  using (client_uuid = (select auth.uid())) with check (client_uuid = (select auth.uid()));

create policy "own progress" on public.user_progress
  for all to authenticated
  using (client_uuid = (select auth.uid())) with check (client_uuid = (select auth.uid()));

create policy "own usage read" on public.assistant_usage
  for select to authenticated using (user_id = (select auth.uid()));
create policy "own usage insert" on public.assistant_usage
  for insert to authenticated with check (user_id = (select auth.uid()));
-- No update/delete policy on assistant_usage: users cannot reset their own rate limit.
-- Retention: purge old usage rows (see docs/SECURITY.md, pg_cron snippet).
