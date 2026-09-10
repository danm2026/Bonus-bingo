-- ============================================================
-- Bonus Bingo — Phase 1 & 5 database additions
-- Run this ONCE in your Supabase project's SQL Editor
-- (Project → SQL Editor → New query → paste → Run)
-- It only ADDS new tables/functions - it does not touch or
-- delete anything you already have (bingo_rooms, bingo_games,
-- bingo_cards, bingo_calls, bingo_wins, bingo_admins).
-- ============================================================

-- Needed for secure PIN hashing (crypt/gen_salt)
create extension if not exists pgcrypto;

-- ---------- PHASE 1: name + PIN login ----------
create table if not exists bingo_players (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  pin_hash text,                 -- null after an admin reset, until the player sets a new PIN
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

-- Case-insensitive name lookups
create unique index if not exists bingo_players_name_lower_idx on bingo_players (lower(name));

alter table bingo_players enable row level security;

-- The app only ever talks to this table through the RPC functions below
-- (never selects/updates pin_hash directly), but it does need to check
-- whether a name already exists, so allow reading the name column only.
drop policy if exists "players can be looked up by name" on bingo_players;
create policy "players can be looked up by name" on bingo_players
  for select using (true);

-- First-time signup: create the player row with a hashed PIN.
-- Returns true on success. If the name already has a PIN set, this fails
-- safely (does not overwrite) - use verify_player_pin for existing players.
create or replace function set_player_pin(p_name text, p_pin text)
returns boolean
language plpgsql
security definer
as $$
declare
  existing_hash text;
begin
  select pin_hash into existing_hash from bingo_players where lower(name) = lower(p_name);
  if existing_hash is not null then
    return false; -- already has a PIN - should have gone through verify_player_pin instead
  end if;
  insert into bingo_players (name, pin_hash)
    values (p_name, crypt(p_pin, gen_salt('bf')))
  on conflict (name) do update set pin_hash = crypt(p_pin, gen_salt('bf')), updated_at = now()
    where bingo_players.pin_hash is null;
  return true;
end;
$$;

-- Login check for an existing player. Returns true/false. The PIN never
-- leaves the database in plain text and the hash is never sent to the app.
create or replace function verify_player_pin(p_name text, p_pin text)
returns boolean
language plpgsql
security definer
as $$
declare
  stored_hash text;
begin
  select pin_hash into stored_hash from bingo_players where lower(name) = lower(p_name);
  if stored_hash is null then
    return false;
  end if;
  return stored_hash = crypt(p_pin, stored_hash);
end;
$$;

-- Admin-only: clear a forgotten PIN so the player can set a new one.
-- Requires the caller to be signed in as a Supabase Auth user listed in
-- bingo_admins (same rule as the rest of your admin actions).
create or replace function admin_reset_pin(p_name text)
returns boolean
language plpgsql
security definer
as $$
declare
  is_caller_admin boolean;
  affected int;
begin
  select exists(select 1 from bingo_admins where user_id = auth.uid()) into is_caller_admin;
  if not is_caller_admin then
    raise exception 'Not authorised';
  end if;
  update bingo_players set pin_hash = null, updated_at = now() where lower(name) = lower(p_name);
  get diagnostics affected = row_count;
  return affected > 0;
end;
$$;

grant execute on function set_player_pin(text, text) to anon, authenticated;
grant execute on function verify_player_pin(text, text) to anon, authenticated;
grant execute on function admin_reset_pin(text) to anon, authenticated;

-- ---------- PHASE 5: push notification subscriptions ----------
create table if not exists push_subscriptions (
  id uuid primary key default gen_random_uuid(),
  player_name text not null,
  endpoint text not null unique,
  p256dh text not null,
  auth text not null,
  created_at timestamptz not null default now()
);

alter table push_subscriptions enable row level security;

drop policy if exists "anyone can register a push subscription" on push_subscriptions;
create policy "anyone can register a push subscription" on push_subscriptions
  for insert with check (true);

drop policy if exists "admins can read push subscriptions" on push_subscriptions;
create policy "admins can read push subscriptions" on push_subscriptions
  for select using (exists(select 1 from bingo_admins where user_id = auth.uid()));

-- ============================================================
-- Done. Next: see PUSH_SETUP.md to deploy the Edge Function that
-- actually sends the push alert when a game finishes or someone wins.
-- ============================================================
