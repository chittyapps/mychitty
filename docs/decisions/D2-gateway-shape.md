# D2 — v1 Producer Gateway Shape

**Status:** ACCEPTED — claim existing `ledger.chitty.cc` (CHITTYFOUNDATION/chittyledger) as v1 producer
**Date:** 2026-05-10

## Accepted resolution

After registry/grep discovery of live namespaces (`gateway.chitty.cc` is the meta-gateway; `ledger.chitty.cc` is **already a deployed Worker** named `chittyledger`), the original A/B/C options were superseded by a fourth: **claim the existing `chittyledger` Worker as the v1 producer.**

**Why this beats Option B (new gateway service):**
- `chittyledger`'s CHARTER.md already names hash chain, sequence enforcement, and signature verification as core responsibilities — adding the v1 producer is *literally what the charter says it does*, no charter rewrite needed.
- Already has Bearer auth + KV service-token store + `NEON_DATABASE_URL` binding + chittytrack tail consumer. Zero infra to provision.
- Avoids creating the parallel-pipeline anti-pattern documented in R2 (a second worker fronting the same DB).
- Existing `POST /entries` writes legacy `chitty_ledger_entries` (R4 finding 6); those routes become deprecated, and the v1 routes ship at `/v1/*`. One Worker, two semantics, one of them sunsetting.

**Q1 (URL):** `ledger.chitty.cc/v1/*` — existing Worker, new route prefix.
**Q2 (Repo):** `CHITTYFOUNDATION/chittyledger/api/` — existing repo, additive only.
**Q3 (Outbox):** same-DB table `public.synthesis_outbox` in ChittyLedger — transactional with the event INSERT, no new service.

## Implementation impact

The original sketch (new repo `CHITTYOS/chittyledger-gateway`) is replaced by an additive change to `CHITTYFOUNDATION/chittyledger/api/src/`:

```
chittyledger/api/src/
  index.ts                  # existing — add /v1/* mount
  v1/                       # new
    mcp.ts                  # MCP server: bind_session, write_event, ...
    sign-client.ts          # POST auth.chitty.cc/v1/sign (D5)
    sequence.ts             # D3 allocator
    hash.ts                 # payload_hash + event_hash + chain link
    ledger-write.ts         # v1 INSERT path → public.event_ledger
    outbox.ts               # enqueue → public.synthesis_outbox
    types.ts                # zod CanonicalEvent etc.
  routes/
    entries.ts              # existing legacy /entries — mark @deprecated
```

Phase 1 first task = scaffold `chittyledger/api/src/v1/` + register a service ChittyID for `signer_cid` as part of D5 implementation.

---

**Blocks:** D3 (sequence allocation), D6 (legacy row strategy), Phase 1 scaffold
**Depends on:** D5 ACCEPTED (ChittyAuth signs events)
**Related findings:** R2 (ChittyConnect is a router), R4 (alchemist is the only writer; 3 repos, 1 drifted; no outbox; legacy v0 schema only), R5 §1.2

## What needs to exist

A service that:
1. Accepts MCP/REST calls from substrate adapters (Claude Code, OpenClaw, ChatGPT)
2. Authenticates the caller and binds to an entity
3. Normalizes `RawEvent` → `CanonicalEvent`
4. Computes `payload_hash`, allocates `sequence`
5. Calls `auth.chitty.cc/v1/sign` (D5) for `signature_proof`
6. Computes `event_hash` and links `prev_hash`
7. INSERTs into `public.event_ledger` with all 13 v1 columns + `canon_version='1.0'`
8. Enqueues a synthesis outbox job
9. Dual-writes for bonded events
10. Exposes `read_last_events` and `read_surface_pack` for verification

Today: none of this exists. Alchemist writes 12 legacy v0 columns synchronously, 13 v1 columns NULL, no signing, no sequencing, no outbox.

## Option A — Upgrade alchemist in place

**Where:** existing `chittyagent-alchemist` Worker (after R4-D1 consolidation to one repo)

**What's net-new:**
- Add MCP server for v1 tools (`bind_session`, `write_event`, `write_bonded_event`, `read_last_events`, `read_surface_pack`)
- Add ChittyAuth signing client
- Add sequence allocator (D3)
- Add outbox writer
- Add v1-shaped INSERT path with 13 new columns + chain hash
- Keep existing 6h cron + analysis insert (different code path)

**Pros:**
- Reuses existing Hyperdrive binding to ChittyLedger
- Reuses existing 1Password secret bindings, deploy pipeline, monitoring
- Single Worker = single deploy, single rollback
- Existing CHARTER/CHITTY/CLAUDE triad already registered

**Cons:**
- **Mission conflict.** Alchemist's CHARTER says "Continuous Improvement Engine — monitors tool/skill/MCP usage, proposes improvements." It is an *analyzer*, not a gateway. Bolting v1 producer onto it violates single-responsibility and makes the charter incoherent.
- **Blast radius coupling.** A bug in the v1 write path could break the analysis cron (or vice versa). Today's alchemist failure = no analysis; tomorrow's = no canonical events.
- **R4-D1 consolidation must happen first.** 3 repos, 1 drifted at +98 LOC. Touching alchemist before consolidating risks losing the drift work or merging into a deploy that gets overwritten.
- Charter triad must be rewritten to reflect dual purpose.

## Option B — New dedicated v1 gateway service (RECOMMENDED)

**Where:** new Worker, suggested name `chittyledger-gateway` at `ledger.chitty.cc` or `gateway.ledger.chitty.cc`

**What's net-new:**
- Full service scaffold: `wrangler.jsonc`, charter triad, registration with `registry.chitty.cc`
- MCP server with 8 v1 tools
- ChittyAuth signing client
- Sequence allocator (D3)
- Outbox writer
- v1 INSERT path
- Hyperdrive binding to ChittyLedger
- 1Password secrets (signing service token, DB conn)

