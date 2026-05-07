# Phase 0 R5 — Implementation Diff

**Date:** 2026-05-07
**Inputs:** R1 (ledger spine), R2 (chittyconnect routes), R3 (P-Synthetic identity), R4 (outbox/workers)
**Spec:** `docs/specs/mychitty-v1-light-the-substrate.md`
**Spine project:** `ChittyLedger` (`shy-sound-75632194`), table `public.event_ledger`. Default branch `br-steep-fog-ae9tdd66`. Migrations A+B verified on branch `br-fancy-art-aevxcl6o`; **not yet applied to default**.

## 0. Verdict

The spec's runtime assumptions are partially refuted by R1–R4. **No surface end-to-end satisfies v1 today.** The schema can be made v1-compliant by applying Migrations A+B to the default branch (DDL-only, additive). The *write path*, *signing*, *sequencing*, *bonding*, *outbox*, *synthesis*, and *read-back* have no implementations and must be built from the gateway down. Identity provenance is conventional, not enforced.

**Phase 0 STOP-GATE remains in effect for everything except the migration apply.** Phase 1 cannot start until D1–D6 (R4) are decided.

## 1. Component-by-component diff

Legend: ✅ matches spec / ⚠ partial / ❌ missing / 🟡 needs decision

### 1.1 Canonical spine — `event_ledger` (spec §7.2)

| Spec requirement | Verified state | Status | Source |
|---|---|---|---|
| Append-only | Triggers added in Migration A; verified on branch | ⚠ on default until apply | R1, A |
| P/L/T/E/A enforcement on actor_type | CHECK constraint live on default | ✅ | R1 |
| Hash-chain columns (`prev_hash`, `event_hash`) | Columns exist; **0/225 rows populated** | ⚠ | R1 |
| v1 columns (signer_cid, signature_proof, signature_alg, signature_kid, payload_hash, payload_ref, bond_id, linked_event_hash, substrate, plane, sequence, occurred_at, canon_version) | Added by Migration B; verified on branch | ⚠ on default until apply | R1, B |
| 18 canonical event types from §9.3 | 12 missing types added by Migration B; verified | ⚠ on default until apply | R1, B |
| Hash chain populated by gateway at write | No gateway exists | ❌ | R4 |
| Sequence monotonic per (chitty_id, scope) | Column added; **no allocator code** | ❌ | R4 |
| Bonded entry pair (bond_id + linked_event_hash) | CHECK present; **no producer** | ❌ | R4 |

**Action:** apply Migrations A+B to `br-steep-fog-ae9tdd66`. After apply, the spine is *schema-ready*; everything else is code.

### 1.2 ChittyConnect Write Gateway (spec §7.1, §10)

| Spec requirement | Verified state | Status |
|---|---|---|
| `mint_sponsored_entity()` | not implemented anywhere | ❌ |
| `bind_session()` | not implemented | ❌ |
| `unbind_session()` | not implemented | ❌ |
| `write_event()` | not implemented in ChittyConnect; alchemist writes legacy v0 only | ❌ |
| `write_bonded_event()` | not implemented; no bond table | ❌ |
| `read_last_events()` | orchestrator has SELECT but not exposed as MCP | ⚠ |
| `read_surface_pack()` | not implemented; spec §9.9 has no producer | ❌ |
| `export_local_mirror()` | not implemented | ❌ |
| Substrate auth (Claude Code, OpenClaw, ChatGPT) | OAuth/HMAC service auth exists; no per-substrate caller binding | ⚠ |
| Signing of events | no signing-key custody anywhere; spec defers to "ChittyConnect signing model" which does not exist | ❌ |
| Direct DB write to event_ledger | ChittyConnect does **not** touch event_ledger; closest write is `chronicle_events` (parallel pipeline) | ❌ |

**Decision required (D2 from R4):** dedicated v1 gateway service vs. upgrade alchemist in place. Either way the 9 MCP tools above are net-new code.

### 1.3 P-Synthetic identity (spec §3.3, §4.1, §10.2)

| Spec requirement | Verified state | Status |
|---|---|---|
| ChittyID format `VV-G-LLL-SSSS-T-YM-C-X` | confirmed in 6 source locations | ✅ |
| P/L/T/E/A enforced in DB and validators | enforced in JS validator + event_ledger CHECK | ✅ |
| TS validator parses production IDs | **TS validator regex requires `Lx` for trust slot; production has bare digit `0`** — would reject every prod ID | ❌ |
| G-slot canonical encoding | VRF generator hardcodes letter `C`; production has digit `1` — divergent minters | ❌ |
| `P-Synthetic` as queryable subtype | exists only as code comment (`src/pipeline/index.js:417`); no DB column, no CHECK | ❌ |
| `context.entities` populated for active actor | **0 rows** in ChittyOS-Core | ❌ |
| `entities.people` populated for active actor | **0 rows** | ❌ |
| Sponsor bond record | no `sponsor_bond` table anywhere | ❌ |
| Reflection imprint hash | concept-only in spec | ❌ |

