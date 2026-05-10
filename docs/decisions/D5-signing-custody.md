# D5 — Event Signing Custody

**Status:** ACCEPTED — Option A (ChittyAuth) on 2026-05-10
**Date:** 2026-05-10

## Accepted resolution

- **Custody:** Option A — ChittyAuth owns event signing.
- **Q1 — `signer_cid`:** mint a dedicated service ChittyID (`chittyauth-event-signer`) — not reused from ChittyAuth's OAuth service identity. Clean audit separation.
- **Q2 — JWKS surface:** shared `auth.chitty.cc/.well-known/jwks.json` with `kid` namespace `evt-*`.
- **Q3 — failure mode:** fail-closed. Gateway returns 503 on ChittyAuth unreachability; event is not written; caller retries.
**Blocks:** D2 (gateway shape), D3 (sequence allocation), D4 (sponsor_bond), every v1 event with `signer_cid`/`signature_proof`/`signature_alg`/`signature_kid`
**Spec:** `docs/specs/mychitty-v1-light-the-substrate.md` §11.2 — defers to "ChittyConnect signing model" which does not exist
**Related findings:** R2 (ChittyConnect is a router, not a signer), R4 (no signing-key flow anywhere), R5 §1.2

## What needs to exist

A v1 `CanonicalEvent` carries four signing fields:

| Field | Meaning | Comes from |
|---|---|---|
| `signer_cid` | ChittyID of the signing principal (typically the gateway service identity, **not** the entity) | service identity, durable |
| `signature_proof` | Detached JWS or compact-form signature over `payload_hash` + canonical event header | private key, request-time |
| `signature_alg` | `EdDSA` or `ES256` | key metadata |
| `signature_kid` | JWK `kid` matching a published JWKS entry | key metadata |

A consumer must be able to: fetch JWKS, find `kid`, verify signature against `payload_hash`, and trust the result without consulting any other service.

Three options for where the private key lives and who calls `sign()`.

## Option A — ChittyAuth owns signing (RECOMMENDED)

**Where:** `auth.chitty.cc`

**Existing surface:**
- `neon_auth.jwks` table in ChittyOS-Core already stores `publicKey` + `privateKey` per `kid` with rotation
- `GET /.well-known/jwks.json` already public
- `POST /v1/jwks/rotate` already exists (service-token auth)
- `getPublicJwks()`, `ensureSigningKey()`, `rotateSigningKey()` already implemented in `src/services/jwks.service.ts`

**What's net-new:**
- `POST /v1/sign` (service-token auth) — accepts `{ payload_hash, header }`, returns `{ signature_proof, signature_alg, signature_kid, signer_cid }`. ChittyAuth's service ChittyID is the `signer_cid`.
- 1 new method on `jwks.service.ts`: `signDetached(databaseUrl, payloadHash, header)` — picks the freshest non-expired key, signs, returns the four fields.

**Pros:**
- 80% of the code already exists. Net-new = ~150 LOC + 1 route.
- Key custody is centralized — rotation, expiry, revocation all already work.
- JWKS is already on a public well-known endpoint; consumers verify offline.
- ChittyAuth is tier 1 (Core Identity) — it's where signing principals belong canonically.
- No new service to deploy, register, or monitor.
- Private key never leaves ChittyAuth's worker.

**Cons:**
- Adds a synchronous network hop on every `write_event` (gateway → auth.chitty.cc → gateway → DB). Latency budget: +30–80ms.
- ChittyAuth becomes a hard dependency on the write path — outage = no events.
- ChittyAuth's existing JWKS is currently used for OAuth/JWT issuance; mixing it with event signing means a single key compromise affects both. Mitigation: separate `kid` namespace (`evt-*` for event keys, `oauth-*` for OAuth) — already supported by the schema.

**Mitigations:**
- Cache `signer_cid` + `signature_kid` at the gateway; refresh hourly.
- If ChittyAuth is unreachable: fail-closed (no event written) — correct behavior for a canon ledger.
- Separate `kid` namespace in `neon_auth.jwks` (cheap; just a naming convention + filter).

## Option B — ChittyConnect owns signing

**Where:** existing `chittyconnect` Worker

**What's net-new:**
- Add `neon_auth.jwks` access (or a new `connect_signing_keys` table) + key gen + rotation
- Implement `signDetached()` from scratch (or copy from ChittyAuth — duplicates code)
- Expose `POST /api/v1/sign` (service-token auth)

**Pros:**
- ChittyConnect is on every write path anyway (R2: router for all proxies). Same-Worker call has no network hop.
- Spec §7.1 says "ChittyConnect Write Gateway" — keeping signing here is the most literal reading.

