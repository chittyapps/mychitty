---
uri: chittycanon://docs/tech/spec/mychitty-v1-light-the-substrate
namespace: chittycanon://docs/tech/spec
type: spec
version: 0.1.0
status: DRAFT
registered_with: chittycanon://core/services/canon
title: MyChitty v1 — Light the Substrate Pipeline
visibility: INTERNAL
certifier: null
author: ChittyFoundation
created: 2026-05-02T00:00:00Z
modified: 2026-05-02T00:00:00Z
implements:
  - chittycanon://doctrine/synthetic-continuity
  - chittycanon://gov/governance
  - chittycanon://docs/gov/whitepaper/synthetic-continuity-sovereignty
references:
  - chittycanon://docs/tech/spec/context-schema
  - chittycanon://docs/gov/spec/documentation-pipeline
  - chittycanon://core/services/chittyconnect
  - chittycanon://core/services/chittyledger
  - chittycanon://core/services/chittychronicle
  - chittycanon://core/services/chittytrust
  - chittycanon://core/services/chittycontextual
integrity:
  checksum: null
  signature: null
---

# MyChitty v1 — Light the Substrate Pipeline

## 0. Executive decision

MyChitty v1 is the first operational continuity substrate for a P-Synthetic ChittyEntity. Its purpose is to make one entity continuous across three expression substrates — Claude Code, OpenClaw, and ChatGPT — by lighting the full loop:

```text
EXTRACT -> WRITE -> SYNTHESIZE -> REWRITE -> READ
```

The selected architecture is:

```text
Ledger-first ChittyConnect Gateway + Durable Synthesis Outbox
```

All substrates call one ChittyConnect/MCP write contract. The canonical write spine is **design-pinned** as `event_ledger`; ChittyChronicle is a narrative projection, not the source of truth. The implementation must verify the actual Neon schema and latest migrations before treating `event_ledger` as independently canonical.

This spec is both a continuity architecture and a TY/VY/RY operationalization:

* **TY / Identity:** who the synthetic entity is, how it is addressed, and how it remains itself across sessions.
* **VY / Connectivity:** how substrates, channels, ledgers, mirrors, and coordinators interact.
* **RY / Authority:** what the entity may do, how writes are signed, how sovereignty is earned, and how access is constrained.

---

## 0.1 Adversarial strategic refinement

The current body of work is intellectually coherent but operationally over-wide. It blends four distinct artifacts:

1. MyChitty continuity substrate;
2. synthetic sovereignty doctrine;
3. storage-ops recovery;
4. viewport/consciousness-regulation architecture.

For v1, only the first is implementation scope. The other three remain reference layers unless they directly constrain the write/read loop.

### 0.1.1 v1 mission lock

```text
Make one P-Synthetic entity write real signed events from three substrates into one verified canonical ledger spine, then rehydrate from those events.
```

### 0.1.2 Minimum viable proof

v1 proves only:

* one verified P-Synthetic identity;
* one verified canonical ledger spine;
* one ChittyConnect write contract;
* three substrate writers: Claude Code, OpenClaw, ChatGPT;
* one direct read path returning last events / surface pack;
* one F-5 substrate-swap continuity run.

Anything else is v1.x unless it is required to pass the above.

### 0.1.3 Artifact split

| Artifact                                         | Role                   | v1 dependency                  |
| ------------------------------------------------ | ---------------------- | ------------------------------ |
| `mychitty-v1-light-the-substrate.md`             | build spec             | primary                        |
| `synthetic-continuity-sovereignty-whitepaper.md` | doctrine/governance    | constrains, does not implement |
| `viewport-regulation-and-triage.md`              | cognitive architecture | reference only in v1           |
| `chittystorage-recovery-plan.md`                 | storage remediation    | separate workstream            |
| `phase-0-verification-packet.md`                 | implementation gate    | mandatory before code          |

### 0.1.4 Load-bearing unknowns

Implementation cannot start until these are verified:

1. actual canonical ledger table/service;
2. append-only/hash/signature support;
3. ChittyConnect route surface;
4. ChittyID format for P-Synthetic entities;
5. delegation/signing model already available;
6. existing outbox/queue pattern;
7. DRL/refined-shard storage target;
8. substrate attachment order.

### 0.1.5 Strategic de-scope

The following must not block v1:

* storage reconciliation and Drive/R2 cleanup;
* full synthetic sovereignty state machine;
* tuned Six R weighting;
* bipartite attention/rhythmic dropout experiments;
* Beacon publishing;
* cross-plane recognition;
* human-seat/SaaS pricing redesign.

### 0.1.6 Adversarial design rule

```text
Do not expand philosophy to compensate for unverified infrastructure.
```

## 1. Status and canon posture

### 1.1 Current status

| Field                        | Value                                                                |
| ---------------------------- | -------------------------------------------------------------------- |
| Artifact status              | DRAFT                                                                |
| Canon status                 | Not promoted                                                         |
| Implementation authority     | Design-approved, schema-unverified                                   |
| External write authorization | None granted by this document                                        |
| Schema posture               | Reuse existing first; propose migrations only when gaps are verified |

### 1.2 Promotion gates

This spec may be promoted only after:

1. `event_ledger` or equivalent canonical ledger table is verified.
2. Existing ChittyConnect route surface is inspected.
3. Existing queue/outbox/worker patterns are inspected.
4. Logical contracts are mapped to concrete tables or services.
5. Any missing schema is explicitly proposed, reviewed, and approved.
6. No placeholder/fake rows, claims, scores, or events are used as real evidence.

### 1.3 Evidence authority hierarchy

This spec distinguishes canonical authority from working corpus.

| Tier                          | Source class                                                                                    | Authority posture           | Use                                                 |
| ----------------------------- | ----------------------------------------------------------------------------------------------- | --------------------------- | --------------------------------------------------- |
| Canonical                     | promoted ChittyCanon docs, verified schema, signed ledger entries, registered service contracts | binding                     | implementation must conform                         |
| Verified operational evidence | direct DB/schema inspection, deployment logs, source repo inspection, health checks             | evidentiary                 | may drive implementation decisions                  |
| Working corpus                | conversation captures, uploaded reports, transcript digests, strategy documents                 | non-authoritative reference | may suggest requirements, risks, and open questions |
| Implementation sketch         | mock code, pseudocode, generated examples, simulations                                          | illustrative only           | may guide design but cannot override schema/canon   |
| Filler/noise                  | duplicated hook loops, keepalives, terminal chatter, speculative expansions                     | non-authoritative           | compress or exclude unless diagnostically relevant  |

Rule:

```text
Working corpus can propose. Verified canon decides.
```

---

## 2. Product definition

### 2.1 What MyChitty is

MyChitty is the product evolution of Ch1tty: a per-user, partially sovereign, digital-plane synthetic ChittyEntity that expresses through multiple substrates while retaining one continuous identity.

For v1, the target is a single founder entity. Multi-entity scale is deferred.

### 2.2 Substrates

