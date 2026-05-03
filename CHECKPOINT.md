# Session Checkpoint — MyChitty v1 Phase 0

**Date:** 2026-05-03
**Project:** mychitty (CHITTYAPPS/mychitty)
**Repo path:** `/home/ubuntu/projects/github.com/CHITTYAPPS/mychitty/`
**Branch:** main (no remote configured)
**HEAD:** `b446ddd remediate R1: Migrations A+B + spec §5 amendment`

## What this is

MyChitty v1 — Phase 0 Verification Packet under STOP-GATE. Spec is at `docs/specs/mychitty-v1-light-the-substrate.md`. Mission: one P-Synthetic entity writes signed events from three substrates (Claude Code, OpenClaw, ChatGPT) into one canonical ledger spine, then rehydrates.

## Accomplished

- **Repo created** at `/home/ubuntu/projects/github.com/CHITTYAPPS/mychitty/` (git init, 3 commits, no remote).
- **Spec saved verbatim** from author at `docs/specs/mychitty-v1-light-the-substrate.md`.
- **Phase 0 R1 (Ledger Spine Verification) — COMPLETE.** Report at `docs/verification/phase-0/01-ledger-spine.md`. Headlines:
  - **Canonical spine = `public.event_ledger`** in Neon project `ChittyLedger` (id `shy-sound-75632194`, org ChittyFoundation `org-old-mountain-22774840`). Default branch: `br-steep-fog-ae9tdd66`.
  - 225 rows now (was 224 at R1), live writers: `chittyagent-alchemist` (every 6h) + `chittymarket-sync-daemon` (stale, last 2026-04-17).
  - Real P-Synthetic ChittyID in production: `03-1-USA-8244-P-2603-0-33` (format `VV-G-LLL-SSSS-T-YM-C-X` confirmed via column comment).
  - Schema has P/L/T/E/A CHECK constraint citing `chittycanon://gov/governance#core-types`.
  - Hash chain columns exist but **0/225 rows populated** — gateway-layer fix needed.
  - **Append-only NOT enforced** — no triggers, no RLS.
  - **12 spec event types missing from enum** (DECISION_COMMITTED, ACTION_*, BONDED_*, SPONSOR_BOND_*, SYNTHESIS_COMPLETED, SURFACE_PACK_READ, MIRROR_EXPORTED, AUTHORITY_UPDATED, INTERACTION_OBSERVED).
  - **13 spec columns missing**: signer_cid, signature_proof, signature_alg, signature_kid, payload_hash, payload_ref, bond_id, linked_event_hash, substrate, plane, sequence, occurred_at, canon_version.
- **Spec §5 amended in-place** with R1's verified state (originals preserved for diff visibility).
- **Migrations A + B written** at `migrations/0001_event_ledger_append_only.sql` and `migrations/0002_event_ledger_v1_columns.sql`. Both additive, non-destructive.
- **Migrations applied to Neon BRANCH `br-fancy-art-aevxcl6o`** (`mychitty-v1-migrations-test`, parent = default `br-steep-fog-ae9tdd66`). All 6 verification checks PASS:

  | Check | Result |
  |---|---:|
  | New columns | 13/13 |
  | New enum values | 12/12 |
  | New CHECK constraints | 3/3 |
  | New partial indexes | 4/4 |
  | Append-only triggers | 2/2 |
  | Rows unchanged | 225 |

  Plus behavioral: UPDATE blocked, DELETE blocked, INSERT works.

## NOT done — explicit user go required

**Task #7: apply Migrations A+B to default branch `br-steep-fog-ae9tdd66`.** User had said "go" for branch; needs to say "go default" before production-DDL apply. Live writers (alchemist, sync-daemon) keep INSERTing during/after — all additive, all compatible.

**Tasks #2–5 of Phase 0 Verification Packet still pending:**
- R2 ChittyConnect Route Surface Report (inspect `/home/ubuntu/projects/github.com/CHITTYOS/chittyconnect`)
- R3 P-Synthetic Identity Verification (inspect `/home/ubuntu/projects/github.com/CHITTYFOUNDATION/chittyid`, verify VV-G-LLL-SSSS-T-YM-C-X semantics, check `context.*` tables in Neon project `ChittyOS-Core` id `restless-grass-40598426`)
- R4 Outbox / Worker Discovery
- R5 Implementation Diff (blocked by R1-R4)

**Spec §26 STOP-GATE is technically still in effect** — user said "remediate" which overrode it for R1 gaps; the remaining reports should still complete before broader implementation.

## Conflict / things to remember

- The previous session on Mac is dead (hookify errors, cwd pegged to deleted path). It produced earlier checkpoint at `~/.claude/checkpoints/openclaw-2026.4.7-triad-split-20260502.md` describing the OpenClaw triad split that landed this VM workspace at `/home/ubuntu/workspace/openclaw/`. That work is unrelated to MyChitty v1 but the openclaw directory IS one of the three target substrates.
- VM's own `~/.claude/chittycontext/sync_queue.json` has 307 entries, similarly drainer-rotted (Mac had 1,682). The "fix the drainer" subproject is implicitly handled by MyChitty v1: once the canonical write path is live, the drainer either gets repointed at it or replaced by the synchronous write contract (Option B from earlier discussion).
- Earlier `plans/chitty-charter-security-agents/plan.md` in `/home/ubuntu/workspace/openclaw/` is unrelated to MyChitty — different work, can ignore.

## Resume commands

```bash
cd /home/ubuntu/projects/github.com/CHITTYAPPS/mychitty
git log --oneline -5
ls migrations/ docs/verification/phase-0/

# Inspect Neon branch state (verification artifact, still alive):
#   project: shy-sound-75632194 (ChittyLedger)
#   branch:  br-fancy-art-aevxcl6o (mychitty-v1-migrations-test)
#   parent:  br-steep-fog-ae9tdd66 (default)

# To resume in a fresh Claude session:
#   /checkpoint resume   (this file is ~/.claude/checkpoints/mychitty-latest.md)
#
# To continue Phase 0 work:
#   "Continue from R2 — ChittyConnect Route Surface Report"
#
# To finish remediation:
#   "Apply migrations to default branch" (or "go default")
```

## Open task IDs in TaskList

- #2 R2 ChittyConnect Route Surface — pending
- #3 R3 P-Synthetic Identity Verification — pending
- #4 R4 Outbox / Worker Discovery — pending
- #5 R5 Implementation Diff — blocked by #1-4 (#1 done)
- #7 Apply migrations to default — needs explicit go
