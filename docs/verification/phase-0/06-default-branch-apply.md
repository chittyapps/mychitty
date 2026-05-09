# Phase 0 — Migrations A+B Default Branch Apply

**Date:** 2026-05-09
**Project:** ChittyLedger (`shy-sound-75632194`) | **DB:** `neondb` | **Branch:** `br-steep-fog-ae9tdd66` (default)
**Applied by:** chittyagent-neon (delegated)
**Authorization:** user "go default" 2026-05-09
**Pre-condition:** both migrations passed all 6 checks on test branch `br-fancy-art-aevxcl6o`

## Migration apply

| Step | Result |
|---|---|
| Migration A — `migrations/0001_event_ledger_append_only.sql` | APPLIED — function + 2 BEFORE triggers committed |
| Migration B — `migrations/0002_event_ledger_v1_columns.sql` | APPLIED — 13 columns, 13 COMMENTs, 3 CHECKs, 4 indexes, 12 enum values committed |

## Verification

| Check | Expected | Actual | Status |
|---|---:|---:|:---:|
| V1 — new columns | 13 | 13 | PASS |
| V2 — new enum values | 12 | 12 | PASS |
| V3 — new CHECK constraints | 3 | 3 | PASS |
| V4 — new partial indexes | 4 | 4 | PASS |
| V5 — append-only triggers | 2 | 2 | PASS |
| V6 — row count before/after | unchanged ± live writes | 250 → 251 | PASS |

## Behavioral tests

| Test | Result |
|---|---|
| `UPDATE event_ledger SET action='_test_' WHERE id=…` | ERROR `event_ledger is append-only …` (PASS) |
| `DELETE FROM event_ledger WHERE id=…` | ERROR `event_ledger is append-only …` (PASS) |
| Benign v1-shaped INSERT | PASS — row `788c267e-3f98-4174-8c71-6901ad982a80` (`AUDIT/migration_apply_verify`, `substrate='system'`, `canon_version='1.0'`, `scope='global'`) inserted and **kept** as the canonical migration audit entry |

## Notes

- Pre-existing constraint `event_ledger_scope_check` requires scope ∈ `{private,shared,project,global}` — untouched by either migration; the audit INSERT used `scope='global'`.
- Test branch `br-fancy-art-aevxcl6o` left intact for forensic comparison.
- New columns are NULLable; legacy 224 rows + alchemist's ongoing INSERTs remain compatible. Phase 1 must add a `WHERE canon_version='1.0'` discriminator on every v1 consumer query.

## Phase 0 closure

- ✅ R1–R5 reports filed
- ✅ Migrations A+B applied to default with all checks green
- ⏳ D1–D9 decisions (R4 §"Decisions needed"; R5 §6) outstanding — these gate Phase 1 entry, not Phase 0 closure

**Phase 0 is complete.** STOP-GATE lifts for Phase 1 design once D1–D9 are resolved.
