# Phase 0 R2 — ChittyConnect Route Surface Report

**Date:** 2026-05-06
**Repo inspected:** `/home/ubuntu/projects/github.com/CHITTYOS/chittyconnect/`
**Entrypoint:** `src/index.js` (Hono app, deployed as Cloudflare Worker via `wrangler.jsonc`)
**Main router:** `src/api/router.js`
**Health endpoint:** `GET /api/health` → returns full route map at v2.0.2
**Status endpoint:** `GET /api/v1/status` (unauthenticated, mesh health)

## Headlines

1. **ChittyConnect is a proxy/router, not the canonical ledger writer.** It does not INSERT into `event_ledger` anywhere in `src/`. Zero matches for `event_ledger` across the entire src tree.
2. **The closest write surface is `ChronicleEngine` → `chronicle_events` table** (`src/services/chronicle-engine.js:59`), exposed at `POST /api/chittychronicle/events`. This is a *separate* table from the canonical spine `public.event_ledger` identified in R1. **Schema divergence — ChittyConnect's chronicle is parallel infrastructure, not the spine.**
3. **All other "ledger-like" writes are HTTP fetches to sibling services** — `https://sync.chitty.cc/api/sync`, `https://evidence.chitty.cc/api/ingest`, `https://track.chitty.cc/*`. ChittyConnect proxies; the actual writers are downstream.
4. **No surface currently accepts a v1 spec event** (substrate, plane, signer_cid, signature_proof, payload_hash, sequence, occurred_at, canon_version) — the chronicle_events shape is `(service, action, user_id, user_email, metadata, related_events, triggered_by, integrations, status, error_message)`. Migration B added the v1 columns to `event_ledger`, not to `chronicle_events`.

## Route mount table (from `src/api/router.js:138-193`)

| Mount | Module | Surface kind |
|---|---|---|
| `/api/chittyid` | chittyid.js | proxy → chittyid.chitty.cc |
| `/api/chittycases` | chittycases.js | proxy |
| `/api/chittydisputes` | chittydisputes.js | proxy |
| `/api/chittytrack` | chittytrack.js | proxy → track.chitty.cc (Bearer service token) |
| `/api/chittyauth` | chittyauth.js | proxy |
| `/api/chittyfinance` | chittyfinance.js | proxy |
| `/api/chittycontextual` | chittycontextual.js | proxy |
| **`/api/chittychronicle`** | **chittychronicle.js** | **direct DB write — `chronicle_events`** |
| `/api/chittyquality` | chittyquality.js | proxy |
| `/api/chittysync` | chittysync.js | proxy → sync.chitty.cc |
| `/api/chittyevidence` | chittyevidence.js | proxy → evidence.chitty.cc |
| `/api/registry` | registry.js | proxy → registry.chitty.cc |
| `/api/services` + `/api/v1/services` | services.js | service catalog |
| `/api/thirdparty` | thirdparty.js | OpenAI/Notion/Google proxies |
| `/api/google` | google.js | Google API proxy |
| `/api/mercury/*` | rewrite → /api/thirdparty/mercury | legacy rewrite |
| `/api/credentials` | credentials.js | 1Password / CF Secrets |
| `/api/intelligence` | intelligence.js | ContextConsciousness, MemoryCloude |
| `/api/context` | context.js | direct DB write — `sync_events` (line 100) |
| `/api/context/tasks` | tasks.js | task queue |
| `/api/files` | files.js | R2/file ops |
| `/api/dashboard` | dashboard.js | aggregate read |
| `/api/v1/context` | context-resolution.js | context resolver |
| `/api/v1/intelligence` | context-intelligence.js | intelligence v2 |
| `/mcp` | mcp.js | MCP protocol (Claude) |
| `/chatgpt/mcp` | chatgpt-mcp.js | MCP protocol (ChatGPT) |
| `/api/v1/exports` | exports.js | export builders |
| `/api/v1/cert` | cert.js | ChittyCert |
| `/api/v1/connect` | connect.js | connection mgmt |
| `/api/connections` | connections.js | connection registry + health |
| `/api/auth/keys` | auth-keys.js | API key issuance |
| `/api/v1/context/prompts` | prompts.js | prompt templates |
| `/api/v1/tenants/migration` | tenant-migration.js | tenant data migration |
| `/api/v1/tenants` | tenants.js | tenant CRUD |
| `/api/v1/sessions` | sessions.js | session tracking |

Auth: `authenticate` middleware on `/api/*` (`src/api/middleware/auth.js`); rate limit on `/api/v1/intelligence/*`. CORS allowlists ChatGPT, chittyconnect-ui, all `*.chitty.cc`, and localhost dev ports.

## Direct DB writers found in ChittyConnect

| File | Table | Notes |
|---|---|---|
| `src/services/chronicle-engine.js:59` | `chronicle_events` | The "log this event" surface for `/api/chittychronicle/events` (POST). Schema bootstrapped in `connect()` via `CHRONICLE_SCHEMA`. **Not the canonical event_ledger.** |
| `src/api/routes/context.js:100` | `sync_events` | `INSERT INTO sync_events` — fired by context route, separate table again |

## Implications for MyChitty v1

- **No existing ChittyConnect endpoint maps to the spec's event-write contract.** A new route is required (proposal: `POST /api/v1/events` or `POST /api/v1/ledger/events`) that validates the v1 schema (substrate, plane, signer_cid, signature_proof, payload_hash, payload_ref, bond_id, linked_event_hash, sequence, occurred_at, canon_version), enforces the append-only triggers from Migration A, computes the hash chain (currently 0/225 rows populated per R1), and writes to `public.event_ledger` in Neon project `shy-sound-75632194`.
- **`chronicle_events` and `sync_events` are pre-existing parallel ledgers.** Decision needed:
  - **(a)** Treat them as legacy and route all new substrate writes to `event_ledger` (cleanest, matches spec §5).
  - **(b)** Keep them as service-local audit trails and have them mirror to `event_ledger` via outbox/trigger (preserves existing consumers but doubles write load).
  - **(c)** Consolidate them into `event_ledger` via migration (heaviest, but closes the divergence permanently).
- **Live writers from R1 (alchemist every 6h, sync-daemon stale)** do not flow through ChittyConnect — they write to Neon directly. ChittyConnect's chronicle path is *additional* writer traffic, not the existing path.
- **No signature/hash plumbing exists in ChittyConnect today.** The v1 contract (P-Synthetic signed events) has no implementation surface here; it must be added (likely as middleware on the new events route + a signing helper that the three substrates call before POSTing).

## Pending follow-ups for R5 (Implementation Diff)

1. Author `POST /api/v1/events` route on ChittyConnect with v1 schema validation → writes to `event_ledger` directly via Neon connection.
2. Decide chronicle_events / sync_events fate (a/b/c above).
3. Wire substrate clients (Claude Code, OpenClaw, ChatGPT) to call the new route with signed payloads.
4. Implement hash chain computation at the gateway layer (R1 finding: 0/225 rows have hash chain; needs gateway-side fix).

## R2 status

**Complete.** ChittyConnect surface is mapped. The route map needed for v1 does not yet exist — that's an R5 deliverable. No blockers for R3 (P-Synthetic Identity).
