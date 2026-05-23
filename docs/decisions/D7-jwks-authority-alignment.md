# D7 — JWKS Authority Alignment

**Status:** ACCEPTED — Option A on 2026-05-23
**Original status:** PROPOSED — 2026-05-17
**Date:** 2026-05-17
**Blocks:** merge of PR #7 (chittyauth `/v1/sign`), merge of PR #8 (chittyledger `/v1/events`)
**Amends:** D5 operationally stands; D7 adds a publish-side requirement
**Related:** ChittyAuth CHARTER, ChittyCert CHARTER, ChittyProof CHARTER



## Accepted resolution (2026-05-23)

- **Option A** — cross-publish: ChittyAuth signs (D5 unchanged), ChittyCert registers (canonical PKI), ChittyProof and all verifiers fetch JWKS from `cert.chitty.cc/.well-known/jwks.json` only.
- **D5 amendment**: Q2 (JWKS surface) is amended. `auth.chitty.cc/.well-known/jwks.json` continues to serve (self-consistency + fallback) but the **canonical verifier endpoint is `cert.chitty.cc/.well-known/jwks.json`**.
- **Cross-published namespaces:** both `evt-*` AND `oauth-*` — verifiers should never need two registry URLs (open Q2 resolved).
- **`kid` collision policy:** ChittyCert MUST reject conflicting publishes — collisions are bugs, not last-write-wins (open Q3 resolved).
- **Pre-flight gate (open Q1):** before PR #7's `publishToChittyCert()` ships, confirm ChittyCert can accept `POST /v1/jwks/register` + aggregate into `/.well-known/jwks.json`. If the endpoint does not exist, a parallel ChittyCert PR must precede or co-land with PR #7. ChittyAuth signing must remain functional throughout (publish is best-effort with retry queue per the D7 mechanism spec).
- **Failure model:** signing path must NOT block on registry availability. Registry outage degrades NEW verifiers (cache-miss), not signers.

## Problem

Three Tier 0/1 services have overlapping JWKS claims:

| Service | Tier | JWKS role per its CHARTER |
|---|---|---|
| ChittyAuth | 1 (Core Identity) | "canonical owner of JWKS and token-signing infrastructure" — signs OAuth + (per D5) events |
| ChittyCert | 1 (Core Identity), `cert.chitty.cc` LIVE | "PKI infrastructure, X.509 certificates, OCSP revocation, JWKS key registry, evidence authentication" |
| ChittyProof | 0 (Trust Anchors), `proof.chitty.cc` PENDING | Verifier — expects keys via JWKS from "external key authority (ChittyCert)" (per `chittyproof-verify-ecdsa.js` comment) |

D5 chose ChittyAuth as the **signer** without surfacing that:

1. ChittyCert's charter claims **registry** authority over JWKS.
2. ChittyProof's verify code explicitly expects to fetch JWKS from **ChittyCert**, not ChittyAuth.

If we ship D5 as-is, ChittyProof's verifier will fetch from `cert.chitty.cc/.well-known/jwks.json` and find no `evt-*` keys there — verification fails. Conversely, telling ChittyProof to fetch from `auth.chitty.cc` violates the authority model and embeds a non-canonical PKI dependency into a Tier 0 service.

## Options

### Option A — Cross-publish: ChittyAuth signs, ChittyCert registers (RECOMMENDED)

ChittyAuth retains everything from D5 (key custody, `/v1/sign`, `evt-*` namespace, rotation). On every key rotation/expiry event, ChittyAuth **publishes its public JWK entries to ChittyCert**, which is the canonical PKI registry. Verifiers (ChittyProof and anyone else) fetch from `cert.chitty.cc/.well-known/jwks.json` — the single registry — and find a union of all registered public keys, including `evt-*` from ChittyAuth.

**Mechanism:**
- ChittyAuth gains one outbound call: `POST cert.chitty.cc/v1/jwks/register` (service-token auth) on every `rotateSigningKey()` for `evt-*` and `oauth-*` namespaces.
- ChittyCert exposes `POST /v1/jwks/register` (idempotent on `kid`) and aggregates entries into its public `/.well-known/jwks.json`.
- `auth.chitty.cc/.well-known/jwks.json` remains as a fallback / authoritative-for-auth-keys endpoint; ChittyCert is the canonical aggregator.
- ChittyProof's verifier reads `cert.chitty.cc/.well-known/jwks.json` only.

