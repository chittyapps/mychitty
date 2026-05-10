# D3 — Sequence Allocation

**Status:** PROPOSED — awaiting user decision
**Date:** 2026-05-10
**Blocks:** v1 INSERT path on `ledger.chitty.cc/v1/*`
**Depends on:** D2 ACCEPTED (gateway lives in chittyledger Worker)
**Spec source:** Migration B `event_ledger.sequence` COMMENT — *"Per-(chitty_id, scope) monotonic sequence number; populated by gateway at write time"* — and partial index `idx_event_ledger_chain_replay ON (chitty_id, scope, sequence) WHERE sequence IS NOT NULL`.

## Discovery

| Surface | State |
|---|---|
| `event_ledger.sequence` column | exists, NULLable, BIGINT (Mig B applied to default 2026-05-09) |
| `idx_event_ledger_chain_replay` | exists on `(chitty_id, scope, sequence) WHERE sequence IS NOT NULL` — index only, **not UNIQUE** |
| Legacy `chitty_ledger_entries.sequence_number` | BIGSERIAL, *global* (not per-chain). Allocator at `chittyledger/api/src/index.ts:197` reads MAX then INSERTs — race-prone under concurrency, but the existing single-writer service has not hit it. |
| Other writers of `event_ledger.sequence` | none (R4) — column is currently 100% NULL across 251 rows |

**No per-chain UNIQUE constraint exists yet.** D3 must answer: does one get added, and what allocator pattern fills the column.

## What needs to exist

For each `(chitty_id, scope)` pair, the gateway must produce a strictly monotonic, gap-allowed BIGINT starting at 1. Two writers in flight for the same chain must not collide. The chosen mechanism is the canonical replay primitive — `read_last_events` and chain verification both depend on it being correct.

## Options

### Option A — Postgres advisory lock + read-then-insert (RECOMMENDED)

```sql
-- inside the gateway's INSERT transaction:
SELECT pg_advisory_xact_lock(hashtext(chitty_id || '|' || scope));
INSERT INTO event_ledger (..., sequence)
SELECT ..., COALESCE(MAX(sequence), 0) + 1
FROM event_ledger
WHERE chitty_id = $1 AND scope = $2;
-- lock auto-released at COMMIT
```

**Pros:**
- Race-free by construction; no retry loop.
- No schema change — works against the column we already have.
- `pg_advisory_xact_lock` releases at COMMIT/ROLLBACK; no leak risk.
- Hyperdrive (used by chittyledger) supports advisory locks transparently.
- Determinism is easy to reason about: at any moment, exactly one transaction holds the (chitty_id, scope) lock.

**Cons:**
- Lock contention if two writers hammer the same chain. v1 throughput target is low (one substrate, one entity) — non-issue. Future-proofing: per-chain lock granularity scales with chains, not with throughput.
- `hashtext()` is 32-bit; collisions across distinct (chitty_id, scope) pairs are theoretically possible. Mitigation: use 64-bit `(hashtextextended(...))` or two 32-bit lock keys (advisory locks accept two int4s). Cheap.

### Option B — UNIQUE constraint + INSERT...SELECT + retry on conflict

```sql
-- one-time:
ALTER TABLE event_ledger
  ADD CONSTRAINT event_ledger_chain_seq_uniq UNIQUE (chitty_id, scope, sequence);

-- per write:
INSERT INTO event_ledger (..., sequence)
SELECT ..., COALESCE(MAX(sequence), 0) + 1
FROM event_ledger WHERE chitty_id=$1 AND scope=$2
ON CONFLICT (chitty_id, scope, sequence) DO NOTHING
RETURNING sequence;
-- if RETURNING is empty, retry up to N times
```

**Pros:**
- DB-enforced invariant — independent of allocator code.
- Slightly faster average case (no lock acquisition).

**Cons:**
- Requires a new Migration C (UNIQUE constraint). Existing 224 legacy rows have `sequence IS NULL` — UNIQUE allows NULL, fine. New v1 rows must populate.
- Retry loop in gateway code adds complexity and latency tail.
- UNIQUE constraint conflicts with append-only trigger semantics? No — UPDATE is blocked by Migration A trigger, but UNIQUE is checked at INSERT time, which is allowed.

