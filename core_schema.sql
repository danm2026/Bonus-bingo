-- ============================================================
-- Bonus Bingo — CORE schema (rooms, games, cards, calls, wins, admins)
-- Run this ONCE in Supabase → SQL Editor, BEFORE schema_additions.sql
-- (schema_additions.sql only adds login + push tables on top of this).
--
-- Your Table Editor showed zero tables, which is why nothing has
-- worked as real live data so far — this creates the tables your
-- index.html has been trying to talk to the whole time.
-- ============================================================

create extension if not exists pgcrypto;

-- ---------- Rooms ----------
create table if not exists bingo_rooms (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  mode text not null default 'free',           -- 'free' or 'paid'
  entry_fee numeric not null default 0,
  created_at timestamptz not null default now()
);

-- ---------- Games (one per room, one "current" game at a time) ----------
create table if not exists bingo_games (
  id uuid primary key default gen_random_uuid(),
  room_id uuid not null references bingo_rooms(id) on delete cascade,
  status text not null default 'scheduled',    -- scheduled | active | finished | void
  scheduled_start timestamptz,
  started_at timestamptz,
  finished_at timestamptz,
  call_interval_ms integer not null default 3000,
  colour_index integer not null default 0,
  line_won boolean not null default false,
  two_lines_won boolean not null default false,
  full_house_won boolean not null default false,
  pot_one numeric not null default 0,
  pot_two numeric not null default 0,
  pot_full numeric not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists bingo_games_room_idx on bingo_games(room_id);

-- ---------- Cards (tickets players buy/hold per game) ----------
create table if not exists bingo_cards (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references bingo_games(id) on delete cascade,
  player_name text not null,
  numbers jsonb not null,                      -- the 3x9 grid
  has_paid boolean not null default false,
  amount_paid numeric not null default 0,
  paid_confirmed_at timestamptz,
  created_at timestamptz not null default now()
);

create index if not exists bingo_cards_game_idx on bingo_cards(game_id);

-- ---------- Calls (numbers called during a game) ----------
create table if not exists bingo_calls (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references bingo_games(id) on delete cascade,
  number integer not null,
  called_at timestamptz not null default now()
);

create index if not exists bingo_calls_game_idx on bingo_calls(game_id);

-- ---------- Wins (payout records per game) ----------
create table if not exists bingo_wins (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references bingo_games(id) on delete cascade,
  tier text not null,                          -- line | two_lines | full_house
  card_id uuid references bingo_cards(id) on delete set null,
  player_name text not null,
  payout numeric not null default 0,
  created_at timestamptz not null default now()
);

create index if not exists bingo_wins_game_idx on bingo_wins(game_id);

-- ---------- Admins (which Supabase Auth users are allowed admin access) ----------
create table if not exists bingo_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  created_at timestamptz not null default now()
);

-- ============================================================
-- Row Level Security
-- Everyone (anon) can read game/room/card/call/win data, since
-- players are not authenticated via Supabase Auth (only name+PIN).
-- Writes are allowed broadly too, matching how this app already
-- works (the app's own logic, not the database, decides who may
-- click "buy cards" or "create room" etc.) — this matches the
-- permissive pattern already used by push_subscriptions and
-- bingo_players in schema_additions.sql.
-- ============================================================

alter table bingo_rooms enable row level security;
alter table bingo_games enable row level security;
alter table bingo_cards enable row level security;
alter table bingo_calls enable row level security;
alter table bingo_wins enable row level security;
alter table bingo_admins enable row level security;

drop policy if exists "rooms readable" on bingo_rooms;
create policy "rooms readable" on bingo_rooms for select using (true);
drop policy if exists "rooms writable" on bingo_rooms;
create policy "rooms writable" on bingo_rooms for insert with check (true);
drop policy if exists "rooms updatable" on bingo_rooms;
create policy "rooms updatable" on bingo_rooms for update using (true);

drop policy if exists "games readable" on bingo_games;
create policy "games readable" on bingo_games for select using (true);
drop policy if exists "games writable" on bingo_games;
create policy "games writable" on bingo_games for insert with check (true);
drop policy if exists "games updatable" on bingo_games;
create policy "games updatable" on bingo_games for update using (true);

drop policy if exists "cards readable" on bingo_cards;
create policy "cards readable" on bingo_cards for select using (true);
drop policy if exists "cards writable" on bingo_cards;
create policy "cards writable" on bingo_cards for insert with check (true);
drop policy if exists "cards updatable" on bingo_cards;
create policy "cards updatable" on bingo_cards for update using (true);
drop policy if exists "cards deletable" on bingo_cards;
create policy "cards deletable" on bingo_cards for delete using (true);

drop policy if exists "calls readable" on bingo_calls;
create policy "calls readable" on bingo_calls for select using (true);
drop policy if exists "calls writable" on bingo_calls;
create policy "calls writable" on bingo_calls for insert with check (true);
drop policy if exists "calls deletable" on bingo_calls;
create policy "calls deletable" on bingo_calls for delete using (true);

drop policy if exists "wins readable" on bingo_wins;
create policy "wins readable" on bingo_wins for select using (true);
drop policy if exists "wins writable" on bingo_wins;
create policy "wins writable" on bingo_wins for insert with check (true);
drop policy if exists "wins deletable" on bingo_wins;
create policy "wins deletable" on bingo_wins for delete using (true);

-- Admins table: a signed-in user can check their OWN row (needed for
-- the admin-login check right after signInWithPassword), but nobody
-- can read the whole list or write to it from the browser — that's
-- managed by you directly in Supabase's Table Editor.
drop policy if exists "admins can check own row" on bingo_admins;
create policy "admins can check own row" on bingo_admins
  for select using (auth.uid() = user_id);

-- ============================================================
-- Done. Next: run schema_additions.sql (login + push tables), then
-- add yourself to bingo_admins using your Supabase Auth user's UID:
--
--   insert into bingo_admins (user_id) values ('YOUR-UID-HERE');
--
-- Find your UID under Authentication → Users.
-- ============================================================