**Cons:**
- ChittyConnect today does **zero direct writes to `event_ledger`** (R2). Adding signing means also adding write-path responsibilities — that's actually D2, not D5.
- Duplicates ChittyAuth's JWKS work. Two key stores, two rotation surfaces, two JWKS endpoints. Doubles the audit surface.
- ChittyConnect is tier 2 (platform) — putting trust-anchor crypto in a router service violates layering.
- No existing JWKS infra in `chittyconnect/src/services/`. Net-new = ~600 LOC (key gen, JWK serialization, rotation, JWKS endpoint, sign endpoint, schema).

## Option C — New `chittysigner` service

**Where:** new Worker at `signer.chitty.cc`

**What's net-new:**
- Full service: `wrangler.jsonc`, charter triad (CHARTER/CHITTY/CLAUDE), registration, JWKS infra, key store, sign endpoint, monitoring.

**Pros:**
- Single-purpose, easiest to audit and reason about.
- Could later host non-event signing (mirror exports, attestations) without contaminating ChittyAuth.

**Cons:**
- Most code to write.
- Yet-another-service to deploy, monitor, register, secret-manage.
- No existing consumer — would be the only caller of itself for months.
- Defeats the principle of using ChittyAuth for what it already does.

## Recommendation

**Option A — ChittyAuth owns signing.**

Reasoning:
1. The infrastructure already exists. Net-new is ~150 LOC + 1 route + 1 service-token grant.
2. ChittyAuth is the canonical signing principal in the ecosystem — every other crypto-anchor (OAuth JWTs, registration tokens, JWKS) already lives there. Putting event signing anywhere else fragments custody.
3. JWKS rotation, expiry, public fetch are already solved. Consumers verify offline against `auth.chitty.cc/.well-known/jwks.json`.
4. The latency hit (+30–80ms per write) is acceptable for a canonical ledger; v1 is not high-throughput.
5. Failure mode is clean: ChittyAuth down → gateway fails-closed → no half-signed events.

## What this unblocks

- **D2 (gateway):** the gateway now has a single dependency (`auth.chitty.cc/v1/sign`); doesn't matter if D2 picks "new gateway" or "alchemist upgrade". Either calls ChittyAuth.
- **D3 (sequence):** orthogonal — sequence allocation can be DB-side or gateway-side regardless.
- **D4 (sponsor_bond):** when bond writes happen (`bonded_action.*`), the gateway makes two `sign()` calls (one per linked entry). No bond-specific signing logic.

## Implementation sketch (post-decision)

Net-new in ChittyAuth:

```ts
// src/services/jwks.service.ts — add
export async function signDetached(
  databaseUrl: string,
  payloadHash: string,        // hex, lowercase, sha-256 over canonical payload
  header: { event_id: string; entity_cid: string; sequence: number; occurred_at: string },
): Promise<{ signature_proof: string; signature_alg: string; signature_kid: string; signer_cid: string }> {
  // 1. fetch freshest non-expired private key WHERE kid LIKE 'evt-%'
  // 2. canonicalize header + payload_hash → JWS payload (RFC 7515 detached, b64url)
  // 3. EdDSA sign with private JWK
  // 4. return { signature_proof: '<protected_header>..<sig>', signature_alg: 'EdDSA',
  //             signature_kid: kid, signer_cid: env.CHITTYAUTH_SERVICE_CID }
}

// src/routes/sign.routes.ts — new file
signRoutes.post('/v1/sign', requireServiceToken, async (c) => {
  const { payload_hash, header } = await c.req.json();
  // validate shape (zod)
  const sig = await signDetached(c.env.NEON_DATABASE_URL, payload_hash, header);
  return c.json(sig);
});
```

Net-new in event_ledger consumers: nothing. They already have `signer_cid`, `signature_proof`, `signature_alg`, `signature_kid` columns from Migration B. They just need to pull JWKS and verify.

## Open questions to confirm with user

1. Confirm ChittyAuth's service ChittyID exists and is appropriate as `signer_cid`. (If not, mint one.)
2. Confirm separate `kid` namespace (`evt-*`) is acceptable, or require a fully separate JWKS endpoint (e.g., `auth.chitty.cc/.well-known/jwks-events.json`).
3. Confirm fail-closed behavior is correct — i.e., writes fail when ChittyAuth is unreachable. (Alternative: gateway holds a short-lived signing token that lets it sign locally for a limited window. More complex; not recommended for v1.)