**Pros:**
- **Single responsibility.** Charter is unambiguous: "v1 producer for `event_ledger`."
- **Independent failure domain.** Outage doesn't take down alchemist's analysis or the 6h cron.
- **Independent deploy / rollback.** v1 changes ship without touching the analyzer.
- **Cleaner audit story.** Every event_ledger row with `canon_version='1.0'` came from one named service with one known signing principal.
- **Doesn't depend on R4-D1.** Alchemist's 3-repo mess is orthogonal; can be cleaned up later without blocking.
- **Spec-aligned.** Spec §7.1 names the component "ChittyConnect Write Gateway" — but R2 confirmed ChittyConnect is a router. A dedicated gateway service is the spec's intent without the misnomer.

**Cons:**
- More upfront scaffolding (~1 day vs. ~half day for in-place).
- Yet-another-service to monitor, secret-manage, and register.
- Hyperdrive binding has to be re-provisioned (cheap but takes a step).

**Mitigations:**
- Use the existing `chittyserv-template` or fork alchemist's `wrangler.jsonc` for fast scaffold.
- Register with `registry.chitty.cc` as part of deploy script — one curl call.

## Option C — Use ChittyConnect as the gateway

**Where:** existing `chittyconnect` Worker (`connect.chitty.cc`)

**Why considered:** spec §7.1 literally says "ChittyConnect Write Gateway."

**Why rejected (already in R5 implicitly, made explicit here):**
- R2 confirmed ChittyConnect does **zero direct writes to `event_ledger`** — it's a router/proxy across 23+ surfaces. Adding direct DB write responsibility violates the layering R2 documented.
- Tier 2 (platform) service. v1 producer needs to be tier 1-adjacent for the same reason signing belongs in ChittyAuth (D5).
- ChittyConnect already routes a `/api/chittychronicle` proxy to a *different* ledger-like surface (`chronicle_events`). Mixing v1 canonical writes into the same Worker creates two ledger semantics in one process.
- ChittyConnect's existing chronicle-engine writes confirm the org has tried "write through the router" before and produced parallel infrastructure (R2 finding 4). Repeating that pattern produces a third parallel pipeline.

## Recommendation

**Option B — new dedicated gateway service `chittyledger-gateway`.**

Reasoning:
1. **Charter cleanliness.** v1 deserves a service whose CHARTER says exactly what it does — produce canonical events. Alchemist's charter is "improvement engine," and ChittyConnect's is "router." Forcing either to also be a producer creates documentation lies.
2. **Failure isolation.** Production canonical writes should not share a process with cron-based analysis (alchemist) or proxy routing (ChittyConnect). v1 ledger writes are the highest-trust surface in the ecosystem.
3. **R4-D1 doesn't block.** Alchemist's 3-repo cleanup happens on its own timeline. The gateway can ship while D1 is unresolved.
4. **Low marginal cost.** ChittyOS already has 30+ Workers; adding one more with the established pattern (charter triad, registration, wrangler) is well-trodden ground.
5. **Spec faithfulness.** Spec §7.1's "ChittyConnect Write Gateway" reflects an outdated view of ChittyConnect. The dedicated service captures the spec's intent under a more accurate name.

## What this unblocks

- **D3 (sequence):** can now spec where the allocator lives — inside the gateway Worker, calling either DB serial or Postgres advisory lock.
- **D6 (legacy rows):** gateway is the discriminator — every write it produces has `canon_version='1.0'`; everything else is legacy.
- **Phase 1 scaffold:** scaffold the gateway repo as the first Phase 1 task.

## Implementation sketch (post-decision)

```
new repo: github.com/CHITTYOS/chittyledger-gateway
  CHARTER.md           # v1 producer for public.event_ledger
  CHITTY.md            # tier 2, depends on ChittyAuth (signing) + ChittyLedger (DB)
  CLAUDE.md            # dev patterns
  wrangler.jsonc       # production env, Hyperdrive to ChittyLedger,
                       #   secret bindings: AUTH_SVC_TOKEN, MINT_API_KEY
  src/
    index.ts           # Hono app + MCP mount
    mcp/
      tools.ts         # bind_session, write_event, write_bonded_event,
                       #   read_last_events, read_surface_pack, ...
    services/
      sign.ts          # POST auth.chitty.cc/v1/sign client
      sequence.ts      # D3 allocator
      hash.ts          # payload_hash + event_hash + chain link
      ledger-write.ts  # the one INSERT path
      outbox.ts        # enqueue synthesis job
    types/
      canonical-event.ts  # zod schemas matching spec §9.3
```

8 tools mount under `/mcp`. REST mirror under `/api/v1/*` for non-MCP callers. Health at `/health`.

## Open questions to confirm with user

1. **Service name + URL.** `chittyledger-gateway` at `ledger.chitty.cc` (claims tier 2 subdomain root) vs. `gateway.ledger.chitty.cc` (subdomain under ledger) vs. something else. Default proposal: **`chittyledger-gateway` at `gateway.ledger.chitty.cc`** — leaves `ledger.chitty.cc` for the ChittyLedger service if/when it gets a Worker.
2. **Repo location.** `CHITTYOS/chittyledger-gateway` (alongside chittyconnect) vs. `CHITTYAPPS/chittyledger-gateway` (alongside mychitty). Default proposal: **`CHITTYOS/`** — it's tier 2 platform infra, not an app.
3. **Outbox storage.** Same DB (new table `public.synthesis_outbox` in ChittyLedger) vs. Cloudflare Queue vs. Durable Object. Default proposal: **same-DB table** — transactional with the event INSERT, simplest semantics, no extra service.
