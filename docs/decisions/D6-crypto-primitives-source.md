# D6 — Crypto Primitives Source

**Status:** ACCEPTED — Option A on 2026-05-23
**Original status:** PROPOSED — 2026-05-17
**Date:** 2026-05-17
**Blocks:** merge of PR #7 (chittyauth `/v1/sign`), merge of PR #8 (chittyledger `/v1/events`)
**Related:** D5 (signing custody), ecosystem-discovery-first rule



## Accepted resolution (2026-05-23)

- **Option A** — chittyauth + chittyledger import canonicalization + hash primitives from ChittyProof; never re-implement.
- **Mechanism choice:** prefer **A1 (npm workspace package `@chittycorp/chittyproof`)** if an internal npm registry is reachable; otherwise **A2 (vendored copy with `// @canon: chittyproof://lib/v2-canonical` provenance header + CI diff check against upstream)** as the v1 bridge. ChittyProof's PENDING deploy status does not block either A1 (library publish, no Worker deploy needed) or A2 (vendor source).
- **Implementation order:** A2 ships first (faster, no registry dependency); A1 supersedes when registry is ready. Either way, three inline implementations are not acceptable.
- **Verifier reuse:** D7's open Q2 (will chittyledger consume `verifyEcdsa` later?) tracked as a follow-up; not blocking PR #7 / PR #8.

## Problem

PRs #7 and #8 each re-implement two primitives inline:

- `canonicalJson(obj)` — RFC 8785-style deterministic JSON canonicalization
- `sha256(bytes)` — payload digest

ChittyProof already owns these primitives as a **Tier 0 (Trust Anchors)** service:

- Repo: `/home/ubuntu/projects/github.com/CHITTYAPPS/chittyproof`
- Domain: `proof.chitty.cc` (status: PENDING)
- Mission (per CHARTER): *"deterministic, court-grade cryptographic integrity primitives — canonicalization, hashing, ECDSA signature verification"*
- Existing modules:
  - `src/lib/chittyproof-v2-canonical.js` — canonical `canonicalJson` + `sha256`
  - `src/lib/chittyproof-verify-ecdsa.js` — ECDSA P-256 verify
- Existing HTTP surface: `/canonicalize`, `/hash`, `/verify`
- Dual export: library (importable) + Worker (callable)

Shipping inline implementations in chittyauth (Tier 1) and chittyledger (Tier 3) means **three parallel implementations of the same trust primitive**, each free to drift. This is exactly the failure mode the Tier 0 trust-anchor designation exists to prevent.

This is also a self-inflicted discovery miss: the global `CLAUDE.md` ecosystem-discovery rule requires querying the registry and reading CHARTER.md before scaffolding. Neither PR did that for ChittyProof.

## Options

### Option A — Import ChittyProof library (RECOMMENDED)

Replace inline `canonicalJson` + `sha256` in PR #7 and PR #8 with imports from ChittyProof's library export.

**Mechanism (pick one at amendment time):**
- **A1 — npm-link / workspace package:** publish `@chittycorp/chittyproof` from ChittyProof's repo; depend on it in chittyauth + chittyledger.
- **A2 — vendored copy with provenance comment:** copy `chittyproof-v2-canonical.js` into each consumer with a header comment `// @canon: chittyproof://lib/v2-canonical — DO NOT EDIT, sync from upstream` and a CI check that diffs against upstream.

A1 is correct long-term; A2 is acceptable for v1 if ChittyProof is not yet publishing.

**Pros:**
- Single source of truth for canonicalization + hash. ChittyProof is the only place these can drift.
- Honors the Tier 0 designation: Tier 1+ services consume, do not re-implement.
- Future verifiers (ChittyProof's own `/verify`, third-party auditors) can trust that what was signed equals what is canonicalized — same code path.
- Closes the discovery miss without service rewrites.

**Cons:**
- Adds a dependency edge: chittyauth + chittyledger now depend on a Tier 0 library. Acceptable — Tier 0 is precisely what they should depend on.
- A1 requires ChittyProof to publish; A2 requires a sync discipline.

### Option B — Keep inline implementations, document divergence

Leave PRs #7 and #8 as-is, add a comment pointing at ChittyProof, accept three copies of the primitive.

**Pros:**
- Zero PR churn.

**Cons:**
- Defeats the trust-anchor model.
- Three implementations will drift the first time someone "fixes" one.
- Cryptographic primitives that don't match across producer (signer) and verifier (ChittyProof) cause silent, court-unsurvivable signature failures.
- Sets the wrong precedent for every future v1 producer.

Rejected.

### Option C — Call ChittyProof at request time (HTTP `/canonicalize` + `/hash`)

Replace inline primitives with HTTP calls to `proof.chitty.cc` on every sign + every write.

**Pros:**
- No code duplication of any form.

**Cons:**
- Adds two synchronous network hops per event (canonicalize + hash) on top of the existing sign hop (D5).
- `proof.chitty.cc` is PENDING — not deployed yet. Blocks both PRs indefinitely.
- Wrong layer: canonicalization is a pure function; making it a network call is over-engineering.

Rejected.

## Recommendation

**Option A** — import ChittyProof's library. Prefer **A1 (npm workspace package)** if ChittyProof can publish in the same sprint; otherwise **A2 (vendored with provenance + CI diff)** as a bridge.

## Implementation (post-decision)

For each of PR #7 and PR #8:

1. Remove inline `canonicalJson` + `sha256` from the diff.
2. Add dependency on `@chittycorp/chittyproof` (A1) or vendor `chittyproof-v2-canonical.js` with provenance header (A2).
3. Replace call sites with `import { canonicalJson, sha256 } from '@chittycorp/chittyproof'` (or vendored path).
4. Re-run unit tests (existing chittyproof tests already cover these primitives — no new tests needed in consumers beyond a smoke test that proves the import works).
5. PR body: link to D6 and to ChittyProof's CHARTER.md.

ChittyProof side (if A1):

1. Publish `@chittycorp/chittyproof` with named exports `canonicalJson`, `sha256`, `verifyEcdsa`.
2. Tag `v0.1.0`; pin consumers to exact version until D6 is COMPLETE.

## Open questions

1. A1 vs A2: does ChittyCorp have an internal npm registry ready, or do we vendor for v1?
2. Should `verifyEcdsa` also be consumed by chittyledger's future read-path verifier? (Yes if D7 lands; flagged.)
3. Does ChittyProof's PENDING status block A1? (No — A1 only needs library publish, not Worker deploy.)
