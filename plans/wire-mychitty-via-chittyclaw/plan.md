# Wire MyChitty via chittyclaw AI Gateway

**Branch:** `wire-mychitty-via-chittyclaw`
**Description:** Route mychitty substrate AI traffic through the `chittyclaw` Cloudflare AI Gateway and use its observability hooks as the canonical EXTRACT source feeding `event_ledger`.

## Goal
Make `chittyclaw` (CF AI Gateway, account `0bc21e3a5a9de1a4cc843be9c3e98121`) the single AI transport seam for mychitty substrates so every model call is observable, attributable, cacheable — and replayable into the canonical ledger spine without re-running the model. This converts the spec's §8.1 EXTRACT step from "best-effort substrate self-reporting" into "verified gateway-side capture."

## Non-goals (this PR)
- Migrations A & B on `event_ledger` (separate PR — gated on R1 approval)
- Phase 0 R2–R5 verification reports (separate PRs)
- Synthesis/rewrite/read-pack (Phase 4–5)
- Routing Anthropic-managed Claude Code or OpenAI-managed ChatGPT traffic through the gateway (those can't be redirected at the LLM transport — they participate via post-hoc event emission, not gateway routing)

## Constraints (binding)
- Spec §3.2 Axiom Zero — no fake events, no silent writes, no unmarked simulations
- Spec §1.1 — Phase 0 STOP-GATE in effect; this PR adds **observability infrastructure** only (no writes to `event_ledger` until Migrations A/B land)
- chittyclaw config (verified via API): `authentication: true`, rate `50/min`, cache TTL ~30d, retry 3x exp backoff
- Endpoint shapes (verified live, 2026-05-03):
  - **Workers-AI native** (200 OK confirmed): `https://gateway.ai.cloudflare.com/v1/{acct}/chittyclaw/workers-ai/{model}` — POST with `{"messages":[...],"max_tokens":N}`
  - **OpenAI-compat**: `https://gateway.ai.cloudflare.com/v1/{acct}/chittyclaw/compat/chat/completions` — for OpenAI-flavored model names + OpenAI provider key (NOT for `@cf/*` models — returns 400 "Invalid provider")
- **Auth is one-token** (verified): a single `cfat_*` (account-scoped CF API token, created in the AI Gateway dashboard's "Create authentication token" button) suffices for **both** gateway auth AND workers-ai provider auth. Send on either `Authorization: Bearer ...` or `cf-aig-authorization: Bearer ...` (or both — gateway accepts).
- Test harness: `/home/ubuntu/.ops/chittyclaw/test.sh` — exercises both header modes and both URL shapes; never echoes token values

## Implementation Steps

### Step 1: Document chittyclaw as the v1 substrate transport (spec addendum)
**Files:**
- `docs/specs/mychitty-v1-light-the-substrate.md` (new §18.x or §25.x — chittyclaw as observability ingress)
- `docs/verification/phase-0/06-chittyclaw-transport.md` (new — gateway capability inventory: auth mode, rate, cache, retry, log retention, supported provider compat layers)

**What:** Add a §18-adjacent subsection that names chittyclaw as the v1 EXTRACT ingress for substrates whose LLM transport we control (OpenClaw + future synthetic clients). Explicitly document which substrates **cannot** be routed (Claude Code, ChatGPT — vendor-controlled) and define their post-hoc event-emission contract instead. Capture the verified gateway config snapshot.

**Testing:** Doc-only step; verified by reading. Cite chittyclaw API GET response in the verification report so authority tier = "verified operational evidence" per spec §1.3.

### Step 2: Persist the chittyclaw `cfat_*` token and wire OpenClaw substrate to use it
**Files:**
- `~/.openclaw/openclaw.json` (model provider block — point to chittyclaw workers-ai endpoint, attach `Authorization` header)
- 1Password item: `op://synthetic-prod/Cloudflare AI Gateway - chittyclaw` (category: API Credential), fields:
  - `token` (concealed) — single `cfat_*` token from the chittyclaw dashboard (does both gateway + provider auth)
  - `account_id` = `0bc21e3a5a9de1a4cc843be9c3e98121`
  - `gateway_id` = `chittyclaw`
  - `endpoint_workers_ai` = `https://gateway.ai.cloudflare.com/v1/0bc21e3a5a9de1a4cc843be9c3e98121/chittyclaw/workers-ai/`
  - `endpoint_compat` = `https://gateway.ai.cloudflare.com/v1/0bc21e3a5a9de1a4cc843be9c3e98121/chittyclaw/compat/chat/completions` (reserved for OpenAI/Anthropic providers, not `@cf/*`)
- `docs/verification/phase-0/06-chittyclaw-transport.md` (append "OpenClaw wiring evidence" section with redacted curl proving the verified 2026-05-03 round-trip)

**What:** Rotate the leaked `cfat_*` and `cfut_*` tokens visible in this session's transcript, mint a fresh `cfat_*` from the AI Gateway dashboard's "Create authentication token" button, persist via the rotation one-liner from chittyconnect-concierge (single-token form). Configure OpenClaw to POST model calls to `…/chittyclaw/workers-ai/{model}` with `Authorization: Bearer <token>` and metadata header `cf-aig-metadata: {"chitty_id":"...","substrate":"openclaw","session_id":"..."}`. Verify the same 200 round-trip seen in the live test, plus a fresh log entry in the gateway logs API.

**Testing:** Run `/home/ubuntu/.ops/chittyclaw/test.sh` (workers-ai shape) → expect HTTP 200 + a real model response (already proven once). Then `curl` the gateway logs API → expect to see that exact request with the metadata attached. No mock; real provider call. Capture redacted output as R6 evidence.

**[NEEDS CLARIFICATION]** Which provider should chittyclaw route to for OpenClaw? Anthropic, OpenAI, or workers-ai? OpenClaw's local-model story (Ollama) implies it doesn't currently call any cloud provider — does this PR change that, or is OpenClaw routed through chittyclaw only when it falls back to a cloud model?

### Step 3: Build the chittyclaw → ledger EXTRACT shim (read-only first)
**Files:**
- `services/chittyclaw-extract/` (new — small Worker or Node script)
  - `src/poll-logs.ts` — fetch chittyclaw logs via CF API since last cursor
  - `src/transform.ts` — map gateway log entry → CanonicalEvent shape (per spec §9.3) with `substrate`, `chitty_id`, `session_id` from metadata
  - `src/dry-run.ts` — emit transformed events to stdout / a log file; **do not insert into `event_ledger` yet**
- `services/chittyclaw-extract/README.md`
- `services/chittyclaw-extract/wrangler.jsonc` (if Worker) **or** root `package.json` script (if Node)

**What:** Stand up the EXTRACT side of the pipeline in **observe-only** mode. Pull real chittyclaw logs, transform them to CanonicalEvent shape, write to a local NDJSON file. This proves the ingress works against real gateway data without violating the STOP-GATE on `event_ledger` writes.

**Testing:** Run the script after Step 2 has produced ≥1 real OpenClaw call. Expect NDJSON output with a CanonicalEvent envelope per gateway log entry, populated `substrate=openclaw`, `chitty_id=<minted>`, `payload_hash` (sha256 of canonical serialization), `signer_cid=null` (signing deferred to Phase 1 proper), `event_hash=null` (gateway wiring step in chittyconnect, not here).

### Step 4: Verification report — Phase 0 R6 (chittyclaw transport)
**Files:**
- `docs/verification/phase-0/06-chittyclaw-transport.md` (finalize)

**What:** Close the loop with a verification report following the same structure as R1 (`01-ledger-spine.md`): summary, evidence, schema/config inspection, gaps, exit criteria. Confirms chittyclaw is real, authenticated, observable, and transformable into the v1 CanonicalEvent shape — and that the EXTRACT shim works against real data. Recommend promotion of chittyclaw as the v1 substrate transport for any non-vendor-controlled substrate.

**Testing:** Doc completeness check. Cross-reference §1.3 authority tiers — every claim must be backed by verified evidence (gateway API responses, NDJSON sample, OpenClaw config diff).

## Cross-repo touchpoints
- `mychitty` — primary
- `~/.openclaw/openclaw.json` — config-only edit on the operator VM (not a repo commit; documented in R6 as evidence)
- `chittyconnect` — **untouched** in this PR (ChittyConnect Write Gateway hash-chain wiring is Phase 1 proper)
- `event_ledger` — **untouched** in this PR (writes gated on Migrations A/B)

## Open questions to resolve before merge
1. ~~**[NEEDS CLARIFICATION]** Vault location for chittyclaw token~~ — **RESOLVED:** `op://synthetic-prod/Cloudflare AI Gateway - chittyclaw/token` (single `cfat_*`, does both gateway + provider auth; verified live 2026-05-03 against `@cf/meta/llama-3.1-8b-instruct`).
2. ~~**[NEEDS CLARIFICATION]** Provider target~~ — **RESOLVED for v1:** workers-ai via `/workers-ai/{model}` URL shape (200 confirmed). OpenAI/Anthropic compat layers exist on `/compat/chat/completions` but require their own provider keys; out of scope unless OpenClaw needs a non-CF model.
3. **[NEEDS CLARIFICATION]** Should the EXTRACT shim live inside `mychitty/` (this repo) or be a sibling repo `chittyclaw-extract`?
4. ~~**[NEEDS CLARIFICATION]** OpenClaw's default model transport~~ — **RESOLVED:** chittyclaw IS OpenClaw's default model transport. Step 2 changes OpenClaw's primary model provider to workers-ai via chittyclaw (`/workers-ai/{model}` URL shape, single `cfat_*`); Ollama is no longer the default. Operator-confirmed 2026-05-03.

## Acceptance checklist (PR-level)
- [ ] Spec addendum committed and cross-referenced from §18
- [ ] R6 verification report committed under `docs/verification/phase-0/`
- [ ] OpenClaw config edit captured in R6 as redacted diff
- [ ] EXTRACT shim runs against real chittyclaw logs and produces ≥1 NDJSON CanonicalEvent
- [ ] Zero writes to `public.event_ledger` (verify via `SELECT MAX(timestamp) FROM event_ledger` before/after — must not increase from this PR's activity)
- [ ] All four [NEEDS CLARIFICATION] items resolved in PR description