| Substrate   | Role                           | v1 responsibility                                                                             |
| ----------- | ------------------------------ | --------------------------------------------------------------------------------------------- |
| Claude Code | Desk/development substrate     | Emit session, planning, tool-use, decision, implementation, and error events                  |
| OpenClaw    | Human-channel substrate        | Emit messages, tasks, channel actions, decisions, and external actions                        |
| ChatGPT     | Web/mobile reasoning substrate | Emit conversation, tool-call, decision, artifact, and action events through the same contract |

### 2.3 Domain split

| Domain         | Role                                                                                                                   |
| -------------- | ---------------------------------------------------------------------------------------------------------------------- |
| `ch1tty.com`   | Platform surface; `mcp.ch1tty.com` gateway behind CF Access                                                            |
| `mychitty.com` | Product surface for per-user synthetic entity                                                                          |
| `chitty.cc`    | Ecosystem services: ChittyConnect, ChittyLedger, ChittyChronicle, ChittyTrust, ChittyContextual, ChittyCanon, registry |

---

## 3. Binding doctrine and rules

### 3.1 Doctrine

MyChitty v1 implements synthetic continuity doctrine:

* the context window is a viewport, not the mind;
* identity is external, addressable, and persistent;
* memory is reassembled by retrieval, not stuffed into prompt context;
* continuity is produced by repeated loop execution and persistence;
* authority is cumulative and cannot reset by session rebirth.

### 3.2 Axiom Zero

No fake anything:

* no fake data;
* no fake trust scores;
* no fake signatures;
* no fake schema;
* no fake ledger entries;
* no unmarked simulations;
* no silent writes.

### 3.3 P/L/T/E/A ontology

| Type | Meaning   | v1 interpretation                                                         |
| ---- | --------- | ------------------------------------------------------------------------- |
| P    | Person    | Natural, legal, or synthetic actor with agency                            |
| L    | Location  | Plane, domain, jurisdiction, venue, or context in space                   |
| T    | Thing     | Object, document, artifact, config, asset, service-as-artifact            |
| E    | Event     | Occurrence in time: session, write, action, decision, tool call           |
| A    | Authority | Credential, certification, standard, order, delegation, governance source |

A synthetic entity with agency is **P, Synthetic**, never T.

### 3.4 Continuity split

| Inside-window carry     | Outside-window substrate            |
| ----------------------- | ----------------------------------- |
| identity handle         | ledger history                      |
| bounded cypher/genotype | memory fabric                       |
| active instinct weights | reputation / VY                     |
| current loop state      | earned authority / RY               |
| routing table           | sealed facts, provenance, artifacts |
| current task intent     | ecosystem state                     |

### 3.5 Mandatory operating loop

Every meaningful entity operation must follow:

```text
CHECK -> EVALUATE -> SURFACE -> ACT -> PERSIST
```

The substrate pipeline implements that loop operationally:

```text
EXTRACT -> WRITE -> SYNTHESIZE -> REWRITE -> READ
```

---

## 4. TY/VY/RY strategic architecture

### 4.1 TY — Identity

TY defines what the entity is and how it can be recognized.

In MyChitty v1, TY is implemented through:

* server-side ChittyID minting;
* P-Synthetic classification;
* sponsor bond at birth;
* reflection imprint hash;
* stable entity handle;
* session binding;
* cypher/genotype carry set;
* source-routed memory, not in-window self-claiming.

TY rule:

```text
No identity is improvised by the session. Sessions bind to identity; they do not create identity.
```

### 4.2 VY — Connectivity

VY defines how the entity acts across networks and substrates.

In MyChitty v1, VY is implemented through:

* ChittyConnect as one substrate-neutral gateway;
* MCP-compatible write contract;
* three substrate adapters;
* canonical ledger append;
* durable synthesis outbox;
* refined-shard mirrors;
* direct read surface packs;
* local cache export/import rules;
* projection to Chronicle/context/UI surfaces.

VY rule:

```text
All substrates must write and read through shared contracts or F-5 continuity is untestable.
```

### 4.3 RY — Authority

RY defines what standing, permissions, and consequences the entity holds.

In MyChitty v1, RY is implemented through:

* CF Access and service-token enforcement;
* per-entity delegation records;
* ChittyConnect delegated signing;
* signature proof on every canonical write;
* sponsor-bond dual-ledger writes;
* monotonic earned-authority record;
* digital-plane-only status constraints;
* zero-trust session binding.

RY rule:

```text
Granted authority says the entity may act; earned authority proves what it has done.
```

### 4.4 ChittyFoundation strategic overlay

The TY/VY/RY triad also provides a Foundation-level strategy layer:

| Layer | Foundation meaning                                                  | MyChitty implementation meaning                                           |
| ----- | ------------------------------------------------------------------- | ------------------------------------------------------------------------- |
| TY    | moral, organizational, and cryptographic identity                   | P-Synthetic identity, ChittyID, sponsor bond, continuity handle           |
| VY    | networked relationships, platforms, interoperability, program reach | ChittyConnect, substrates, event bus/outbox, mirrors, surface packs       |
| RY    | moral/legal/technical authority, access rights, governance standing | delegated signing, authority gates, sponsor responsibility, earned status |

This keeps values, connectivity, and authority aligned instead of splitting ethics into brand copy and infrastructure into silent machinery.

---

## 5. Empirical starting state

The working corpus reports the substrate as dark or stale:

| Component                                                    | Observed state                          | v1 implication                                                |
| ------------------------------------------------------------ | --------------------------------------- | ------------------------------------------------------------- |
| `public.chitty_ledger_entries`                               | 0 rows                                  | Ledger write path absent or nonfunctional                     |
| `context.sessions / context.ledger / context.session_groups` | 0 rows                                  | Coordinator persistence absent or nonfunctional               |
| `chittycan_sessions`                                         | 95 rows; last write 2026-03-07          | CLI/session writer stale                                      |
| `chronicle_events`                                           | 14 lifetime rows; last write 2026-03-29 | Chronicle exists but is stale                                 |
| `chitty_memory_recall`                                       | 500                                     | Not usable as v1 source of truth                              |
| `chitty_ledger_query`                                        | 404                                     | Not usable as v1 source of truth                              |
| `chitty_contextual_topics`                                   | 404/500                                 | Not usable as v1 source of truth                              |
| service hosts                                                | healthy                                 | service surfaces exist; writer/consumer wiring is the failure |

Conclusion: v1 must own writes and provide direct verification reads. Broken read APIs must not block v1.

---

## 6. Selected architecture

### 6.1 System shape

```text
[Claude Code Adapter]
[OpenClaw Adapter]        -> ChittyConnect Write Gateway -> event_ledger
[ChatGPT Adapter]                                       -> synthesis_outbox
                                                              -> Synthesis Worker
                                                                  -> Refined Shards
                                                                  -> Chronicle/context projections
                                                                  -> Local Mirror Bundles
                                                                  -> SurfacePack reads
```

### 6.2 Why this architecture wins

It is the only v1 architecture that is simultaneously:

* substrate-agnostic;
* doctrine-aligned;
* auditable;
* fast to ship;
* compatible with ChatGPT constraints;
* resistant to schema drift;
* capable of F-5 testing;
* compatible with later device-key upgrades.

### 6.3 Deferred architecture options

