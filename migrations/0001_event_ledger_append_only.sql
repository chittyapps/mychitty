-- Migration A — enforce append-only on public.event_ledger
--
-- Source spec: docs/specs/mychitty-v1-light-the-substrate.md §6, §7.2
-- Source verification: docs/verification/phase-0/01-ledger-spine.md §6, §8.1
--
-- Target Neon project: ChittyLedger (id shy-sound-75632194, org ChittyFoundation)
-- Verified state pre-migration (2026-05-02):
--   - 224 rows in public.event_ledger
--   - zero triggers, zero RLS policies, RLS disabled
--   - DB allows arbitrary UPDATE/DELETE
--
-- This migration is non-destructive:
--   - existing 224 rows are not touched
--   - INSERT path is unchanged
--   - only UPDATE and DELETE are blocked at the row trigger level
--
-- Rollback: drop both triggers + the function. No data is altered.

BEGIN;

CREATE OR REPLACE FUNCTION public.event_ledger_no_mutation()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN
  RAISE EXCEPTION
    'event_ledger is append-only (canonical ledger spine; see chittycanon://docs/tech/spec/mychitty-v1-light-the-substrate §6,§7.2)';
END;
$$;

DROP TRIGGER IF EXISTS event_ledger_block_update ON public.event_ledger;
CREATE TRIGGER event_ledger_block_update
  BEFORE UPDATE ON public.event_ledger
  FOR EACH ROW EXECUTE FUNCTION public.event_ledger_no_mutation();

DROP TRIGGER IF EXISTS event_ledger_block_delete ON public.event_ledger;
CREATE TRIGGER event_ledger_block_delete
  BEFORE DELETE ON public.event_ledger
  FOR EACH ROW EXECUTE FUNCTION public.event_ledger_no_mutation();

COMMIT;

-- Verification (run after apply; both should return blocking errors):
--
--   UPDATE public.event_ledger SET action='_test_' WHERE id = (SELECT id FROM public.event_ledger LIMIT 1);
--   DELETE FROM public.event_ledger WHERE id = (SELECT id FROM public.event_ledger LIMIT 1);
--
-- Expected: ERROR  event_ledger is append-only ...
--
-- Trigger inventory check:
--   SELECT tgname FROM pg_trigger
--   WHERE tgrelid = 'public.event_ledger'::regclass AND NOT tgisinternal
--   ORDER BY tgname;
-- Expected: event_ledger_block_delete, event_ledger_block_update
