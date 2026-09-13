-- Bonus Bingo: allow an authenticated Bingo admin to delete rooms.
-- Run this ONCE in Supabase SQL Editor after the core schema is installed.
-- Because bingo_games, bingo_cards, bingo_calls and bingo_wins reference their
-- parents with ON DELETE CASCADE, deleting a room also removes its related data.

drop policy if exists "rooms deletable by admins" on bingo_rooms;
create policy "rooms deletable by admins" on bingo_rooms
  for delete
  using (
    exists (
      select 1
      from bingo_admins
      where bingo_admins.user_id = auth.uid()
    )
  );
