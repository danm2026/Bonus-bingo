-- Bonus Bingo: preserve winner history when rooms/games are deleted.
-- Run once in Supabase SQL Editor.

-- Keep winner rows after their game is deleted by making game_id nullable
-- and changing the FK from CASCADE to SET NULL.
alter table bingo_wins alter column game_id drop not null;

alter table bingo_wins
  drop constraint if exists bingo_wins_game_id_fkey;

alter table bingo_wins
  add constraint bingo_wins_game_id_fkey
  foreign key (game_id) references bingo_games(id) on delete set null;

-- Winner history is public, but only authenticated Bingo admins may delete it.
drop policy if exists "wins deletable" on bingo_wins;
drop policy if exists "wins deletable by admins" on bingo_wins;
create policy "wins deletable by admins" on bingo_wins
  for delete
  using (exists (select 1 from bingo_admins where bingo_admins.user_id = auth.uid()));
