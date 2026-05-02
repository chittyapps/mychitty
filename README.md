# MyChitty

Per-user, partially sovereign, digital-plane synthetic ChittyEntity that expresses through multiple substrates while retaining one continuous identity.

**Status:** v1 — DRAFT, schema-unverified. **Phase 0 STOP-GATE in effect.** No production code, schema changes, queue creation, or service writes until the verification packet is complete and approved.

## Layout

```
docs/
  specs/                              # Build specs (canonical)
    mychitty-v1-light-the-substrate.md
  verification/
    phase-0/                          # Verification packet (in progress)
      01-ledger-spine.md
      02-chittyconnect-routes.md
      03-p-synthetic-identity.md
      04-outbox-worker.md
      05-implementation-diff.md
```

## v1 mission lock

> Make one P-Synthetic entity write real signed events from three substrates into one verified canonical ledger spine, then rehydrate from those events.

See `docs/specs/mychitty-v1-light-the-substrate.md` for the full spec.

## Current phase

Phase 0 — Verification Packet. See `docs/verification/phase-0/`.
