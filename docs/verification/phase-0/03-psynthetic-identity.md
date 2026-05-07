# Phase 0 R3 — P-Synthetic Identity Verification

**Date:** 2026-05-07
**Repo inspected:** `/home/ubuntu/projects/github.com/CHITTYFOUNDATION/chittyid/`
**Neon project queried:** `ChittyOS-Core` (id `restless-grass-40598426`, db `neondb`)

## Headlines

1. **Format `VV-G-LLL-SSSS-T-YM-C-X` is canonical and confirmed across 6 source locations** — `src/config/index.js:64`, `src/index-refactored.js:271`, `src/services/validation.js:27`, `src/api/index.js:202`, `src/services/vrf-generator.js:10`, `src/integrations/chittyrouter-gateway.js:31`. Comment block in `vrf-generator.js:10-19` decodes each segment.
2. **`P/L/T/E/A` is correctly enforced** in validator regex (`src/services/validation.js:62` → `/^[PLTEA]$/`) and TypeScript validator (`src/workers/chittyid-validator.ts:33`). Config map at `src/config/index.js:79` lists all 5 with proper names. **One stale doc-comment in `vrf-generator.js:14`** still says `Type (P/L/T/E)` — missing A. Cosmetic only; runtime allows A.
3. **Validator regex disagrees with production IDs.** `src/workers/chittyid-validator.ts:36`: `/^(\d{2})-([A-Z])-([A-Z]{3})-(\d{4})-([PLTEA])-(\d{4})-([L]\d)-(\d{2})$/` expects `Lx` for the trust level slot. Production ID from R1 is `03-1-USA-8244-P-2603-0-33` — trust level is bare `0`, not `L0`. **The TS validator would reject every production ChittyID.** The JS validator (`src/services/validation.js`) does not have this mismatch (uses `[PLTEA]` only).
4. **G slot also disagrees.** `vrf-generator.js:78` hardcodes `domain = "C"` (ChittyCorp), but production has `G = "1"` (a digit, not a letter). Either the production minter is a different code path, or the VRF generator has not been used to produce the 225 ledger rows.
5. **`P-Synthetic` is a code comment, not a persisted attribute.** `src/pipeline/index.js:417-418`:
   ```
   context: "P",    // Contexts are Person (P, Synthetic) — actors with agency
   agent:   "P",    // Agents are Person (P, Synthetic) — actors with agency
   ```
   No subtype column exists in `context.entities` or `entities.people`. The Natural / Synthetic / Legal distinction lives only as developer-facing comments. **There is no DB-level way to query "all P-Synthetic IDs".**
6. **`context.*` and `entities.*` tables in ChittyOS-Core are EMPTY.** Schema exists; data does not.

## ChittyOS-Core schema state (live query)

Schemas present: `chico_concierge, chittychat, chittyinventory, chittyleads, chittymemory, context, core, entities, foundation, infra, neon_auth, product, protected, public, storage, verification`.

| Schema.Table | Columns of interest | Row count |
|---|---|---:|
| `context.entities` | id, **chitty_id**, project_path, workspace, **support_type**, organization, anchor_hash, signature, issuer, trust_score, trust_level, status, ledger_head, ledger_count, last_activity, total_sessions, total_tool_uses | **0** |
| `context.sessions` | — | **0** |
| `context.ledger` | — | **0** |
| `context.heartbeats` | — | **0** |
| `entities.people` | chitty_id, owner_chitty_id, name, email, metadata (jsonb), created_at, updated_at | **0** |
| `entities.events` | — | **0** |

`context.entities.support_type` is a varchar(8 mod) — likely the closest thing to a Person subtype field, but unused (no rows). No CHECK constraint observed in column shape; would need a follow-up to enumerate allowed values.

## Where the live P-Synthetic ID actually lives

Per R1: `03-1-USA-8244-P-2603-0-33` appears in Neon project **`ChittyLedger`** (`shy-sound-75632194`), `public.event_ledger.actor_chitty_id`, with `actor_type = 'P'` enforced by the P/L/T/E/A CHECK constraint. **The identity is real and used; the supporting context tables in ChittyOS-Core are empty placeholders.**

