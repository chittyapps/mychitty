# Phase 0 R4 — Outbox / Worker Discovery

**Date:** 2026-05-07
**Repos inspected:** `~/projects/github.com/{CHITTYOS,CHITTYFOUNDATION,CHITTYAPPS}` (full tree grep)
**Target table:** `public.event_ledger` in Neon project `ChittyLedger` (id `shy-sound-75632194`, org ChittyFoundation) — 224 rows pre-migration, append-only enforced by Migration A (49a3cf8 → b446ddd lineage), v1 columns added by Migration B.

## Headlines

1. **Exactly one writer class exists today**: `chittyagent-alchemist`. Two `INSERT INTO event_ledger` call sites in `src/index.ts` — `ledgerWrite()` at L58 (12 columns) and the analysis insert at L348 (8 columns). No other source file in CHITTYOS, CHITTYFOUNDATION, or CHITTYAPPS contains an `event_ledger` write.
2. **The writer is duplicated across three repos** with the same `wrangler.jsonc` name (`chittyagent-alchemist`) — deploy collision risk:

   | Repo path | `src/index.ts` LOC | Status |
   |---|---:|---|
   | `CHITTYOS/chittyagent-task/workers/chittyagent-alchemist` | 623 | Same as viewport |
   | `CHITTYOS/chittyentity-viewport/workers/chittyagent-alchemist` | 623 | Same as -task |
   | `CHITTYOS/chittyentity/workers/chittyagent-alchemist` | 721 | Drifted (+98 lines, 3rd INSERT site at L446) |

   Whichever repo was last `wrangler deploy`-ed wins. There is no canonical-location declaration and no CODEOWNERS pointing to one.
3. **The writer writes legacy v0 schema only.** `ledgerWrite()` populates: `id, event_id, event_type, event_severity, service_name, action, chitty_id, scope, group_id, project, metadata, timestamp`. **All v1 columns from Migration B are NULL on every write** — `signer_cid`, `signature_proof`, `signature_alg`, `signature_kid`, `payload_hash`, `payload_ref`, `bond_id`, `linked_event_hash`, `substrate`, `plane`, `sequence`, `occurred_at`, `canon_version`. The hash chain (`prev_hash` / `event_hash`) is also not populated by this writer.
4. **No outbox / queue / retry layer exists.** Alchemist writes synchronously via `postgres(env.HYPERDRIVE.connectionString)` inside the request path (`async function ledgerWrite`). On failure: the row is lost. There is no transactional outbox table, no Cloudflare Queue, no Durable Object buffer, and no idempotency key. v1 §10.5 (bonded dual-write) is **not implementable with the current writer surface**.
5. **`chittyagent-orchestrator` reads only.** L685 in all three repos: `FROM event_ledger` (3 SELECT sites). Not a writer. Cannot serve as a v1 producer without new code.
6. **`chittyledger` service does not write `event_ledger`.** `CHITTYFOUNDATION/chittyledger/api/src/index.ts:214` writes to `public.chitty_ledger_entries` — a different table, in a different schema purpose (per-entity custody chain entries). The service exposes `POST /entries` under `authMiddleware` but is unrelated to the canonical event spine.
7. **`chittyconnect` does not write `event_ledger`.** Confirmed in R2 (it is a router/proxy). Grep across `CHITTYOS/chittyconnect` returns zero hits for `event_ledger`.
8. **`chittyschema` ships generated types and Zod validators for the table** at `CHITTYFOUNDATION/chittyschema/identity/src/{types,validators}/chittyledger/event_ledger.ts`, but the alchemist writer uses raw template-literal SQL and does not import them. **Schema drift between generated validators and the actual write payload is not caught at compile time.**
9. **The production actor `03-1-USA-8244-P-2603-0-33` is not in any source.** Full-tree grep across `~/projects/github.com` returns zero hits. Minting is runtime — by `chittyid` VRF (per R3), not by any `event_ledger` writer. **No event_ledger writer mints actors**; events reference `chitty_id` but cannot create it. R3's recommended `context.entities` population is the only path for actor provenance.
10. **Sibling tables exist in a different Neon project**, not in `ChittyLedger`. `ChittyOS-Core` (per R3, project id `restless-grass-40598426`) holds `public.chronicle_events`, `public.chittycan_events`, `public.chronicle_failed_events`, `public.chronicle_legal_events`, `public.chronicle_quality_events`, `public.scope_events`, `public.service_registration_events`, plus `context.ledger` and `entities.events`. **These are parallel telemetry pipelines, not consumers or producers of `event_ledger`.** Cross-project mirroring is not implemented.

