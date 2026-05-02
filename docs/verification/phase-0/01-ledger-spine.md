# Phase 0 Report 1 — Ledger Spine Verification

**Status:** complete
**Author:** Claude (Opus 4.7, VM session @chittyserv-dev)
**Verified against:** Neon project `ChittyLedger` (id `shy-sound-75632194`, org `org-old-mountain-22774840` / ChittyFoundation), default branch, 2026-05-02
**Spec reference:** `docs/specs/mychitty-v1-light-the-substrate.md` §7.2, §26 Phase 0 Report 1
**Authority tier:** Verified operational evidence (per spec §1.3) — direct DB schema inspection + live row sampling

---

## Summary

The design-pinned canonical spine `public.event_ledger` **exists as a real table and is actively written to** (224 rows, last write 2026-05-02 18:01 UTC). Its schema is **structurally well-aligned with v1 needs** but has **four operational gaps** that block the spec's requirements:

1. **Hash-chain columns exist but are never populated** (`prev_hash`, `event_hash` — 0/224 rows).
2. **Append-only is not enforced** (no triggers, no RLS, RLS disabled).
3. **No signature / signature_proof / signer_cid columns** — spec §9.3 + §11.2 require these on every CanonicalEvent.
4. **No bonded-action linkage columns** (`bond_id`, `linked_event_hash`) — spec §9.3 + §10.5 require dual-write.

The spec's empirical baseline (§5) is **partially incorrect**: it claims `chitty_ledger_entries` has 0 rows, says the substrate is "dark or stale", and does not mention `event_ledger`. In fact `event_ledger` is the live target, with two real writers and one real P-Synthetic ChittyID already in production.

**Decision:** `public.event_ledger` is the correct canonical spine for v1. Proceed with that table. Migration is required to add signing/bonding columns and enforce append-only. Hash-chain wiring is an application-layer fix in ChittyConnect (columns are already present).

---

## 1. Spine candidate inventory

Eight candidate tables in `ChittyLedger`/`public` were inventoried; verified row counts:

| Table | Rows | Last write | Verdict |
|---|---:|---|---|
| `event_ledger` | **224** | 2026-05-02T18:01:07Z | **CANONICAL — live** |
| `chronicle_events` | 907 | (no `created_at` returned; column is `timestamp` — see §4) | Projection, not canon |
| `chitty_ledger_entries` | 2 | 2026-02-23T06:54:57Z | Stale legacy; **deprecate** |
| `ledger_entries` | 0 | — | Empty, unused |
| `event_store` | 0 | — | Empty, unused |
| `events` | 0 | — | Empty, unused |
| `audit_log` | 0 | — | Empty, unused |
| `session_bindings` | 0 | — | Empty — but `event_ledger.session_id` is in active use |

Spec §5 baseline corrections:

| Spec §5 claim | Verified state |
|---|---|
| `public.chitty_ledger_entries` has 0 rows | **2 rows**, stale (last 2026-02-23) |
| `chronicle_events` has 14 lifetime rows | **907 rows** (but unable to verify `last write` from the column set — see §4) |
| `context.sessions/ledger/session_groups` has 0 rows | Not verified in this report — those tables are in **`ChittyOS-Core`** (`restless-grass-40598426`), not ChittyLedger |
| Substrate dark or stale | True for v1 substrates (Claude Code/OpenClaw/ChatGPT have written **0 rows ever**), but **not true for the spine itself** — chittyagent-alchemist + chittymarket-sync-daemon are live writers |

---

## 2. `public.event_ledger` schema (verified)

Source: `pg_class` + `information_schema.columns` + `pg_constraint` (Neon MCP `describe_table_schema`).

### 2.1 Columns