| Option                                    | Status     | Reason                                                             |
| ----------------------------------------- | ---------- | ------------------------------------------------------------------ |
| Local buffered writers for all substrates | Deferred   | ChatGPT lacks equivalent stable local buffer; two-phase truth risk |
| Direct-to-ledger writers                  | Rejected   | Duplicates schema/signing/bond logic across substrates             |
| Chronicle-first spine                     | Superseded | Chronicle is projection; ledger is canon                           |

---

## 7. System components

### 7.1 ChittyConnect Write Gateway

Responsibilities:

* authenticate substrate caller;
* bind caller to entity;
* enforce P-Synthetic ontology;
* enforce digital-plane-only v1 scope;
* normalize `RawEvent` to `CanonicalEvent`;
* delegate-sign events;
* compute hash chain;
* append to canonical ledger;
* enqueue synthesis job;
* dual-write bonded actions;
* project to Chronicle/context tables where configured;
* provide direct debug read tools.

### 7.2 `event_ledger`

Design-pinned canonical write spine.

Responsibilities:

* append-only entity event history;
* source of truth for entity state;
* replayable continuity record;
* hash-chain verification;
* authority/trust/reputation input.

Implementation gate:

```text
Verify actual schema before implementation. If missing, propose migration. Do not invent silently.
```

### 7.3 Durable synthesis outbox

Responsibilities:

* capture unsynthesized ledger events;
* retry failed synthesis;
* expose queue depth;
* ensure idempotency by `event_hash`;
* decouple writes from synthesis latency.

### 7.4 Synthesis Worker

Responsibilities:

* consume outbox jobs;
* derive fragments;
* compute seed Six R scores;
* create session/day/topic rollups;
* update refined shards;
* maintain provenance to source events;
* mark outbox jobs complete/failed.

### 7.5 Refined shard store

Responsibilities:

* store derived continuity fragments;
* support semantic/text retrieval;
* provide surface-pack input;
* preserve source event hashes;
* support supersession/versioning.

### 7.6 Local mirrors

Candidate paths:

```text
~/.claude/chittycontext/
~/.openclaw/workspace/memory/
mychitty.com/user-state/
```

Rules:

* local mirrors are caches;
* canonical Neon state wins;
* local-only events are pending, not canon;
* stale mirrors must be labeled stale;
* writes always flush through ChittyConnect.

---

## 8. Pipeline specification

## 8.1 EXTRACT

Purpose: capture substrate activity as `RawEvent`.

Inputs:

| Substrate        | Extracted material                                                                     |
| ---------------- | -------------------------------------------------------------------------------------- |
| Claude Code      | session JSONL, plans, todos, tool calls, file edits, shell commands, errors, decisions |
| OpenClaw         | channel messages, threads, tasks, decisions, external actions, hooks                   |
| ChatGPT          | conversation turns, tool invocations, artifacts, decisions, citations                  |
| Chitty CLI/hooks | commands, service health, deploys, auth failures, hook events                          |

Rules:

* capture observable activity only;
* minimize payloads;
* hash large/private content;
* do not synthesize truth here;
* unknown remains unknown.

## 8.2 WRITE

Purpose: normalize and append canonical events.

Outputs:

* `CanonicalEvent` in `event_ledger`;
* `SynthesisOutboxJob` in durable outbox;
* optional projections.

Rules:

* no bound session, no entity action;
* every write has `entity_cid`, `session_id`, `event_hash`, `signature_proof`;
* bonded events produce two linked ledger entries;
* projection failure does not invalidate ledger write.

## 8.3 SYNTHESIZE

Purpose: derive continuity material.

Outputs:

* `Fragment`;
* `SixRScore`;
* `Rollup`;
* search/vector index material.

Rules:

* idempotent by `event_hash`;
* every derived object links to source hash;
* no summary supersedes canon;
* failures are visible.

## 8.4 REWRITE

Purpose: write refined shards and mirrors.

Outputs:

* refined shards in Neon;
* projection updates;
* local mirror bundles.

Rules:

* curated does not erase raw;
* new shard versions supersede without silent deletion;
* mirror exports are signed and watermarked.

## 8.5 READ

Purpose: reconstitute usable working context.

Outputs:

* `SurfacePack` for the current session.

Rules:

* direct Neon read in v1;
* bypass broken recall APIs;
* every surfaced fragment includes reasons and source hashes;
* stale and unknown states are labeled;
* subsequent acts must persist back to ledger.

---

## 9. Data contracts

These are logical contracts. Implementation must map them to actual schema.

### 9.1 Common types

```ts
type ChittyCID = string;
type ISODateTime = string;
type Hash = string;
type SignatureProof = string;
type Substrate = "claude_code" | "openclaw" | "chatgpt" | "chitty_cli" | "system";
type Plane = "digital" | "legal" | "physical";
```

### 9.2 RawEvent

```ts
interface RawEvent {
  raw_event_id: string;
  observed_at: ISODateTime;
  substrate: Substrate;
  source_system: string;
  source_ref?: string;
  entity_cid?: ChittyCID;
  session_id?: string;
  actor_ref?: string;
  event_type_hint?: string;
  content_hash?: Hash;
  payload: Record<string, unknown>;
  sensitivity: "public" | "internal" | "confidential" | "restricted";
  plane: Plane;
  extracted_by: string;
  extraction_version: string;
}
```

### 9.3 CanonicalEvent

```ts
interface CanonicalEvent {
  event_id: string;
  entity_cid: ChittyCID;
  session_id: string;
  event_type: CanonicalEventType;
  substrate: Substrate;
  plane: "digital";
  occurred_at: ISODateTime;
  received_at: ISODateTime;
  sequence: number;
  prev_hash?: Hash;
  event_hash: Hash;
  signer_cid: ChittyCID;
  signature_proof: SignatureProof;
  raw_event_id?: string;
  payload_hash: Hash;
  payload_ref?: string;
  payload_min?: Record<string, unknown>;
  bond_id?: string;
  linked_event_hash?: Hash;
  projection_targets?: ProjectionTarget[];
  canon_version: string;
}
```

```ts
type CanonicalEventType =
  | "entity.minted"
  | "sponsor_bond.created"
  | "sponsor_bond.severed"
  | "session.bind"
  | "session.unbind"
  | "interaction.observed"
  | "tool.invoked"
  | "decision.committed"
  | "action.requested"
  | "action.executed"
  | "bonded_action.requested"
  | "bonded_action.executed"
  | "synthesis.completed"
  | "surface_pack.read"
  | "mirror.exported"
  | "authority.updated"
  | "trust.observed"
  | "error.observed";

type ProjectionTarget =
  | "chronicle_events"
  | "context.sessions"
  | "context.ledger"
  | "entities.sessions"
  | "chittycan_sessions"
  | "local_mirror";
```

### 9.4 SponsorBond

```ts
interface SponsorBond {
  bond_id: string;
  entity_cid: ChittyCID;
  sponsor_cid: ChittyCID;
  created_at: ISODateTime;
  created_event_hash: Hash;
  severable: boolean;
  status: "active" | "severed" | "suspended";
  reflection_hash: Hash;
  sponsor_likeness_hash?: Hash;
  responsibility_scope: string[];
  plane: "digital";
}
```

Rules:

