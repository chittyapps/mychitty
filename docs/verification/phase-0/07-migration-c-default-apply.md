# Migration C — Default Branch Apply Record

**Date:** 2026-05-11
**Migration:** `migrations/0003_event_ledger_chain_seq_unique.sql`
**Commit (artifact):** `66df51b`
**Source decision:** `docs/decisions/D3-sequence-allocation.md` Q1 ACCEPTED 2026-05-11

## Target

- **Neon project:** `shy-sound-75632194` (ChittyLedger, org ChittyFoundation)
- **Branch:** `br-steep-fog-ae9tdd66` (default)
- **Test branch (pre-apply verification):** `br-steep-glade-aeuhez4o`

## Pre-apply state

- 258 rows in `public.event_ledger` (up from 251 at 2026-05-03 checkpoint; alchemist's 6h cron has run)
- 258/258 rows have `sequence IS NULL` (no v1 writer exists yet)
- `idx_event_ledger_chain_replay` ON (chitty_id, scope, sequence) WHERE sequence IS NOT NULL — index only

## Apply

```sql
ALTER TABLE public.event_ledger
  ADD CONSTRAINT event_ledger_chain_seq_uniq
  UNIQUE (chitty_id, scope, sequence);
```

Plus `COMMENT ON CONSTRAINT` for the audit trail.

## Post-apply verification (default branch)

| Check | Result |
|---|---|
| `pg_get_constraintdef` for `event_ledger_chain_seq_uniq` | `UNIQUE (chitty_id, scope, sequence)`, `contype='u'` |
| Total rows | 258 (unchanged) |

## Behavioral verification (run on `br-steep-glade-aeuhez4o` pre-apply)

| Scenario | Result |
|---|---|
| First INSERT (chitty=`03-1-USA-8244-P-2603-0-33`, scope=`private`, seq=1) | ✅ inserted |
| Duplicate INSERT (same triplet) | ✅ blocked — `duplicate key value violates unique constraint` |
| Same chitty, different scope=`shared`, seq=1 | ✅ inserted (per-chain partitioning works) |
| Multiple NULL-sequence rows for same (chitty, `global`) | ✅ both inserted (PostgreSQL UNIQUE permits multiple NULLs) |

## Interaction with prior migrations

- **Migration A (append-only triggers):** unaffected. UNIQUE is checked at INSERT time, which A's triggers permit. UPDATE/DELETE remain blocked at the trigger layer.
- **Migration B (v1 columns + enum extensions):** unaffected. The constraint references only columns already present pre-B (`chitty_id`, `scope`) plus the `sequence` column B added.

## Live writers during apply

- `chittyagent-alchemist` (6h cron) — inserts `SESSION_INGEST` / `SYSTEM_EVENT` with `sequence IS NULL`. Compatible with UNIQUE on NULL-able column.
- `chittymarket-sync-daemon` — stale since 2026-04-17; no writes during apply window.
- No v1 writer exists yet (D2 implementation pending).

## What this unblocks

- D3 invariant is now DB-enforced on production. Gateway code in `CHITTYFOUNDATION/chittyledger/api/src/v1/` can rely on it as the floor; `pg_advisory_xact_lock` + MAX+1 remains the primary allocator.
- The full v1 schema contract (Migrations A + B + C) is now live on default. Next phase 1 surface is the producer code itself, gated on D5 implementation (`auth.chitty.cc/v1/sign`).

## Rollback (if ever needed)

```sql
ALTER TABLE public.event_ledger DROP CONSTRAINT event_ledger_chain_seq_uniq;
```

Safe — drops only the constraint, no data touched. The `idx_event_ledger_chain_replay` partial index remains.
