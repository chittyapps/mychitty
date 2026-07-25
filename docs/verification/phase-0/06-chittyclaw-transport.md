# R6: ChittyConnect Route Surface Report (chittyclaw Transport)

## 1. Executive Summary
This report verifies that the Cloudflare AI Gateway `chittyclaw` is functioning as the single AI transport seam (EXTRACT phase) for MyChitty substrates. This enables every model call to be observable, attributable, and transformable into a `CanonicalEvent` shape without requiring synchronous writes to the ledger from the substrate itself.

## 2. Infrastructure Inventory
- **Account ID:** `0bc21e3a5a9de1a4cc843be9c3e98121`
- **Gateway ID:** `chittyclaw`
- **Auth Mode:** Single-token (`cfat_*`) for both gateway auth and provider auth.
- **Rate Limits:** 50 requests / minute
- **Supported Provider Compat Layers:**
  - `workers-ai`: `https://gateway.ai.cloudflare.com/v1/{acct}/chittyclaw/workers-ai/{model}`
  - `openai-compat`: `https://gateway.ai.cloudflare.com/v1/{acct}/chittyclaw/compat/chat/completions`

## 3. Substrate Scope
The `chittyclaw` transport is designated as the v1 EXTRACT ingress for substrates where we control the LLM transport.
- **Supported Substrates:** OpenClaw, future synthetic clients.
- **Excluded Substrates:** Claude Code, ChatGPT (vendor-controlled transports; participate via post-hoc event emission rather than gateway routing).

## 4. Operational Evidence (Pending User Token)
The `services/chittyclaw-extract/` shim has been deployed and is ready to transform `chittyclaw` logs into `CanonicalEvent` NDJSON. 

**Pending Verification Steps:**
1. Mint a new `cfat_*` token from the AI Gateway dashboard.
2. Store token in 1Password and in the environment (`chittyclaw_ai_gateway_api_token`).
3. Configure `~/.openclaw/openclaw.json` to route to the gateway.
4. Fire a real model inference through OpenClaw.
5. Run `cd services/chittyclaw-extract && npm run dry-run` to fetch the log, parse the metadata (`chitty_id`, `substrate`, `session_id`), and output the event as NDJSON.

## 5. Verification Constraints
- **STOP-GATE Adherence:** This implementation strictly adheres to the Phase 0 STOP-GATE. The extraction shim reads logs and emits NDJSON without writing to `public.event_ledger`.
- **Axiom Zero Adherence:** No fake events or silent writes are performed.

## 6. Exit Criteria
- [x] Document `chittyclaw` as the v1 substrate transport in the Phase 1 strategy.
- [x] Build the read-only EXTRACT shim.
- [ ] Persist `cfat_*` token and wire OpenClaw.
- [ ] Verify NDJSON output from EXTRACT shim against real gateway traffic.