**Pros:**
- Honors all three charters: ChittyAuth signs (D5 unchanged operationally), ChittyCert registers (its charter claim is satisfied), ChittyProof verifies from the canonical PKI registry (its code comment is satisfied).
- No service rewrite. Net-new = one outbound publish call in ChittyAuth + one ingest endpoint in ChittyCert.
- Verifier side has a single URL to trust — matches PKI norms (you don't fetch keys from N issuers).
- Rotation flow is unchanged from D5 + one publish step.

**Cons:**
- Adds a publish dependency from ChittyAuth → ChittyCert on rotation. Mitigation: queue + retry; rotation is rare (hours-to-days, not request-time).
- Two endpoints serve `/.well-known/jwks.json` (auth + cert). Mitigation: document that ChittyCert is canonical for verifiers; ChittyAuth's endpoint is for self-consistency.

### Option B — Move custody to ChittyCert (reverse D5)

ChittyCert owns private keys and the `/v1/sign` endpoint; ChittyAuth no longer signs events.

**Pros:**
- Single service, single endpoint, no cross-publish.

**Cons:**
- Reverses D5 — re-litigates an ACCEPTED decision.
- Throws away ~150 LOC already implemented in chittyauth (PR #7).
- ChittyCert today is a PKI / X.509 service — not currently designed to sign arbitrary JWS payloads on request. Net-new is significantly more than the ChittyAuth path was.
- Splits OAuth signing (stays in ChittyAuth) from event signing (moves to ChittyCert) — fragments custody in a different direction.

Rejected.

### Option C — Status quo: ChittyAuth is the only JWKS URL

Tell ChittyProof and all verifiers to fetch from `auth.chitty.cc/.well-known/jwks.json`. Ignore ChittyCert's charter claim.

**Pros:**
- Zero new wiring.

**Cons:**
- Direct CHARTER violation for ChittyCert.
- Embeds ChittyAuth as a verify-time dependency for every Tier 0 trust-anchor service. Inverts the trust hierarchy: a Tier 1 service becomes a hard dependency of a Tier 0 service.
- Contradicts ChittyProof's existing code comment — first reader will be confused or "fix" it.

Rejected.

### Option D — Defer: ship D5 as-is, fix later

Merge PRs #7 and #8, deal with the authority overlap when ChittyProof's verifier actually goes to use it.

**Pros:**
- Unblocks v1 ship today.

**Cons:**
- "Later" never comes. The first verifier will hardcode `auth.chitty.cc/.well-known/jwks.json` and that URL becomes load-bearing.
- Trust-anchor architecture decisions are exactly the ones you don't defer; rip-out cost is much higher than amend-now cost.

Rejected.

## Recommendation

**Option A** — ChittyAuth signs (D5 stands), ChittyCert registers (canonical PKI), ChittyProof verifies from ChittyCert.

Authority model:

```
      ┌──────────────┐   sign request    ┌──────────────┐
      │   Gateway    ├──────────────────►│  ChittyAuth  │
      │              │◄──────────────────┤   (signer)   │
      └──────────────┘   sig + kid       └──────┬───────┘
                                                │ on rotation:
                                                │ POST /v1/jwks/register
                                                ▼
                                         ┌──────────────┐
                                         │  ChittyCert  │
                                         │  (registry)  │
                                         └──────┬───────┘
                                                │ .well-known/jwks.json
                                                ▼
                                         ┌──────────────┐
                                         │ ChittyProof  │
                                         │  (verifier)  │
                                         └──────────────┘
```

## What this changes vs D5

D5's three accepted resolutions stand:
- Custody: ChittyAuth.
- `signer_cid`: `chittyauth-event-signer`.
- Fail-closed on signer unreachability.

D5's Q2 (JWKS surface) is **amended**: `auth.chitty.cc/.well-known/jwks.json` is still served (for self-consistency), but **`cert.chitty.cc/.well-known/jwks.json` is the canonical verifier endpoint**. PR #7's documentation and any client examples must point at ChittyCert, not ChittyAuth, for verification.

## Implementation (post-decision)

ChittyAuth (PR #7 amendment):
1. Add `publishToChittyCert(kid, publicJwk)` called from `rotateSigningKey()` and `ensureSigningKey()` (for `evt-*` and `oauth-*` namespaces).
2. Add env: `CHITTYCERT_REGISTER_URL`, `CHITTYCERT_SERVICE_TOKEN`.
3. Make publish best-effort with retry queue; signing must not block on registry availability (registry is for verifiers, not signers).
4. PR body: link D5 + D7; note that verifiers fetch from `cert.chitty.cc`.

ChittyCert (separate PR in chittycert repo):
1. Add `POST /v1/jwks/register` — idempotent on `kid`, service-token auth.
2. Aggregate registered entries into `GET /.well-known/jwks.json`.
3. Reject keys whose `kid` collides across publishers.

ChittyProof (when verifier ships):
1. Hardcode `cert.chitty.cc/.well-known/jwks.json` as the verify-time JWKS URL.
2. Cache with TTL matching key rotation cadence.

ChittyLedger (PR #8): no change required for D7 — chittyledger only stores `signature_kid`, it does not verify. Verification is downstream.

## Open questions

1. ChittyCert's existing endpoint: does it already aggregate JWKS, or does the registry need to be built? (Charter says it owns JWKS registry; need to confirm implementation state.)
2. Should `oauth-*` keys also be cross-published, or only `evt-*` for v1? (Recommend: both, for consistency — verifiers should never need two registry URLs.)
3. `kid` namespace conflict policy: registry rejects, or last-write-wins? (Recommend: reject — collisions are bugs.)