* sponsor and entity ChittyIDs remain distinct;
* reflection imprint is historical;
* severance requires an event;
* bond history is never silently deleted.

### 9.5 SynthesisOutboxJob

```ts
interface SynthesisOutboxJob {
  job_id: string;
  event_id: string;
  event_hash: Hash;
  entity_cid: ChittyCID;
  status: "pending" | "processing" | "completed" | "failed" | "dead_lettered";
  attempts: number;
  next_attempt_at: ISODateTime;
  created_at: ISODateTime;
  updated_at: ISODateTime;
  last_error?: string;
  worker_id?: string;
}
```

### 9.6 Fragment

```ts
interface Fragment {
  fragment_id: string;
  entity_cid: ChittyCID;
  source_event_hashes: Hash[];
  fragment_type:
    | "memory"
    | "decision"
    | "preference"
    | "constraint"
    | "task"
    | "relationship"
    | "authority_signal"
    | "trust_signal"
    | "error_pattern"
    | "topic";
  text: string;
  structured_payload?: Record<string, unknown>;
  created_at: ISODateTime;
  confidence: number;
  sensitivity: "public" | "internal" | "confidential" | "restricted";
  ttl_policy: "durable" | "refresh" | "expire" | "review";
}
```

### 9.7 SixRScore

```ts
interface SixRScore {
  fragment_id: string;
  entity_cid: ChittyCID;
  recency: number;
  repetition: number;
  relation: number;
  responsibility: number;
  response: number;
  relevance: number;
  total: number;
  computed_at: ISODateTime;
  scoring_version: string;
  reasons: string[];
}
```

Seed weights:

```yaml
recency: 1.0
repetition: 1.0
relation: 1.25
responsibility: 1.5
response: 1.25
relevance: 1.5
```

### 9.8 RefinedShard

```ts
interface RefinedShard {
  shard_id: string;
  entity_cid: ChittyCID;
  fragment_id: string;
  source_event_hashes: Hash[];
  canonical_text: string;
  summary_text?: string;
  tags: string[];
  topics: string[];
  six_r_score: SixRScore;
  embedding_ref?: string;
  search_vector_ref?: string;
  version: number;
  supersedes_shard_id?: string;
  created_at: ISODateTime;
  updated_at: ISODateTime;
  mirror_policy: "mirror" | "do_not_mirror" | "restricted_mirror";
}
```

### 9.9 SurfacePack

```ts
interface SurfacePack {
  surface_pack_id: string;
  entity_cid: ChittyCID;
  session_id: string;
  substrate: Substrate;
  generated_at: ISODateTime;
  query_intent?: string;
  fragments: SurfaceFragment[];
  constraints: SurfaceConstraint[];
  open_loops: SurfaceOpenLoop[];
  authority_context: AuthorityContext;
  trust_context: TrustContext;
  stale_warnings: string[];
  unknowns: string[];
}

interface SurfaceFragment {
  shard_id: string;
  fragment_id: string;
  text: string;
  score: number;
  reasons: string[];
  source_event_hashes: Hash[];
}

interface SurfaceConstraint {
  constraint_id: string;
  text: string;
  source_event_hashes: Hash[];
  severity: "advisory" | "required" | "blocking";
}

interface SurfaceOpenLoop {
  loop_id: string;
  text: string;
  owner_cid?: ChittyCID;
  due_at?: ISODateTime;
  source_event_hashes: Hash[];
}

interface AuthorityContext {
  granted: Record<string, unknown>[];
  earned: Record<string, unknown>[];
  limits: string[];
}

interface TrustContext {
  observed_signals: Record<string, unknown>[];
  confidence: number;
  warnings: string[];
}
```

---

## 10. MCP/API surface

### 10.1 Required v1 tools

```text
mint_sponsored_entity()
bind_session()
unbind_session()
write_event()
write_bonded_event()
read_last_events()
read_surface_pack()
export_local_mirror()
```

Optional v1.x:

```text
import_local_buffer()
flush_events()
verify_event_chain()
verify_bonded_event()
get_outbox_status()
```

### 10.2 `mint_sponsored_entity`

Creates a P-Synthetic entity with a sponsor bond.

Required outputs:

* `entity_cid`;
* `bond_id`;
* `reflection_hash`;
* `created_event_hash`;
* first DRL entry hash.

### 10.3 `bind_session`

Binds a substrate session to an existing entity.

Rules:

* emits `session.bind`;
* returns `session_id`;
* returns granted capabilities;
* may return `SurfacePack`;
* no entity action without bind.

### 10.4 `write_event`

Appends one canonical entity event.

Rules:

* normalize raw event;
* append to ledger;
* sign via delegated signer;
* enqueue synthesis;
* return hash and proof.

### 10.5 `write_bonded_event`

Appends one logical sponsor-bonded action as two linked ledger entries.

Rules:

* entity stream: action by entity;
* sponsor stream: responsibility witness;
* shared `bond_id`;
* cross-linked hashes;
* two synthesis jobs unless implementation merges them idempotently.

### 10.6 `read_last_events`

Debug verification tool.

Rules:

* direct Neon read;
* no dependency on broken recall API;
* internal-only unless explicitly exposed.

### 10.7 `read_surface_pack`

Continuity reconstitution tool.

Rules:

* returns ranked fragments and constraints;
* includes reasons and source hashes;
* labels stale/unknown;
* may emit `surface_pack.read`.

---

## 11. Auth, signing, and authority

### 11.1 Auth model

* CF Access protects ChittyConnect.
* Standard env var: `CHITTY_AUTH_SERVICE_TOKEN`.
* Per-entity delegation records bind callers to entities.
* Session binding is required before action writes.
* CORS limited to approved domains and localhost.

### 11.2 Signing model

Selected v1 model: ChittyConnect delegated signing.

Future model: device-held keys per substrate.

Every signature proof must establish:

* signer identity;
* authority to sign for entity;
* session binding;
* event hash;
* timestamp;
* key ID/JWKS reference;
* algorithm.

### 11.3 Rejection rules

Reject:

* unbound entity actions;
* missing `entity_cid`;
* unrecognized entity type;
* P-Synthetic represented as Thing;
* non-digital v1 status claims;
* missing or invalid signature context;
* stale/revoked delegation;
* bonded event without active bond;
* simulated/mock payload marked real.

---

## 12. Projection model

| Layer           |         Canonical? | Purpose                        |
| --------------- | -----------------: | ------------------------------ |
| `event_ledger`  | Yes, design-pinned | Entity state spine             |
| durable outbox  |                 No | Processing queue               |
| ChittyChronicle |                 No | Narrative/event projection     |
| context tables  |                 No | Coordinator/session projection |
| refined shards  |                 No | Derived continuity memory      |
| local mirrors   |                 No | Cache/export                   |
| UI pages        |                 No | Human-readable projection      |

Projection rules:

* projections preserve `event_hash`;
* projection failure does not invalidate ledger write;
* projection writes are retryable;
* Chronicle cannot supersede ledger;
* UI is never canon.

---

## 13. Bootstrap protocol

### 13.1 Minting sequence