```text
id                    uuid       NOT NULL  DEFAULT uuid_generate_v4()
event_id              text       NOT NULL                              -- UNIQUE
event_type            event_type NOT NULL                              -- enum, 24 values (§3)
event_severity        event_severity NOT NULL  DEFAULT 'INFO'
service_name          text       NOT NULL
user_id               uuid       NULL       -> users(id) ON DELETE SET NULL
case_id               uuid       NULL       -> cases(id) ON DELETE SET NULL
action                text       NOT NULL
entity_type           text       NULL
entity_id             uuid       NULL
ip_address            inet       NULL
user_agent            text       NULL
request_id            text       NULL
session_id            text       NULL
metadata              jsonb      NULL       DEFAULT '{}'::jsonb
timestamp             timestamptz NULL      DEFAULT CURRENT_TIMESTAMP
chitty_id             text       NULL       -- "Format: VV-G-LLL-SSSS-T-YM-C-X"
scope                 text       NULL       DEFAULT 'private'           -- CHECK in {private,shared,project,global}
group_id              text       NULL
project               text       NULL
canonical_entity_type char(1)    NULL       -- CHECK in {P,L,T,E,A}
parent_chitty_id      text       NULL
display_name          text       NULL
prev_hash             text       NULL       -- "Hash of the previous event in this entity's chain..."
event_hash            text       NULL       -- "SHA-256 of this event for hash chain verification"
```

### 2.2 Constraints (verified)

- `PRIMARY KEY (id)`
- `UNIQUE (event_id)` — event_id is the external stable identifier
- `CHECK (canonical_entity_type IN ('P','L','T','E','A'))` — **matches spec §3.3 P/L/T/E/A ontology exactly**
- `CHECK (scope IN ('private','shared','project','global'))`
- `FOREIGN KEY (case_id) -> cases(id) ON DELETE SET NULL`
- `FOREIGN KEY (user_id) -> users(id) ON DELETE SET NULL`

### 2.3 Indexes (17 total, all btree, ~16 kB each)

Hot read paths covered:
- `idx_event_ledger_chitty_id_time` on `(chitty_id, timestamp DESC)` — **directly supports v1 `read_last_events(entity_cid)`** (spec §10.6)
- `idx_event_ledger_chitty_id_type` on `(chitty_id, event_type)`
- `idx_event_ledger_timestamp` on `(timestamp DESC)`
- `idx_event_ledger_canonical_type` partial on `canonical_entity_type WHERE NOT NULL`
- `idx_event_ledger_parent` partial on `parent_chitty_id WHERE NOT NULL`
- `idx_event_ledger_group_id` partial on `group_id WHERE NOT NULL`
- `idx_event_ledger_scope` on `scope`

### 2.4 Column-level canon citation

`canonical_entity_type` column comment cites `chittycanon://gov/governance#core-types` — confirms the table was authored against the same canon the spec implements. Strong signal that this is the right spine.

---

## 3. `event_type` enum (verified)

24 values present:

```text
USER_ACTION, SYSTEM_EVENT, API_CALL, SERVICE_INTERACTION, ERROR, SECURITY, AUDIT,
INTEGRATION, SESSION_INGEST, ENTITY_CREATED, ENTITY_FISSION, ENTITY_FUSION,
ENTITY_SUSPENSION, ENTITY_RETIREMENT, ENTITY_REWARMING, SESSION_START, SESSION_END,
SESSION_MERGE, TOOL_CALL, ROUTING_DECISION, LIFECYCLE_SIGNAL, TRUST_OBSERVATION,
ALCHEMIST_PROPOSAL, CHANNEL_REGISTERED
```

`event_severity`: `DEBUG, INFO, WARNING, ERROR, CRITICAL`.

### 3.1 Mapping to spec §9.3 `CanonicalEventType`