### Option C — Cloudflare Durable Object per (chitty_id, scope)

Per-chain DO holds `next_sequence`; gateway calls DO before INSERT.

**Pros:**
- Atomic by DO contract; no DB locking.

**Cons:**
- Two state surfaces (DO state + DB column) — risk of drift if DO state is lost or rebuilt from a stale read.
- Adds a network hop + DO cold-start latency.
- DOs are per-account; a DO outage = no events written. Fail-closed is correct, but it adds a failure mode.
- DO sharding unbounded — one DO per (entity × scope) — operational tax.

### Option D — Postgres SEQUENCE per chain

Create one `SEQUENCE seq_<chitty_id>_<scope>` per chain, used at INSERT.

**Pros:** truly atomic, no contention.
**Cons:** unmanageable proliferation (thousands of sequences over time), DDL on every new chain. Rejected.

### Option E — Global BIGSERIAL (legacy chittyledger pattern)

Drop the per-chain requirement, use a single global counter.

**Cons:** violates spec + Migration B comment. Rejected.

## Recommendation

**Option A — Postgres advisory lock + read-then-insert with `pg_advisory_xact_lock`.**

Reasoning:
1. **No schema change.** The column is there, the partial index is there, no Migration C needed.
2. **No retry loop.** Determinism beats average-case latency for v1's low throughput.
3. **No new state surface.** All state in Postgres. DO option (C) introduces a second source of truth and a failure mode.
4. **Locks are scoped to the transaction.** No leak risk, no manual release.
5. **Hyperdrive-compatible.** chittyledger already uses Hyperdrive; advisory locks pass through.

Optionally add the UNIQUE constraint from Option B as a *belt-and-suspenders* invariant — even if the lock works, the UNIQUE protects against future code paths that might bypass the gateway. Cost: one Migration C, additive.

## Implementation sketch

```ts
// chittyledger/api/src/v1/sequence.ts
export async function allocateSequence(
  sql: NeonSql,
  chittyId: string,
  scope: string,
): Promise<bigint> {
  // call inside an open tx; lock released at commit/rollback
  await sql`SELECT pg_advisory_xact_lock(hashtextextended(${chittyId} || '|' || ${scope}, 0))`;
  const [{ next }] = await sql`
    SELECT COALESCE(MAX(sequence), 0) + 1 AS next
    FROM event_ledger
    WHERE chitty_id = ${chittyId} AND scope = ${scope}
  `;
  return next;
}

// chittyledger/api/src/v1/ledger-write.ts
await sql.begin(async (tx) => {
  const seq = await allocateSequence(tx, event.entity_cid, event.scope);
  const prevHash = await fetchPrevHash(tx, event.entity_cid, event.scope);
  const eventHash = computeEventHash({ ...event, sequence: seq, prev_hash: prevHash });
  await tx`INSERT INTO event_ledger (..., sequence, prev_hash, event_hash, ...) VALUES (..., ${seq}, ${prevHash}, ${eventHash}, ...)`;
  await enqueueOutbox(tx, event.event_id, eventHash);
});
```

## Open questions

1. **Add the UNIQUE constraint (belt-and-suspenders) or not?** Default: **yes**, ship as Migration C alongside Phase 1 work — additive, cheap, protects against future code paths.
2. **Scope vocabulary.** Migration B's `event_ledger_scope_check` already constrains scope to `{private,shared,project,global}`. Confirmed via prior apply (migration audit row `788c267e…` used `scope='global'`). Per-chain = (chitty_id, this scope). Acceptable, or do we need a finer scope (e.g., per-substrate)? Default: **acceptable as-is** — the current 4 scopes give coarse-but-sufficient chain partitioning for v1.
3. **prev_hash linkage.** Is `prev_hash` per-chain (= last event_hash where chitty_id=X AND scope=Y) or global (= last event_hash overall)? The spec implies per-chain. Default: **per-chain**, same partition as `sequence`. Document explicitly in the gateway code.