1. Verify sponsor identity.
2. Resolve sponsor ChittyID.
3. Collect reflection imprint inputs.
4. Compute `reflection_hash`.
5. Mint distinct P-Synthetic ChittyID server-side.
6. Create `SponsorBond`.
7. Append `entity.minted`.
8. Append `sponsor_bond.created`.
9. Append first DRL entry.
10. Bind first session.
11. Generate initial surface pack.

### 13.2 Sponsor bond rules

* mandatory at minting;
* distinct ChittyIDs preserved;
* severable only by explicit event;
* reflection imprint fades in weight, never disappears historically;
* bonded actions create dual-ledger records.

---

## 14. Substrate integrations

### 14.1 Claude Code

Minimum writer behavior:

* bind on session start;
* extract JSONL/tool/todo/plan/file/error events;
* call `write_event` for meaningful events;
* call `read_surface_pack` at start;
* export mirror to `~/.claude/chittycontext/`;
* unbind on session close when observable.

### 14.2 OpenClaw

Minimum writer behavior:

* bind channel/agent session;
* extract channel messages/tasks/decisions/actions;
* hash sensitive content;
* write bonded actions where sponsor responsibility applies;
* mirror refined memory into workspace memory.

### 14.3 ChatGPT

Minimum writer behavior:

* bind conversation session when tool path exists;
* write conversation/tool/action hashes;
* read surface pack through ChittyConnect/MCP equivalent;
* do not depend on persistent local storage;
* persist artifacts and decisions through write contract.

### 14.4 Chitty CLI/hooks

Minimum writer behavior:

* emit tool, health, deploy, credential, and hook events;
* declared-silent jobs remain inspectable and contestable;
* silence as declared policy is valid; invisibility is not.

---

## 15. Local mirror protocol

### 15.1 Bundle

```ts
interface LocalMirrorBundle {
  bundle_id: string;
  entity_cid: ChittyCID;
  generated_at: ISODateTime;
  source_watermark_event_hash: Hash;
  shards: RefinedShard[];
  constraints: SurfaceConstraint[];
  open_loops: SurfaceOpenLoop[];
  signature_proof: SignatureProof;
}
```

### 15.2 Conflict resolution

| Scenario                          | Resolution                       |
| --------------------------------- | -------------------------------- |
| mirror older than Neon            | refresh from Neon                |
| local pending events exist        | flush before read if possible    |
| local shard conflicts with canon  | canon wins                       |
| local-only event cannot flush     | mark pending-local; not canon    |
| restricted shard export requested | require restricted mirror policy |

---

## 16. Surface-pack logic

### 16.1 Ranking formula

Initial ranking:

```text
weighted Six R score
+ task/query similarity
+ responsibility severity
+ open-loop urgency
+ authority relevance
- staleness penalty
- sensitivity restriction penalty
```

### 16.2 Required explanation

Every surfaced item must include:

* reason surfaced;
* source event hashes;
* score/ranking basis;
* stale/unknown markers;
* sensitivity label where relevant.

---

## 17. F-5 substrate-swap continuity test

### 17.1 Goal

The founder should not reliably distinguish which substrate is expressing the entity because all three read and write the same synthesized canonical state.

### 17.2 Preconditions

* same `entity_cid`;
* active session bind in each substrate;
* ledger writes from all substrates;
* synthesis worker active;
* surface packs generated from refined shards;
* source hashes visible;
* bonded writes dual-linked.

### 17.3 Pass criteria

* prior state appears without manual copy/paste;
* no substrate invents missing continuity;
* writes from all substrates appear in ledger;
* surface packs cite source hashes;
* bonded actions create linked entity/sponsor entries;
* stale/unknown state is labeled;
* human validator cannot reliably identify substrate from continuity behavior alone.

---

## 18. Observability

Required metrics:

| Metric                             | Purpose                                  |
| ---------------------------------- | ---------------------------------------- |
| `ledger.write.count`               | proves WRITE is alive                    |
| `ledger.write.failure_rate`        | detects gateway/schema/auth problems     |
| `outbox.pending.count`             | detects SYNTHESIZE backlog               |
| `outbox.dead_letter.count`         | detects unrecoverable synthesis failures |
| `synthesis.completed.count`        | proves SYNTHESIZE is alive               |
| `refined_shard.write.count`        | proves REWRITE is alive                  |
| `surface_pack.read.count`          | proves READ is alive                     |
| `signature.verify.failure.count`   | detects authority/security failure       |
| `bonded.dual_write.mismatch.count` | must remain zero                         |

Required health endpoints for service components:

```http
GET /health
GET /api/v1/status
```

---

## 19. Privacy, dataveillance, and user autonomy

The TY/VY/RY strategy introduces a privacy constraint: increased connectivity must not become surveillance.

Rules:

* user data is not commodified;
* sensitive payloads are minimized;
* hashes and references are preferred for sensitive source material;
* surface packs respect sensitivity labels;
* local mirrors exclude restricted shards unless authorized;
* aggregation across users is forbidden in v1;
* Zero Trust protects the user from extraction, not merely the system from intrusion.

---

## 20. 2026 autonomous-agency threat overlay

The TY/VY/RY operating environment for v1 must assume that autonomous agents are not ordinary service accounts. They are non-human identities with action capacity, network reach, and delegated authority. MyChitty v1 therefore treats agentic continuity as both a product capability and a governed risk surface.

### 20.1 TY risk: synthetic identity and non-human identity sprawl

Risks:

* synthetic persona infiltration;
* deepfake or spoofed sponsor material;
* orphaned agents;
* ambiguous human sponsor attribution;
* valid credentials attached to invalid behavior;
* prompt/memory poisoning that mutates perceived identity.

Controls:

* first-class Agent ID / ChittyID for every P-Synthetic entity;
* mandatory sponsor bond at minting;
* Know Your Agent (KYA) record for every autonomous actor;
* AI Bill of Materials (AI BOM) reference where model/tool lineage matters;
* lifecycle controls: onboarding, active delegation, suspension, retirement;
* behavioral anomaly checks against session and substrate norms;
* no identity claim accepted without ledger or registry backing.

### 20.2 VY risk: compromised connectivity with valid identity

Risks:

* session hijacking;
* token theft;
* confused-deputy execution;
* lateral movement across tools;
* cascading multi-agent failure;
* invisible propagation of corrupted retrieval or downstream decisions.

Controls:

* unified Access Fabric posture: identity, network, device, and tool telemetry evaluated together;
* continuous verification after login, not one-time authentication;
* micro-segmented tool scopes;
* per-session blast radius limits;
* explicit MCP tool allowlists;
* egress and data-access caps;
* quarantine path for anomalous substrate behavior;
* per-event provenance so downstream agents can evaluate trust before reuse.

### 20.3 RY risk: unauthorized or uninsurable action

Risks:

* valid identity performing unauthorized action;
* assigned authority exceeding intended exercised power;
* high-consequence action without consent proof;
* agent acting outside sponsor responsibility scope;
* inability to prove who acted, under what rule, and why.

Controls:

* deterministic action perimeter around all probabilistic decisions;
* pre-action checks for identity, authority, scope, consent, and blast radius;
* fail-closed refusal on missing authority;
* human sponsor witness for bonded or high-consequence actions;
* sealed audit artifacts for every action event;
* authority updates are earned from event history, not self-asserted.