Implications:
- The 225 production rows in `event_ledger` reference an actor whose canonical metadata record does not exist anywhere we've inspected. There is no `context.entities` row, no `entities.people` row, no `chittycontext/entities/{chittyId}/identity.json` cross-checked yet.
- The "P-Synthetic" assertion is purely conventional — based on actor_chitty_id type-letter `P` and the comment-only convention that ChittyOS contexts/agents are Synthetic.

## Decoding the canonical actor's ID

`03-1-USA-8244-P-2603-0-33` parsed against config decoders:
| Segment | Value | Meaning (from `src/config/index.js`) |
|---|---|---|
| VV | 03 | Version 03 |
| G | 1 | Region 1 (`North America`) — NOTE: VRF generator emits `C` here for ChittyCorp; the digit-form must come from a different minter |
| LLL | USA | Jurisdiction (USA) |
| SSSS | 8244 | VRF-derived sequential |
| T | P | Person |
| YM | 2603 | Year=26, Month=03 → 2026-03 |
| C | 0 | Trust L0 (Unverified) |
| X | 33 | Mod-97 checksum |

The `G` slot is documented two different ways across the code:
- `vrf-generator.js:13`: "Domain (C=ChittyCorp, E=Error, F=Fallback)"
- `validation.js:31` destructure names it `region` (single-letter)
- `config/index.js:60-77` defines a **regions** map keyed by digit `1`-`9`

**Production uses the digit-region form**, not the letter-domain form. The VRF generator code is out of sync with the live minter.

## Trust level for the canonical actor

`trust_level = 0` (L0 - Unverified). Phase 0 spec implicitly assumes the substrate-writer is trusted. **Either (a) the actor needs trust elevation before being used as a signed-event signer, or (b) the contract permits L0 actors to write substrate events and trust gating happens elsewhere.** The spec §5 amendment did not specify this; flagging for R5.

## P-Synthetic representation gap (key finding for v1)

To make "P-Synthetic" a queryable, governable concept (which v1 needs — only synthetic actors can write substrate events on behalf of a host operator), we need persisted subtype. Options:

| Option | Where | Cost | Tradeoff |
|---|---|---|---|
| (a) Add `actor_subtype` to `event_ledger` | new column on canonical spine | Migration C | Spine-local, doesn't help non-event consumers |
| (b) Populate `context.entities` with a row per actor + subtype column | new column on `context.entities` | Migration in ChittyOS-Core + backfill | Cleanest — central identity table, currently empty/unused |
| (c) Use `support_type` field already on `context.entities` | populate existing field | No DDL | Repurposes ambiguous field; needs CHECK constraint + canon citation |
| (d) Convention-only (status quo) | code comments | $0 | What we have today; not enforceable |

Recommendation for R5: **(b) + (a)** — populate `context.entities` as the source of truth for actor metadata (subtype, sponsor, trust), and denormalize `actor_subtype` onto `event_ledger` so spine queries don't require a join. Both should be added in Migration C alongside the canon citation.

## Pending follow-ups for R4 and R5

- R4 (Outbox / Worker discovery) needs to identify which writer minted `03-1-USA-8244-P-2603-0-33` to determine which code path is the canonical minter (likely not the VRF generator, given the G-slot mismatch).
- R5 (Implementation Diff) must reconcile (i) VRF generator's letter-G vs production digit-G, (ii) TS validator's `Lx` regex vs JS validator's bare-digit format, (iii) docstring drift (`P/L/T/E` missing A in vrf-generator.js:14), (iv) populate context.entities with the canonical actor.

## R3 status

**Complete.** P-Synthetic is conventional, not enforced. The identity in production is real; its supporting metadata tables are empty. Multiple internal validator/generator inconsistencies surfaced — none block Phase 0 progression but all need addressing in R5.