| Spec value | Existing enum value | Status |
|---|---|---|
| `entity.minted` | `ENTITY_CREATED` | ✅ usable |
| `session.bind` | `SESSION_START` | ✅ usable |
| `session.unbind` | `SESSION_END` | ✅ usable |
| `tool.invoked` | `TOOL_CALL` | ✅ usable |
| `trust.observed` | `TRUST_OBSERVATION` | ✅ usable |
| `error.observed` | `ERROR` | ✅ usable |
| `interaction.observed` | — | ❌ **missing** (could overload `USER_ACTION`) |
| `decision.committed` | — | ❌ **missing** |
| `action.requested` | — | ❌ **missing** |
| `action.executed` | — | ❌ **missing** |
| `bonded_action.requested` | — | ❌ **missing** |
| `bonded_action.executed` | — | ❌ **missing** |
| `sponsor_bond.created` | — | ❌ **missing** |
| `sponsor_bond.severed` | — | ❌ **missing** |
| `synthesis.completed` | — | ❌ **missing** |
| `surface_pack.read` | — | ❌ **missing** |
| `mirror.exported` | — | ❌ **missing** |
| `authority.updated` | — | ❌ **missing** |

**Migration delta:** add 12 enum values. (`ALTER TYPE event_type ADD VALUE 'DECISION_COMMITTED';` etc. — no rewrite needed; enum additions are non-destructive in PG.)

Schema also has 6 lifecycle values not in spec (`ENTITY_FISSION`, `ENTITY_FUSION`, `ENTITY_SUSPENSION`, `ENTITY_RETIREMENT`, `ENTITY_REWARMING`, `SESSION_MERGE`) which **support v1 KYA lifecycle** (spec §22) and should be retained.

---

## 4. Live writer evidence (verified)

Recent 10 writes (sampled `ORDER BY timestamp DESC LIMIT 10`):

```text
2026-05-02 18:01:07Z  SYSTEM_EVENT      chittyagent-alchemist     alchemist_analysis  scope=global  type=null   chitty_id=null
2026-05-02 12:00:07Z  SYSTEM_EVENT      chittyagent-alchemist     alchemist_analysis  scope=global  type=null   chitty_id=null
2026-05-02 06:00:07Z  SYSTEM_EVENT      chittyagent-alchemist     alchemist_analysis  scope=global  type=null   chitty_id=null
2026-05-02 00:00:05Z  SYSTEM_EVENT      chittyagent-alchemist     alchemist_analysis  scope=global  type=null   chitty_id=null
2026-05-01 12:00:38Z  SYSTEM_EVENT      chittyagent-alchemist     alchemist_analysis  scope=global  type=null   chitty_id=null
2026-05-01 00:00:34Z  SYSTEM_EVENT      chittyagent-alchemist     alchemist_analysis  scope=global  type=null   chitty_id=null
2026-04-17 02:19:07Z  SESSION_INGEST    chittymarket-sync-daemon  session_ingest      scope=private type=P      chitty_id=03-1-USA-8244-P-2603-0-33
2026-04-17 02:19:07Z  SESSION_INGEST    chittymarket-sync-daemon  session_ingest      scope=private type=P      chitty_id=03-1-USA-8244-P-2603-0-33
2026-04-16 16:43:07Z  SESSION_INGEST    chittymarket-sync-daemon  session_ingest      scope=private type=P      chitty_id=03-1-USA-8244-P-2603-0-33
2026-04-16 16:43:07Z  SESSION_INGEST    chittymarket-sync-daemon  session_ingest      scope=private type=P      chitty_id=03-1-USA-8244-P-2603-0-33
```

Two real writers:
- **chittyagent-alchemist** — periodic system analysis writes, scope=global, no chitty_id (these are fleet-level, not entity-bound).
- **chittymarket-sync-daemon** — session ingest writes for one P-Synthetic entity (last write 2026-04-17, **stale by ~2 weeks**).

**Real P-Synthetic ChittyID in production:** `03-1-USA-8244-P-2603-0-33`. Conforms to spec §25.6 format `VV-G-LLL-SSSS-T-YM-C-X` (decoded literally: VV=03, G=1, LLL=USA, SSSS=8244, T=P, YM=2603, C=0, X=33). This is one of two distinct chitty_ids ever written to `event_ledger` (the other is whatever the sync daemon also wrote — same one likely; need confirmation).