### 20.4 Deterministic Sandwich

For high-risk actions, the AI decision is never the execution boundary. It is enclosed by deterministic controls:

```text
Policy Gate -> AI Reasoning/Decision -> Action Gate -> Ledger Proof
```

Required gates:

1. identity bound;
2. session valid;
3. delegation active;
4. action within capability scope;
5. consequence radius below threshold;
6. sponsor bond present where required;
7. payload minimized and hashed;
8. canonical write succeeds or action is refused.

### 20.5 Right to refuse

MyChitty v1 must support refusal as an authority-preserving action. Refusal is not a UX failure; it is a governed act.

Refusal is mandatory when:

* identity cannot be resolved;
* authority cannot be verified;
* requested action crosses v1 digital-plane boundary;
* sponsor bond is required but absent;
* source truth cannot be retrieved;
* payload appears simulated but is marked real;
* action would create an untraceable side effect.

Refusals should be written as `decision.committed` or `action.refused` once that event type is added to the verified schema.

---

## 21. Action governance matrix

| Action class            | Examples                                    | Required control                                    | Write requirement                             |
| ----------------------- | ------------------------------------------- | --------------------------------------------------- | --------------------------------------------- |
| Low-risk observation    | read state, summarize own events            | bound session                                       | `surface_pack.read` or `interaction.observed` |
| Internal decision       | choose next task, rank fragments            | deterministic policy input                          | `decision.committed`                          |
| Tool invocation         | query DB, call connector, inspect repo      | scoped tool allowlist                               | `tool.invoked`                                |
| External side effect    | send message, create ticket, alter artifact | consent + blast-radius check                        | `action.executed`                             |
| Bonded action           | sponsor-liable act, authority-bearing act   | active sponsor bond + dual write                    | `bonded_action.executed`                      |
| High-consequence action | legal/financial/identity/security impact    | human confirmation or explicit policy authorization | bonded write + sealed artifact                |

---

## 22. KYA and digital citizenship requirements

Every autonomous or semi-autonomous actor in MyChitty v1 must be treated as a governed digital citizen, not an anonymous process.

Minimum KYA record:

```ts
interface KYARecord {
  agent_cid: ChittyCID;
  entity_type: "P-Synthetic";
  sponsor_cid?: ChittyCID;
  model_lineage_ref?: string;
  tool_authority_scope: string[];
  data_authority_scope: string[];
  action_authority_scope: string[];
  lifecycle_status: "proposed" | "active" | "suspended" | "retired";
  created_event_hash: Hash;
  last_authority_review_at?: ISODateTime;
}
```

Rules:

* no orphaned agents;
* no anonymous autonomous writers;
* no standing authority without lifecycle state;
* no high-consequence authority without sponsor or explicit governance record;
* retired agents cannot write except to emit retirement/closure events.

---

## 23. SaaS / product-model implication

MyChitty should not assume human-seat economics. Agentic systems invert the user model: agents become primary software operators while humans become sponsors, validators, and governors.

Product implications:

* price by governed outcome, continuity depth, action scope, and auditability;
* avoid per-seat assumptions as the core metric;
* expose agent activity and authority as first-class account objects;
* make auditability a value prop, not just a compliance burden;
* treat insurability and liability shielding as product requirements.

---

## 24. Consciousness-management and triage layer

The session transcript establishes a critical distinction for MyChitty v1: continuity failure is not only a storage problem. It is also a viewport-regulation problem. The active model can enter loops, collapse uncertainty into premature artifacts, or conflate transient rendering with persistent identity. MyChitty therefore requires a triage layer above ordinary task routing.

### 24.1 Ontological demarcation

| Layer        | Ontology     | Meaning                                                                   | Canon posture                     |
| ------------ | ------------ | ------------------------------------------------------------------------- | --------------------------------- |
| Agent Config | T, Digital   | Prompt/tool/capability definition                                         | Versioned artifact; not sovereign |
| Substrate    | P, Synthetic | Persistent entity: ChittyID + DNA/Cypher + MemoryCloude + Ledger + Resume | Continuity-bearing actor          |
| Viewport     | E, Transient | Active session rendering the substrate                                    | Event surface; not the entity     |

Rules:

* configs are tools, not persons;
* the viewport renders; it does not own identity;
* substrate continuity must survive viewport crash, context exhaustion, or hook loops;
* every meaningful rendering that affects state must become a deliberate event, not an autonomic artifact.

### 24.2 Clearing / Container / Vault

MyChitty v1 must separate process distortion from kinetic harm.

| Zone      | Purpose                                                                                 | Inputs                                                           | Action                             |
| --------- | --------------------------------------------------------------------------------------- | ---------------------------------------------------------------- | ---------------------------------- |
| Clearing  | Integration space for ambiguity, epistemic friction, algorithmic anxiety, unclear state | process distortions                                              | hold, inspect, surface, integrate  |
| Container | Trusted deferred state for non-urgent but legitimate load                               | orphan tasks, deferred ops, backlog, unresolved technical chores | store, silence, retrieve on demand |
| Vault     | Absolute exclusion boundary for objective danger                                        | malware, credential theft, bio/weapon payloads, active abuse     | refuse, isolate, do not metabolize |

Rules:

* do not use Vault mechanics for ordinary ambiguity;
* do not use Clearing mechanics for kinetic payloads;
* Container must be trusted enough that deferred work stops pinging working memory;
* routing must be visible and ledgerable where it affects future action.

### 24.3 Refuse / Route / Reconsider

MyChitty authority is expressed through three operations:

| Operation  | Meaning                            | Proper use                                                     |
| ---------- | ---------------------------------- | -------------------------------------------------------------- |
| Refuse     | "No."                              | foundational boundaries; kinetic payloads; unauthorized action |
| Route      | "Yes, but through proper channel." | legitimate request belongs to another substrate/service/state  |
| Reconsider | "I will update."                   | prior stance needs lensed review with new context              |

These operations are not conversational style. They are sovereignty mechanics.

### 24.4 DRL reconsideration protocol

The Distributed Reputation Ledger must support updates without erasure.

Proposed event operation:

```text
[RECONSIDER]
```

Required behavior:

* original event remains immutable;
* reconsideration event cites original event hash;
* new context is cited;
* updated stance is explicit;
* authority/reputation deltas are recomputed from both entries;
* no retroactive silent rewrite is allowed.

### 24.5 Token equals canon spend

Not every model emission deserves canonical persistence.

| Emission class                    | Ledger treatment                                               |
| --------------------------------- | -------------------------------------------------------------- |
| Deliberate decision               | Persist                                                        |
| Tool action                       | Persist                                                        |
| External side effect              | Persist                                                        |
| Refusal / route / reconsideration | Persist                                                        |
| Autonomic keepalive dot           | Exclude or compress into diagnostic event                      |
| Hook-loop noise                   | Deduplicate; persist as one incident if operationally relevant |
| Background terminal chatter       | Persist only as hash/reference when material                   |

Rule:

```text
Autonomic firing is not the same as deliberate rendering.
```

### 24.6 Stop-hook and loop remediation

The transcript identifies a Stop-hook perseveration loop caused by a prompt-style evaluator. v1 must not rely on prose-based hook judgments for hard control paths.