## What this means for v1

- **The substrate has zero v1-compliant writers.** Every byte of v1 schema added by Migration B is currently unused by code. Phase 1 must either (a) build a new v1 gateway and route all new writes through it, or (b) upgrade alchemist in place. Option (a) is cleaner — option (b) requires adding signing-key custody, bond registry access, payload hashing, and sequence allocation to a worker that today does pattern analysis.
- **Alchemist's existing 224+ legacy rows must be tagged `substrate IS NULL` (untagged legacy)** and excluded from v1 chain verification. The constraint added in Migration B (`substrate_check`) already permits NULL — so backward-compat is fine, but Phase 1 must add a discriminator query (`WHERE canon_version = '1.0'`) on every consumer.
- **Sequence allocation is undefined.** v1 §9.3 says `sequence` is "per-(chitty_id, scope) monotonic, populated by gateway at write time." No code allocates this today. Cannot be done in alchemist's current shape (no transactional read-then-insert).
- **Bond enforcement is undefined.** v1 §9.4/§10.5 require `bond_id` + `linked_event_hash` together. Migration B adds the CHECK constraint but no code populates either. There is no `sponsor_bond` table or service yet.
- **Signing is undefined.** No signing-key flow exists for `signer_cid`/`signature_proof`. v1 §11.2 says "format defined by ChittyConnect signing model" — but ChittyConnect's signing surface (per R2 findings) is OAuth/HMAC for service auth, not event signing. Gap.

## Decisions needed for R5 / Phase 1

| # | Decision | Why it matters |
|---|---|---|
| D1 | Consolidate alchemist to **one canonical repo** OR formalize the 3-copy split with CODEOWNERS | Today: silent deploy collisions, drift between -task/-viewport (623) and chittyentity (721) |
| D2 | v1 producer model: **dedicated gateway service** OR **upgrade alchemist in place** | Determines blast radius. Gateway is cleaner; alchemist-in-place reuses existing Hyperdrive binding |
| D3 | Sequence allocation: **PostgreSQL serial on insert** (per chitty_id+scope unique index) OR **gateway-side advisory lock** | Determines whether sequence is gateway-only or DB-enforced |
| D4 | Where `sponsor_bond` lives: **new table in ChittyLedger** OR **new service (chittybond)** OR **column on event_ledger** | Required before any bonded action can be written |
| D5 | Signing custody: **ChittyAuth** (already issues tokens) OR **ChittyConnect** (already proxies) OR **new chittysigner** | Spec defers to "ChittyConnect signing model" but that model does not yet exist |
| D6 | Legacy alchemist row strategy: **leave NULL substrate** OR **backfill `substrate='legacy_pre_v1'`** OR **emit a compaction event marking the cutover** | Affects every consumer's v1 query shape |

## Cross-references

- R1 (Ledger spine) — confirms 224 rows, append-only enforced, v1 columns present.
- R2 (ChittyConnect routes) — confirms ChittyConnect is a router; not a writer.
- R3 (P-Synthetic identity) — confirms no DB persistence of actor subtype today; recommends populating `context.entities` in R5.
- R5 (planned) — must consume D1–D6 above before proposing the v1 gateway shape.

## R4 status

**Complete.** Today's substrate has exactly one writer class, three repo copies, zero v1 column population, and no outbox. The producer surface that v1 assumes does not yet exist. Six decisions (D1–D6) gate Phase 1 implementation. None of them require user-side credential work; all are repo-shape decisions answerable from the spec.