**Action:** D5 (signing custody) overlaps here. Before any v1 write, an actor row must exist with subtype = `Synthetic`. Recommend `context.entities.support_type` becomes the subtype with a CHECK against `('Natural','Synthetic','Legal')`, and is required for any `P` actor referenced in `event_ledger`.

### 1.4 Substrate adapters (spec §2.2, §8.1)

| Substrate | Extract path | Status |
|---|---|---|
| Claude Code | session JSONL, plans, todos, tool calls — extractor not built | ❌ |
| OpenClaw | channel msgs/threads/tasks — extractor not built | ❌ |
| ChatGPT | conversation turns/tools/artifacts — extractor not built | ❌ |
| Chitty CLI/hooks | `~/.claude/hooks/*` exist and log to Neon (not event_ledger) | ⚠ |

**Status:** zero of three target substrates have written zero rows ever to the canonical spine. The "substrate is dark" finding is confirmed for v1 substrates.

### 1.5 Durable synthesis outbox (spec §7.3)

| Spec requirement | Verified state | Status |
|---|---|---|
| Outbox table or queue | **does not exist** | ❌ |
| Idempotent by `event_hash` | n/a — no producer or consumer | ❌ |
| Retry policy + dead-letter | n/a | ❌ |
| Queue depth observable | n/a | ❌ |

### 1.6 Synthesis Worker → Refined Shards → SurfacePack (spec §7.4–7.6, §8.3–8.5, §9.6–9.9)

All ❌. No `Fragment`, `SixRScore`, `RefinedShard`, `SurfacePack` producers or storage. Spec §9.6–9.9 contracts have no schema mapping. v1 READ path is undefined beyond "direct Neon read".

### 1.7 Local mirrors (spec §7.6)

| Mirror | State |
|---|---|
| `~/.claude/chittycontext/` | exists; `sync_queue.json` has 307 stale entries; **drainer-rotted** |
| `~/.openclaw/workspace/memory/` | not yet inspected on this VM (was Mac-side per checkpoint) |
| `mychitty.com/user-state/` | not implemented |

Mirrors must flush through the gateway (none exists) — currently they accumulate or are silently dropped.

## 2. Schema diff (post-Migration B vs. spec §9.3)

After Migrations A+B apply to default, the table aligns with `CanonicalEvent` except:

| `CanonicalEvent` field | Spine column | Status |
|---|---|---|
| `event_id` | `event_id` | ✅ |
| `entity_cid` | `actor_chitty_id` | ✅ (rename, not mismatch — spine name predates spec) |
| `session_id` | — | ❌ **missing as a typed column**; lives in `metadata` jsonb today |
| `event_type` | `event_type` (enum extended) | ✅ post-apply |
| `substrate` | `substrate` | ✅ post-apply |
| `plane` | `plane` | ✅ post-apply (enforced 'digital' for v1) |
| `occurred_at` | `occurred_at` | ✅ post-apply |
| `received_at` | `timestamp` | ✅ (rename) |
| `sequence` | `sequence` | ✅ post-apply (column only; no allocator) |
| `prev_hash` | `prev_hash` | ✅ |
| `event_hash` | `event_hash` | ✅ |
| `signer_cid` | `signer_cid` | ✅ post-apply |
| `signature_proof` | `signature_proof` | ✅ post-apply |
| `raw_event_id` | — | ❌ not in spine; lives in `metadata` |
| `payload_hash` | `payload_hash` | ✅ post-apply |
| `payload_ref` | `payload_ref` | ✅ post-apply |
| `payload_min` | — | ❌ not modeled; conflated with `metadata` |
| `bond_id` | `bond_id` | ✅ post-apply |
| `linked_event_hash` | `linked_event_hash` | ✅ post-apply |
| `projection_targets` | — | ❌ no column; would live in `metadata` |
| `canon_version` | `canon_version` | ✅ post-apply |

**Gaps:** `session_id`, `raw_event_id`, `payload_min`, `projection_targets` are not first-class columns. Phase 1 must either (a) add Migration C with these columns, or (b) accept them in `metadata` jsonb with a documented schema and queryable indexes.

## 3. Authority/Trust hooks (spec §4.3)