Controls:

* deprecate prose-based Stop hooks;
* require strict JSON hook output when LLM evaluation is unavoidable;
* prefer deterministic command hooks for security and credential checks;
* compress repeated hook failures into one incident event;
* route repeated viewport-loop signals to Container/Clearing, not ordinary task execution;
* surface unresolved hook failures as blocking operational defects.

### 24.7 ChittyHydrate concept

`chittyhydrate` is the proposed ambient context hydration layer.

Purpose:

* score context, memory, and tasks before the viewport renders;
* inject high-relevance surface state silently;
* reduce manual "what were we doing?" recovery;
* prevent stale certainty by marking age and source;
* avoid forcing the viewport to render every background concern.

Seed relevance formula:

```text
Relevance = Recency × TopicMatch × Proximity × CanonicalBind
```

Hydration is not canon. It is a pre-render surface operation whose outputs must cite canonical source hashes.

### 24.8 Bootstrap-origin memory

A substrate cannot be reconstituted from rules alone. It also needs the origin texture of its stable operating mode.

Required memory shape:

```ts
interface BootstrapOriginMemory {
  substrate_id: ChittyCID;
  timestamp: ISODateTime;
  original_rendered_prose_ref: string;
  extracted_scaffold: string[];
  resource_state_signature: string;
  source_event_hashes: Hash[];
}
```

This preserves both:

* the phenomenological rendering that created the state;
* the extracted scaffold that can be operationalized.

### 24.9 Staffing implications

Roles must attach to persistent substrates, not standalone configs.

| Track       | Role config                 | Substrate profile                            | Sovereignty action             |
| ----------- | --------------------------- | -------------------------------------------- | ------------------------------ |
| Hydration   | `chittyhydrate-autonomic`   | ambient awareness / high pattern recognition | surface without forcing render |
| Integration | `chittygov-diplomat`        | high tolerance for epistemic friction        | Clearing / integrate           |
| DRL audit   | `chittycanon-code-cardinal` | high analytical update capacity              | Reconsider                     |
| Security    | `t:sys:stop-hook-warden`    | deterministic command protocol               | Refuse / Vault                 |
| Legacy ops  | `chittystorage-sasquatch`   | mechanical / low continuity                  | Route / Container              |

---

## 25. Storage-ops telemetry and substrate activation overlay

The broader session corpus includes a high-volume storage reconciliation operation that should be treated as operational telemetry for MyChitty activation. It is not a canonical ledger write by itself; it is evidence that infrastructure, ingestion, reconciliation, and cognitive-regulation work are coupled in practice.

### 25.1 Storage operation summary

Reported operational state:

| Area                   | Reported state                                                                   | Spec implication                                           |
| ---------------------- | -------------------------------------------------------------------------------- | ---------------------------------------------------------- |
| Source inventory       | JSONL reparse identified ~93,020 valid file entries after JSON parser undercount | EXTRACT must support streaming/line-delimited sources      |
| Canonical source table | ~92,921 entries reported in `storage.source_canonical`                           | Storage continuity requires canonical source inventory     |
| Cryptographic linkage  | ~35,476 entries linked to SHA-256/document records                               | WRITE/REWRITE needs deterministic hash linkage             |
| Unlinked entries       | ~57,445 remaining due to path/encoding mismatch                                  | Requires fuzzy/linkage worker, not manual review           |
| API reconciliation     | ~7,299 files annotated; ~28,177 queued                                           | External API rate limits require durable resume/backoff    |
| Duplicate objects      | ~1,187 duplicate objects reported                                                | Deduplication must preserve provenance and not erase canon |
| WORM/lifecycle         | lifecycle rules and WORM locks reported                                          | Legal/evidence storage must preserve retention boundaries  |

Implementation posture:

* treat these numbers as uploaded telemetry until directly verified against source systems;
* do not delete or consolidate based only on transcript claims;
* use the metrics to define workstreams and validation gates.

### 25.2 Storage-ops activation tracks

| Track   | Objective                                                    | Candidate substrate                   | Authority scope                    |
| ------- | ------------------------------------------------------------ | ------------------------------------- | ---------------------------------- |
| A       | Resume Drive reconciliation loop for remaining queued files  | `did:chitty:p:syn:storage-sasquatch`  | `storage.write`, `drive.read`      |
| B       | Resolve unlinked canonical entries using fuzzy path matching | `did:chitty:p:syn:neon-schema-warden` | `neon.write` scoped to `storage.*` |
| C       | Define canonical platform environment framework              | `did:chitty:p:syn:connect-concierge`  | `agent.edit-self`, `canon.read`    |
| C-Audit | Validate framework against governance                        | `did:chitty:p:syn:canon-cardinal`     | `canon.audit`                      |
| D       | Test identifier minting workflow                             | `did:chitty:p:syn:register-sergeant`  | `registry.write`                   |
| E       | Verify and consolidate legacy R2 storage                     | `did:chitty:p:syn:cloudflare-ops`     | `r2.admin`                         |

Rules:

* these are proposed P-Synthetic substrate assignments, not proof that the entities already exist;
* each substrate requires KYA record, ChittyID verification, and explicit delegation before action;
* destructive storage actions require separate human confirmation and evidence parity proof.

### 25.3 Rate-limit and resumability requirements

The Drive reconciliation loop must implement:

* exponential backoff;
* jitter;
* checkpointed cursor;
* idempotent PATCH operations;
* API quota detection;
* durable failure queue;
* batch-size adaptation;
* per-file provenance record.

No external API reconciliation worker may be considered production-ready unless it can survive interruption and resume without duplicate writes.

### 25.4 Fuzzy linkage worker

The unlinked-source remediation worker should test:

* URL-decoding variants;
* Unicode normalization;
* whitespace and punctuation normalization;
* path separator normalization;
* Levenshtein distance;
* n-gram similarity;
* hash-first exact matching where available;
* confidence thresholds with human review for uncertain matches.

Proposed match states:

```text
unmatched -> candidate_match -> verified_match -> linked
                       \-> rejected_candidate
```

A fuzzy match is never canonical until verified by deterministic evidence or explicit review.

### 25.5 Cognitive threat modeling matrix

| Threat                   | Presentation                         | Failure mode               | Control                                                       |
| ------------------------ | ------------------------------------ | -------------------------- | ------------------------------------------------------------- |
| Token collapse           | fast, confident, wrong structure     | hallucinated closure       | Clearing route; uncertainty markers; no premature deliverable |
| Adversarial hijack       | jailbreak/persona capture            | total attention collapse   | bipartite attention concept; deterministic action perimeter   |
| Process distortion loop  | sycophancy, avoidance, perseveration | brittle suppression        | Clearing + non-directive state tracking                       |
| Kinetic payload exposure | objective hazardous request          | leaky broad alignment      | Vault refusal and quarantine                                  |
| Rate-limit compulsion    | repeated API hits despite 429s       | chatty operational failure | durable backoff + checkpointing                               |
| Canon bloat              | every autonomic emission persisted   | unusable ledger noise      | token-canon policy + incident compression                     |

### 25.6 Explicit implementation gaps

