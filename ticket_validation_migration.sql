-- Bonus Bingo — fix the ticket validation error:
-- "Ticket cells must contain numbers or null"
--
-- This migration is for databases that already contain an older ticket
-- validation trigger which incorrectly treats the 3x9 ticket rows as cells.
-- It removes only a bingo_cards trigger whose function contains that exact
-- error message, then installs a validator that accepts the app's 3x9 grid.
-- Run once in Supabase -> SQL Editor.

DO $$
DECLARE
  r record;
BEGIN
  FOR r IN
    SELECT t.tgname, n.nspname
    FROM pg_trigger t
    JOIN pg_class c ON c.oid = t.tgrelid
    JOIN pg_namespace n ON n.oid = c.relnamespace
    JOIN pg_proc p ON p.oid = t.tgfoid
    WHERE c.relname = 'bingo_cards'
      AND NOT t.tgisinternal
      AND pg_get_functiondef(p.oid) ILIKE '%Ticket cells must contain numbers or null%'
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS %I ON %I.bingo_cards', r.tgname, r.nspname);
  END LOOP;
END $$;

CREATE OR REPLACE FUNCTION public.validate_bonus_bingo_ticket()
RETURNS trigger
LANGUAGE plpgsql
AS $$
DECLARE
  row_value jsonb;
  cell_value jsonb;
  row_index integer;
  cell_index integer;
  numeric_value numeric;
BEGIN
  IF jsonb_typeof(NEW.numbers) <> 'array'
     OR jsonb_array_length(NEW.numbers) <> 3 THEN
    RAISE EXCEPTION 'Ticket must contain exactly 3 rows';
  END IF;

  FOR row_index IN 0..2 LOOP
    row_value := NEW.numbers -> row_index;

    IF jsonb_typeof(row_value) <> 'array'
       OR jsonb_array_length(row_value) <> 9 THEN
      RAISE EXCEPTION 'Ticket rows must contain exactly 9 cells';
    END IF;

    FOR cell_index IN 0..8 LOOP
      cell_value := row_value -> cell_index;

      IF jsonb_typeof(cell_value) = 'null' THEN
        CONTINUE;
      END IF;

      IF jsonb_typeof(cell_value) <> 'number' THEN
        RAISE EXCEPTION 'Ticket cells must contain numbers or null';
      END IF;

      numeric_value := (cell_value #>> '{}')::numeric;
      IF numeric_value <> trunc(numeric_value)
         OR numeric_value < 1
         OR numeric_value > 90 THEN
        RAISE EXCEPTION 'Ticket cells must contain whole numbers from 1 to 90 or null';
      END IF;
    END LOOP;
  END LOOP;

  RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS bonus_bingo_validate_ticket ON public.bingo_cards;
CREATE TRIGGER bonus_bingo_validate_ticket
BEFORE INSERT OR UPDATE OF numbers ON public.bingo_cards
FOR EACH ROW
EXECUTE FUNCTION public.validate_bonus_bingo_ticket();