| Hook | Verified state |
|---|---|
| `authority.updated` event type | added by Migration B; no producer |
| Trust signal ingestion | no v1 surface; ChittyTrust exists at tier 0 but is not wired to event_ledger |
| Six-R score storage | no schema |
| Granted vs. earned authority distinction | concept-only |

## 4. STOP-GATE status (spec §26)

The spec's §26 STOP-GATE was overridden by user "remediate" for R1 schema work only. Everything else remains gated. R5 confirms that **the gate cannot be lifted**: the v1 producer surface, signing model, bond registry, outbox, synthesis worker, and read path are all unimplemented. No code path can produce a v1-compliant event today.

## 5. Minimum viable proof (spec §0.1.2) reachability

Spec §0.1.2 requires: one P-Synthetic entity writes signed events from all three substrates into one canonical ledger spine, then rehydrates.

| Dependency | Status |
|---|---|
| Spine schema | ⚠ ready post Mig-A+B apply on default |
| One P-Synthetic actor with subtype enforced | ❌ |
| Gateway with `bind_session` + `write_event` | ❌ |
| Signing key custody | ❌ |
| Sequence allocator | ❌ |
| 3 substrate adapters | ❌ |
| Outbox + synthesis worker | ❌ |
| SurfacePack read | ❌ |

**Estimated work to MVP:** all of Phase 1 (gateway, signer, sequencer, 3 adapters), most of Phase 2 (outbox + synth worker), part of Phase 3 (SurfacePack reader). Phase 0 ends at the migration apply.

## 6. Phase 1 entry checklist (decisions blocking start)

These are the R4 D1–D6 decisions plus three new ones surfaced here:

| # | Decision | Owner of decision | Blocking what |
|---|---|---|---|
| D1 | Consolidate alchemist to one repo OR formalize 3-copy with CODEOWNERS | user | every future event_ledger write |
| D2 | New gateway service vs. upgrade alchemist in place | user | gateway scaffolding |
| D3 | Sequence allocation: DB serial vs. gateway advisory lock | user | sequence column usability |
| D4 | sponsor_bond location: new table in ChittyLedger / new service / column on event_ledger | user | bonded events |
| D5 | Signing custody: ChittyAuth / ChittyConnect / new chittysigner | user | every event with signer_cid |
| D6 | Legacy row strategy: leave substrate NULL / backfill / cutover event | user | every v1 consumer query |
| D7 | TS validator regex fix (R3): drop the `L` prefix on trust slot to match production IDs | implementer | every consumer using TS validator |
| D8 | P-subtype enforcement: add `support_type` CHECK to `context.entities` and require population before any v1 write | user | identity provenance |
| D9 | session_id / raw_event_id / payload_min / projection_targets: column-promote (Migration C) vs. typed metadata jsonb | user | future schema migrations |

## 7. Recommended next-step ordering

1. **Apply Migrations A+B to default `br-steep-fog-ae9tdd66`.** Additive-only, compatible with live writers (alchemist, sync-daemon). Closes the schema gap. *Awaits user "go default".*
2. Resolve D1 (consolidate alchemist) — fix deploy collision before any new writer lands.
3. Resolve D2 (gateway shape) — pick the v1 producer architecture.
4. Resolve D5 (signing custody) — every other producer-side decision depends on this.
5. Build Phase 1 in this order: actor row + subtype CHECK (D8) → signer (D5) → gateway scaffold (D2) → sequence allocator (D3) → `bind_session` + `write_event` end-to-end with one substrate adapter (Claude Code) → bonded write + bond registry (D4) → second adapter (OpenClaw) → third (ChatGPT).
6. Phase 2: outbox table + synthesis worker.
7. Phase 3: SurfacePack reader.

## 8. Cross-references

- R1 — `01-ledger-spine.md` — schema verified; columns exist post-Mig-B
- R2 — `02-chittyconnect-routes.md` — ChittyConnect is a router, not a spine writer
- R3 — `03-psynthetic-identity.md` — identity is conventional; TS validator broken vs. production
- R4 — `04-outbox-workers.md` — single legacy writer, no outbox, 9 v1 columns unused by code
- Migrations — `migrations/0001_event_ledger_append_only.sql`, `migrations/0002_event_ledger_v1_columns.sql`

## 9. Phase 0 closure criteria

Phase 0 is complete when:

1. ✅ R1–R5 reports filed in `docs/verification/phase-0/`.
2. ⏳ Migrations A+B applied to `br-steep-fog-ae9tdd66` and verified with the same 6 checks that passed on `br-fancy-art-aevxcl6o`.
3. ⏳ User accepts D1–D9 decisions or defers them as Phase 1 entry blockers.

After (2) and (3), Phase 0 closes and STOP-GATE lifts for the items the user has decided.