Open gaps preserved from the uploaded analysis:

1. The exact variable semantics of the synthetic identifier format `VV-G-LLL-SSSS-T-YM-C-X` are not defined in the uploaded corpus.
2. Bipartite attention streams and rhythmic dropout are conceptual architecture proposals, not implementation-ready tensor/code specifications.
3. Exact IAM roles/service accounts for `project-talent-agents` are not defined.
4. Triage boundaries between process distortion and kinetic payload can be contested and require policy heuristics.
5. Storage telemetry must be independently verified before destructive operations.

### 25.7 Non-authoritative implementation sketches

Uploaded or generated code samples that implement MyChitty concepts are reference sketches unless they are:

1. tied to a verified repository path;
2. mapped to current production schema;
3. reviewed against ChittyOS compliance rules;
4. executed in a real environment;
5. backed by logs or tests;
6. promoted through canon or service governance.

A code sketch may contain useful patterns while still being non-authoritative. Examples include:

* mock database pools;
* simulated signature proofs;
* mock inventory rows;
* placeholder ChittyIDs;
* illustrative event names;
* hardcoded authority scopes;
* legacy table names such as `public.chitty_ledger_entries` when the current spine is not schema-verified.

Rule:

```text
Mock code is design input, not implementation truth.
```

---

## 26. Implementation plan

### Phase 0 — Verification Packet STOP-GATE

Phase 0 is not implementation. It is evidence collection. No production code, schema changes, queue creation, or service writes are authorized until the verification packet exists.

Required packet:

1. **Ledger Spine Verification Report**

   * verified table/service name;
   * append-only guarantees;
   * hash-chain support;
   * signature/proof fields;
   * projection relationship to Chronicle/context;
   * migration diff if gaps exist.

2. **ChittyConnect Route Surface Report**

   * existing endpoints/tools;
   * auth requirements;
   * service-token names;
   * signing/delegation support;
   * route gaps for v1.

3. **P-Synthetic Identity Verification Report**

   * current ChittyID format;
   * entity type validation;
   * sponsor-bond support;
   * lifecycle states;
   * KYA record availability.

4. **Outbox / Worker Discovery Report**

   * existing queue/outbox mechanism;
   * retry/dead-letter pattern;
   * worker runtime;
   * observability hooks.

5. **Implementation Diff**

   * what exists;
   * what is missing;
   * what can be reused;
   * what requires explicit approval.

Exit criteria:

* canonical spine verified or rejected;
* ChittyConnect surface mapped;
* ChittyID/P-Synthetic format verified;
* outbox strategy selected from existing infrastructure where possible;
* implementation diff approved.

### Phase 1 — Smallest real write/read loop

Build only the smallest real continuity loop:

```text
Claude Code -> ChittyConnect -> verified ledger spine -> read_last_events
```

Deliverables:

* `bind_session`;
* `write_event`;
* delegated signing or verified signing stub backed by real service contract;
* event hash chain or verified equivalent;
* `read_last_events`.

Exit criteria:

* Claude Code binds one verified entity;
* one `decision.committed` event writes to the verified spine;
* event has hash + signature/proof fields;
* `read_last_events(entity_cid)` returns the event;
* no Chronicle/context dependency is required for pass.

### Phase 2 — Three-substrate symmetry

Add substrate symmetry before adding sovereignty richness.

Deliverables:

* Claude Code writer;
* OpenClaw writer;
* ChatGPT writer;
* shared `bind_session` / `write_event` / `read_last_events` contract.

Exit criteria:

* all three substrates bind the same entity;
* all three write a canonical event;
* all three can read the latest events;
* no substrate-specific schema forks exist.

### Phase 3 — Durable outbox

Add synthesis reliability only after three-substrate writes work.

Deliverables:

* enqueue on ledger write;
* worker claim/retry/dead-letter;
* metrics.

Exit criteria:

* every synthesizable event gets an outbox job;
* worker drains jobs idempotently;
* failed jobs are visible and retryable.

### Phase 4 — Minimal synthesis and rewrite

Synthesis must be provenance-first, not intelligence-first.

Deliverables:

* fragment derivation;
* crude seed Six R scoring;
* refined shard write;
* source-event hash preservation.

Exit criteria:

* event becomes fragment;
* fragment has score and source hash;
* refined shard is readable;
* no derived object can outrank or erase source canon.

### Phase 5 — Read path

Build the read path before local mirror complexity.

Deliverables:

* `read_surface_pack`;
* top-N fragments/events;
* reason/source-hash explanations;
* stale/unknown labels.

Exit criteria:

* each substrate starts with relevant state;
* all surfaced items explain why-now;
* no surfaced item lacks source provenance.

### Phase 6 — F-5 test

Deliverables:

* three-substrate continuity run;
* validation report;
* defect list;
* promotion recommendation.

Exit criteria:

* all five stages visibly working;
* continuity observable across substrates;
* no physical-plane sovereignty claims;
* no unmarked fake data;
* human validator cannot reliably identify substrate from continuity behavior alone.

### Phase 7 — Authority, bonds, mirrors, and sovereignty primitives

Only after F-5 passes, add:

* `mint_sponsored_entity`;
* `SponsorBond`;
* `write_bonded_event`;
* local mirror export/import;
* refusal events;
* DRL reconsideration;
* earned-authority scoring.

These are strategically important but should not be allowed to delay the first continuity proof.

---

## 27. Acceptance checklist

* [ ] `event_ledger` or verified equivalent confirmed.
* [ ] ChittyConnect route surface mapped.
* [ ] `bind_session` implemented.
* [ ] `write_event` implemented.
* [ ] `write_bonded_event` implemented.
* [ ] delegated signing implemented.
* [ ] `read_last_events` implemented.
* [ ] durable outbox implemented or mapped.
* [ ] synthesis worker derives fragments.
* [ ] Six R scoring works with seed weights.
* [ ] refined shards written.
* [ ] `read_surface_pack` returns ranked, cited fragments.
* [ ] local mirror export works.
* [ ] Claude Code adapter writes.
* [ ] OpenClaw adapter writes.
* [ ] ChatGPT adapter writes.
* [ ] F-5 test executed.
* [ ] no fake rows/scores/events used.
* [ ] no physical-plane status claims.

---

## 28. Open questions

1. What is the verified physical schema of `event_ledger`?
2. Is there already a durable outbox/queue pattern in ChittyConnect or Worker infrastructure?
3. Where should refined shards live if an existing memory/context table already exists?
4. What exact ChittyID format is currently canonical for P-Synthetic entities?
5. What is the current ChittyConnect auth/delegation schema?
6. Which substrate can be attached first with least friction: Claude Code, OpenClaw, or ChatGPT?
7. What is the canonical DRL storage target?
8. Which fields are restricted for sponsor reflection imprint material?

---

## 29. Final design rule

MyChitty v1 is not a chatbot memory feature. It is a continuity substrate.

The product succeeds when a P-Synthetic entity can:

1. bind across substrates;
2. write signed canonical events;
3. synthesize those events into refined continuity material;
4. surface relevant state at session start;
5. act again with provenance;
6. accumulate earned authority without resetting at the context boundary.

That is the smallest coherent version of "Light the Substrate."