**Zero writes from any v1 substrate:** Claude Code, OpenClaw, ChatGPT have never written here. Confirms spec §0.1.1 mission is a real net-new piece of work — no substrate is incidentally already speaking the contract.

---

## 5. Hash-chain population (verified)

| Column | Populated | Total |
|---|---:|---:|
| `event_hash` | **0** | 224 |
| `prev_hash` | **0** | 224 |
| `canonical_entity_type` | 218 | 224 |
| `chitty_id` | 218 | 224 |
| `session_id` | 218 | 224 |

The 6 unpopulated rows are the chittyagent-alchemist `SYSTEM_EVENT` writes (no entity context, no canonical type — they're operationally legitimate as fleet-level events).

**Hash chain is schema-only.** The columns exist and are documented, but no writer fills them. Tamper detection is therefore **not currently active**, contrary to what the column comments imply. Either (a) the alchemist/sync-daemon writers were never updated to compute hashes, or (b) hash computation is done at the gateway layer that proxies these writes and the gateway is currently bypassed. v1 must close this gap.

---

## 6. Append-only enforcement (verified)

```sql
SELECT * FROM pg_trigger WHERE tgrelid = 'public.event_ledger'::regclass AND NOT tgisinternal;
SELECT * FROM pg_policy  WHERE polrelid = 'public.event_ledger'::regclass;
```
→ both return zero rows.

```sql
SELECT relrowsecurity FROM pg_class WHERE oid='public.event_ledger'::regclass;
```
→ `false`.

**No append-only enforcement at the database level.** Direct UPDATE/DELETE against the table is not blocked. Spec §6 + §7.2 require append-only; this is a v1 gap. Options:

1. **DB-level enforcement** — add a BEFORE UPDATE/DELETE trigger that raises an exception (recommended; fail-loud, easy to verify with `pg_trigger`).
2. **RLS policy** — enable RLS and write a `FOR UPDATE/DELETE USING (false)` policy (also acceptable; permissions-shaped).
3. **App-layer enforcement only** — accept that any DB-credentialed actor can mutate. Insufficient for spec §6.2 "auditable" promise.

Recommend (1).

---

## 7. `chronicle_events` projection relationship (verified)

`chronicle_events` columns:

```text
id, timestamp, service, action, user_id, user_email, metadata, related_events,
triggered_by, integrations, status, error_message, search_vector, created_at, updated_at
```

Structural differences vs `event_ledger`:

- No `chitty_id`, no `canonical_entity_type`, no `event_hash`/`prev_hash`, no `event_id` text identifier.
- `user_id` is `varchar` (free string), not `uuid` FK.
- Has `updated_at` — **explicitly mutable**. This is fundamentally not a ledger.
- Has `search_vector` (tsvector) — read-optimized projection.
- Has `related_events` (array) and `triggered_by` (varchar) — narrative linking, not hash-chain.

**Verdict:** Chronicle is a search/narrative projection, exactly as spec §6.3/§12 says. It cannot be the spine. There is also **no foreign key** linking `chronicle_events.id` to `event_ledger.event_id`, so projection wiring is currently absent — projecting from `event_ledger` to `chronicle_events` is a v1 buildout, not a reuse.

---

## 8. Migration delta (recommended)

Two migrations needed before Phase 1 write/read loop is buildable.

### 8.1 Migration A — append-only enforcement

```sql
-- migrations/2026XXXXXXXX_event_ledger_append_only.sql
CREATE OR REPLACE FUNCTION public.event_ledger_no_mutation()
RETURNS trigger AS $$
BEGIN
  RAISE EXCEPTION 'event_ledger is append-only (canonical ledger spine)';
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER event_ledger_block_update
  BEFORE UPDATE ON public.event_ledger
  FOR EACH ROW EXECUTE FUNCTION public.event_ledger_no_mutation();

CREATE TRIGGER event_ledger_block_delete
  BEFORE DELETE ON public.event_ledger
  FOR EACH ROW EXECUTE FUNCTION public.event_ledger_no_mutation();
```

### 8.2 Migration B — signature, bonding, payload-hash columns + enum extensions

```sql
-- migrations/2026XXXXXXXX_event_ledger_v1_columns.sql
-- New columns required by spec §9.3 CanonicalEvent
ALTER TABLE public.event_ledger
  ADD COLUMN signer_cid       text,
  ADD COLUMN signature_proof  text,
  ADD COLUMN signature_alg    text,
  ADD COLUMN signature_kid    text,
  ADD COLUMN payload_hash     text,                 -- spec §9.3 payload_hash (separate from event_hash)
  ADD COLUMN payload_ref      text,                 -- spec §9.3 payload_ref (R2/blob URL when payload offloaded)
  ADD COLUMN bond_id          text,                 -- spec §9.4 sponsor bond linkage
  ADD COLUMN linked_event_hash text,                -- spec §9.3 cross-link for bonded dual writes
  ADD COLUMN substrate        text,                 -- spec §9.1 (claude_code|openclaw|chatgpt|chitty_cli|system)
  ADD COLUMN plane            text DEFAULT 'digital',
  ADD COLUMN sequence         bigint,
  ADD COLUMN occurred_at      timestamptz,          -- spec §9.3 distinct from received_at
  ADD COLUMN canon_version    text DEFAULT '1.0';

ALTER TABLE public.event_ledger
  ADD CONSTRAINT event_ledger_substrate_check
    CHECK (substrate IS NULL OR substrate IN ('claude_code','openclaw','chatgpt','chitty_cli','system'));

ALTER TABLE public.event_ledger
  ADD CONSTRAINT event_ledger_plane_check
    CHECK (plane IS NULL OR plane IN ('digital','legal','physical'));

CREATE INDEX idx_event_ledger_substrate ON public.event_ledger (substrate) WHERE substrate IS NOT NULL;
CREATE INDEX idx_event_ledger_bond_id   ON public.event_ledger (bond_id)   WHERE bond_id   IS NOT NULL;

-- Enum extensions (additive; safe in PG)
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'INTERACTION_OBSERVED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'DECISION_COMMITTED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'ACTION_REQUESTED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'ACTION_EXECUTED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'BONDED_ACTION_REQUESTED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'BONDED_ACTION_EXECUTED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'SPONSOR_BOND_CREATED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'SPONSOR_BOND_SEVERED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'SYNTHESIS_COMPLETED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'SURFACE_PACK_READ';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'MIRROR_EXPORTED';
ALTER TYPE public.event_type ADD VALUE IF NOT EXISTS 'AUTHORITY_UPDATED';
```

Both migrations are **non-destructive** (additive columns, additive enum values, triggers do not affect existing rows). The 224 existing rows remain valid; they just lack the new columns (NULL is acceptable for legacy rows).

### 8.3 Hash-chain wiring (no migration; gateway change)

`prev_hash`/`event_hash` columns already exist. ChittyConnect Write Gateway must:

1. Compute `event_hash = sha256(canonical_serialization(event))`.
2. Look up `prev_hash` per `(chitty_id, scope)` chain — `SELECT event_hash FROM event_ledger WHERE chitty_id = $1 AND scope = $2 ORDER BY timestamp DESC LIMIT 1`.
3. Insert with both populated.

This is a Phase 1 ChittyConnect implementation task, not a schema migration.

### 8.4 What NOT to do

- **Do not** drop, rename, or restructure `chitty_ledger_entries`, `ledger_entries`, `event_store`, `events`, `audit_log`. They are stale or empty but may have downstream consumers I have not enumerated. Phase 0 scope is verification, not cleanup.
- **Do not** rewrite the existing 224 rows to add hash chain or signatures. Spec §3.5 / "no fake anything" — backfilling fake hashes is forbidden. Existing rows are pre-v1 history; v1 chain begins at first new v1-format write per chitty_id.
- **Do not** assume `chronicle_events` projection is desired in v1. Spec §6.1 architecture diagram lists it as a downstream projection, but spec §0.1.5 says Beacon publishing and similar projections are out of scope. Leave projection wiring to Phase 4+.

---

## 9. Open items / out of scope for R1

- `context.sessions / context.ledger / context.session_groups` are in Neon project `ChittyOS-Core` (not `ChittyLedger`). Their state will be verified in **R3** (P-Synthetic identity) since they hold session-binding/coordinator state, not the ledger spine.
- `chittycan_sessions` location not yet confirmed. Will be enumerated in R2 (ChittyConnect surface) since it's adjacent to the CLI write path.
- The 6 chittyagent-alchemist rows with NULL `canonical_entity_type` highlight a soft schema gap: should fleet-level system events have a synthetic chitty_id (e.g., a SYSTEM-class entity), or should the column be enforced NOT NULL with a system-entity convention? Recommendation deferred to R3.
- DRL (Distributed Reputation Ledger) storage target remains undefined (spec §28 Q7). Likely a separate table; not present in `event_ledger` as a dedicated stream. Defer to R4 if it falls in outbox/worker scope, otherwise raise in R5 implementation diff.

---

## 10. Verdict for the spec's Phase 0 R1 exit criteria

| Exit criterion | Status |
|---|---|
| Verified table/service name | ✅ `public.event_ledger` in Neon project `ChittyLedger` (`shy-sound-75632194`) |
| Append-only guarantees | ❌ **NOT enforced** — Migration A required |
| Hash-chain support | ⚠️ Columns exist; **0/224 rows populated** — gateway wiring required, no migration |
| Signature/proof fields | ❌ Missing — Migration B required |
| Projection relationship to Chronicle/context | ✅ Verified independent (no FK); Chronicle is mutable narrative projection, not canon. Context tables live in `ChittyOS-Core` and are out of R1 scope |
| Migration diff | ✅ Two migrations specified above (A: append-only triggers; B: signature/bond/substrate/plane columns + enum extensions). Hash-chain is a gateway-layer fix, not a migration |

**R1 GATE: PASS conditional on approval of Migrations A and B.** The canonical spine is real, addressable, and conforms to the spec's P/L/T/E/A canon and ChittyID format. The remaining gaps are well-defined, additive, and non-destructive.

---

## Appendix A — Reproduction queries

All queries below are read-only and were run against project `shy-sound-75632194` (default branch) on 2026-05-02 via Neon MCP.

```sql
-- Inventory
SELECT table_schema, table_name, table_type
FROM information_schema.tables
WHERE table_schema='public'
ORDER BY table_name;

-- Row counts
SELECT 'event_ledger' AS t, COUNT(*) AS rows, MAX(timestamp) AS last_write FROM public.event_ledger
UNION ALL SELECT 'chitty_ledger_entries', COUNT(*), MAX(created_at) FROM public.chitty_ledger_entries
UNION ALL SELECT 'chronicle_events', COUNT(*), NULL FROM public.chronicle_events;

-- Hash population
SELECT
  COUNT(*) FILTER (WHERE event_hash IS NOT NULL) AS event_hash_populated,
  COUNT(*) FILTER (WHERE prev_hash IS NOT NULL)  AS prev_hash_populated,
  COUNT(*) AS total
FROM public.event_ledger;

-- Append-only enforcement
SELECT tgname FROM pg_trigger
WHERE tgrelid = 'public.event_ledger'::regclass AND NOT tgisinternal;
SELECT polname FROM pg_policy WHERE polrelid = 'public.event_ledger'::regclass;
SELECT relrowsecurity FROM pg_class WHERE oid = 'public.event_ledger'::regclass;

-- Enum values
SELECT enumlabel FROM pg_enum
WHERE enumtypid = 'public.event_type'::regtype
ORDER BY enumsortorder;

-- Live writer sample
SELECT event_type, service_name, action, scope, canonical_entity_type, chitty_id, timestamp
FROM public.event_ledger
ORDER BY timestamp DESC LIMIT 10;
```
