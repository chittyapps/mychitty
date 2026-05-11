-- Migration C — UNIQUE per-chain sequence on public.event_ledger
--
-- Source decision: docs/decisions/D3-sequence-allocation.md (ACCEPTED 2026-05-11)
--   Q1: Add UNIQUE (chitty_id, scope, sequence) as belt-and-suspenders alongside
--       the gateway's pg_advisory_xact_lock + MAX+1 allocator.
-- Source spec:     docs/specs/mychitty-v1-light-the-substrate.md §9.3 (CanonicalEvent.sequence)
-- Source contract: D2 (chittyledger /v1/* is the producer; this constraint protects
--                  against future code paths that bypass the gateway)
--
-- Target Neon project: ChittyLedger (id shy-sound-75632194, org ChittyFoundation)
-- Verified state pre-migration (2026-05-11):
--   - Migrations A + B applied to default branch br-steep-fog-ae9tdd66 (commit 534970b)
--   - public.event_ledger.sequence: BIGINT, NULL-able, 0/251 rows populated
--   - idx_event_ledger_chain_replay exists ON (chitty_id, scope, sequence)
--     WHERE sequence IS NOT NULL — index only, NOT UNIQUE
--   - No writer currently populates sequence (alchemist is v0-only)
--
-- This migration is additive only:
--   - UNIQUE constraint allows multiple NULLs (PostgreSQL semantics), so the
--     251 existing legacy rows with sequence IS NULL remain valid
--   - First v1 write per (chitty_id, scope) chain inserts sequence=1; UNIQUE
--     prevents any second writer from inserting the same (chitty_id, scope, 1)
--   - Belt-and-suspenders to D3's allocator: even if gateway code is bypassed
--     or buggy, the DB enforces per-chain monotonic sequence injectivity
--   - Constraint validation is fast: existing NULL-sequence rows are skipped;
--     no row scan required for UNIQUE on NULLable column
--
-- Rollback:
--   ALTER TABLE public.event_ledger DROP CONSTRAINT event_ledger_chain_seq_uniq;
--
-- Interactions:
--   - Migration A (append-only triggers) is unaffected; UNIQUE is checked at
--     INSERT time, which Migration A's triggers permit. UPDATE/DELETE remain
--     blocked at the trigger layer.
--   - Migration B's idx_event_ledger_chain_replay is left in place. It serves
--     query-side replay reads (WHERE sequence IS NOT NULL); the UNIQUE
--     constraint serves write-side injectivity. Different purposes.

BEGIN;

ALTER TABLE public.event_ledger
  ADD CONSTRAINT event_ledger_chain_seq_uniq
  UNIQUE (chitty_id, scope, sequence);

COMMENT ON CONSTRAINT event_ledger_chain_seq_uniq ON public.event_ledger IS
  'D3 ACCEPTED: per-(chitty_id, scope) sequence injectivity. NULL sequence permitted '
  'for legacy v0 rows. Belt-and-suspenders to gateway pg_advisory_xact_lock allocator.';

COMMIT;

-- Verification queries (run on branch first, then default):
--
-- 1. Constraint registered:
--   SELECT conname, contype, pg_get_constraintdef(oid) AS def
--   FROM pg_constraint
--   WHERE conrelid = 'public.event_ledger'::regclass
--     AND conname = 'event_ledger_chain_seq_uniq';
-- Expected: 1 row, contype='u',
--   def = 'UNIQUE (chitty_id, scope, sequence)'
--
-- 2. Legacy rows unaffected (251 rows with sequence IS NULL):
--   SELECT COUNT(*) FROM public.event_ledger WHERE sequence IS NULL;
-- Expected: 251 (unchanged from pre-migration count)
--
-- 3. Total row count unchanged:
--   SELECT COUNT(*) FROM public.event_ledger;
-- Expected: 251 (or higher if alchemist has run since; constraint must not
--           reduce row count)
--
-- 4. INSERT of first v1 chain entry succeeds:
--   INSERT INTO public.event_ledger
--     (event_id, event_type, service_name, action, chitty_id, scope, sequence,
--      canonical_entity_type, canon_version)
--   VALUES (gen_random_uuid(), 'DECISION_COMMITTED', 'mig-c-test', 'verify',
--           '03-1-USA-8244-P-2603-0-33', 'private', 1, 'P', '1.0');
-- Expected: 1 row inserted.
--
-- 5. Duplicate INSERT for same (chitty_id, scope, sequence) blocked:
--   INSERT INTO public.event_ledger
--     (event_id, event_type, service_name, action, chitty_id, scope, sequence,
--      canonical_entity_type, canon_version)
--   VALUES (gen_random_uuid(), 'DECISION_COMMITTED', 'mig-c-test', 'verify-dup',
--           '03-1-USA-8244-P-2603-0-33', 'private', 1, 'P', '1.0');
-- Expected: ERROR — duplicate key value violates unique constraint
--           "event_ledger_chain_seq_uniq"
--
-- 6. Different scope, same sequence, allowed:
--   INSERT INTO public.event_ledger
--     (event_id, event_type, service_name, action, chitty_id, scope, sequence,
--      canonical_entity_type, canon_version)
--   VALUES (gen_random_uuid(), 'DECISION_COMMITTED', 'mig-c-test', 'verify-scope',
--           '03-1-USA-8244-P-2603-0-33', 'shared', 1, 'P', '1.0');
-- Expected: 1 row inserted (different scope = different chain).
--
-- 7. NULL sequence still allowed (legacy v0 writers unaffected):
--   INSERT INTO public.event_ledger
--     (event_id, event_type, service_name, action, chitty_id, scope,
--      canonical_entity_type)
--   VALUES (gen_random_uuid(), 'service.healthy', 'mig-c-test', 'legacy',
--           '03-1-USA-8244-P-2603-0-33', 'global', 'P');
-- Expected: 1 row inserted with sequence IS NULL.
--
-- Cleanup of test rows after verification:
--   DELETE FROM public.event_ledger WHERE service_name = 'mig-c-test';
--   -- NB: Migration A blocks DELETE on this table. To clean test rows on the
--   -- verification branch, either (a) drop the branch entirely, or (b)
--   -- temporarily disable the append_only_block_delete trigger:
--   --   ALTER TABLE public.event_ledger DISABLE TRIGGER event_ledger_no_delete;
--   --   DELETE FROM public.event_ledger WHERE service_name = 'mig-c-test';
--   --   ALTER TABLE public.event_ledger ENABLE TRIGGER event_ledger_no_delete;
--   -- Option (a) is preferred for branch verification; option (b) is only for
--   -- non-default branches and must never be run against default.
